"""Independent Windows GDI/Pillow oracle for EMF compatibility playback.

Source EMFs are read-only. Rejected DIB records are reconstructed in memory;
Pillow decodes their pixels independently of the Pascal/Skia implementation.
Every recovered record and every source SHA-256 is recorded in manifest.json.
"""
import argparse
import ctypes as C
import hashlib
import io
import json
import os
import tempfile
import time
import struct
from pathlib import Path
from PIL import Image


def write_reference(path, data):
    """Preserve identical references; atomically publish changed files."""
    if path.exists() and path.read_bytes() == data:
        return
    with tempfile.NamedTemporaryFile(dir=path.parent, prefix=path.name+'.',
                                     suffix='.tmp', delete=False) as stream:
        temporary = Path(stream.name)
        stream.write(data)
    try:
        for attempt in range(51):
            try:
                os.replace(temporary, path)
                break
            except PermissionError:
                # Windows test readers can briefly deny replacement.
                if attempt == 50:
                    raise
                time.sleep(0.1)
    finally:
        temporary.unlink(missing_ok=True)


class Rect(C.Structure):
    _fields_ = [(name, C.c_int32) for name in ("left", "top", "right", "bottom")]


class Brush(C.Structure):
    _fields_ = [("style", C.c_uint32), ("color", C.c_uint32), ("hatch", C.c_size_t)]


P = C.c_void_p
U = C.c_uint32
CALLBACK = C.WINFUNCTYPE(C.c_int, P, P, P, C.c_int, P)


def api():
    dll = C.WinDLL("gdi32", use_last_error=True)
    declarations = {
        "GetEnhMetaFileW": (P, [C.c_wchar_p]),
        "CreateCompatibleDC": (P, [P]),
        "CreateDIBSection": (P, [P, P, U, P, P, U]),
        "SelectObject": (P, [P, P]),
        "PlayEnhMetaFileRecord": (C.c_int, [P, P, P, U]),
        "EnumEnhMetaFile": (C.c_int, [P, P, CALLBACK, P, C.POINTER(Rect)]),
        "GetPath": (C.c_int, [P, P, P, C.c_int]),
        "ExtCreatePen": (P, [U, U, C.POINTER(Brush), U, P]),
        "CreateBitmap": (P, [C.c_int, C.c_int, U, U, P]),
        "DeleteObject": (C.c_int, [P]),
        "DeleteDC": (C.c_int, [P]),
        "DeleteEnhMetaFile": (C.c_int, [P]),
        "GdiFlush": (C.c_int, []),
    }
    for name, (restype, argtypes) in declarations.items():
        fn = getattr(dll, name)
        fn.restype, fn.argtypes = restype, argtypes
    return dll


def dword(data, offset):
    return struct.unpack_from("<I", data, offset)[0]


def signed(data, offset):
    return struct.unpack_from("<i", data, offset)[0]


def slice_field(data, offset, length):
    if offset > len(data) or length > len(data) - offset:
        raise ValueError("DIB field extends beyond its record")
    return data[offset:offset + length]


def decode_dib(info, bits, usage=0):
    """Decode using Pillow, with explicit palette and bitfield validation."""
    if len(info) < 40:
        raise ValueError("Truncated BITMAPINFOHEADER")
    size, width, height, planes, bpp, compression = struct.unpack_from("<IiiHHI", info)
    if size == 0x20000000:
        # Known corrupt header marker, corroborated by complete scanlines.
        if planes != 1 or width <= 0 or bpp not in (1, 4, 8, 16, 24, 32) or compression not in (0, 3):
            raise ValueError("Cannot reconstruct DIB header")
        if ((width * bpp + 31) // 32) * 4 * abs(height) > len(bits):
            raise ValueError("Truncated corrupt-header DIB")
        info = struct.pack("<I", 40) + info[4:]
    elif size < 40 or size > len(info):
        raise ValueError("Invalid DIB header size")
    if compression in (4, 5):
        image = Image.open(io.BytesIO(bits))
        image.load()
        if image.size != (width, abs(height)):
            raise ValueError("Encoded image dimensions disagree with DIB")
        return image.convert("RGB")
    if usage != 0:
        raise ValueError("Palette-dependent DIB needs explicit native handling")
    fixed = bytearray(info)
    if bpp <= 8:
        available = (len(info) - 40) // 4
        count = dword(info, 32) or 1 << bpp
        if available < count:
            if available == 0:
                raise ValueError("Missing DIB palette")
            struct.pack_into("<I", fixed, 32, available)
            # Check actual pixel indexes independently, excluding row padding.
            stride = ((width * bpp + 31) // 32) * 4
            for y in range(abs(height)):
                for x in range(width):
                    value = bits[y * stride + x * bpp // 8]
                    index = (value >> (8 - bpp - (x * bpp % 8))) & ((1 << bpp) - 1)
                    if index >= available:
                        raise ValueError("Pixel references a missing palette entry")
    bmp = b"BM" + struct.pack("<IHHI", 14 + len(fixed) + len(bits), 0, 0, 14 + len(fixed)) + fixed + bits
    image = Image.open(io.BytesIO(bmp))
    image.load()
    return image.convert("RGB")


def rgb_dib(image, top_down=True):
    w, h = image.size
    rows = image if top_down else image.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    bits = rows.tobytes("raw", "BGRX")
    info = struct.pack("<IiiHHIIiiII", 40, w, -h if top_down else h, 1, 32, 0, len(bits), 0, 0, 0, 0)
    return info, bits


def render(g, source, width, height, output):
    dc = g.CreateCompatibleDC(None)
    storage = P()
    bitmap_info = C.create_string_buffer(struct.pack("<IiiHHIIiiII", 40, width, -height, 1, 32, 0, 0, 0, 0, 0, 0))
    bitmap = g.CreateDIBSection(dc, bitmap_info, 0, C.byref(storage), None, 0)
    if not dc or not bitmap:
        raise OSError("Cannot create reference surface")
    previous = g.SelectObject(dc, bitmap)
    C.memset(storage, 255, width * height * 4)
    metafile = g.GetEnhMetaFileW(str(source.resolve()))
    owned = []
    recoveries, failures = [], []
    record_index = 0
    path_open = False

    def callback(dc, table, rec, objects, _):
        nonlocal record_index, path_open
        record_index += 1
        kind, size = struct.unpack("<II", C.string_at(rec, 8))
        data = C.string_at(rec, size)
        if kind == 1:
            path_open = False
        path_before = g.GetPath(dc, None, None, 0) if kind in (62, 63, 64) else None
        C.set_last_error(0)
        if g.PlayEnhMetaFileRecord(dc, table, rec, objects):
            if kind == 59:
                path_open = True
            elif kind in (60, 68):
                path_open = False
            return 1
        error = C.get_last_error()
        reason = None
        try:
            if kind in (62, 63, 64) and path_before == -1 and not path_open:
                reason = "empty_path"
            elif kind == 95:
                index = dword(data, 8)
                if index >= objects:
                    raise ValueError("Invalid pen object index")
                info = slice_field(data, dword(data, 12), dword(data, 16))
                bits = slice_field(data, dword(data, 20), dword(data, 24))
                style, pen_width, brush_style, usage, hatch, count = struct.unpack_from("<6I", data, 28)
                entries = None
                if style & 15 == 7:
                    if not 0 < count <= 16:
                        raise ValueError("Invalid user style count")
                    entries = C.create_string_buffer(slice_field(data, 52, count * 4))
                else:
                    count = 0
                packed = None
                if brush_style in (3, 5, 6, 7, 8, 9):
                    if brush_style == 9 or (len(info) >= 40 and struct.unpack_from("<H", info, 14)[0] == 1 and usage == 2):
                        w, h = signed(info, 4), signed(info, 8)
                        if w <= 0 or h == 0 or struct.unpack_from("<H", info, 14)[0] != 1:
                            raise ValueError("Invalid monochrome pattern")
                        stride = ((w + 31) // 32) * 4
                        mono_stride = ((w + 15) // 16) * 2
                        if len(bits) < stride * abs(h):
                            raise ValueError("Truncated monochrome pattern")
                        rows = [bits[y * stride:y * stride + mono_stride] for y in range(abs(h))]
                        if h > 0:
                            rows.reverse()
                        packed = C.create_string_buffer(b"".join(rows))
                        pattern = g.CreateBitmap(w, abs(h), 1, 1, packed)
                        if not pattern:
                            raise OSError("Cannot create monochrome pattern")
                        owned.append(pattern)
                        brush = Brush(3, 0, pattern)
                    else:
                        pixels = decode_dib(info, bits, usage & 0xFFFF)
                        decoded_info, decoded_bits = rgb_dib(pixels)
                        packed = C.create_string_buffer(decoded_info + decoded_bits)
                        brush = Brush(6, 0, C.addressof(packed))
                else:
                    brush = Brush(brush_style, usage, hatch)
                pen = g.ExtCreatePen(style, pen_width, C.byref(brush), count, entries)
                if not pen:
                    raise OSError(f"ExtCreatePen failed: {C.get_last_error()}")
                owned.append(pen)
                C.cast(table, C.POINTER(C.c_size_t))[index] = pen
                reason = "pattern_pen"
            elif kind in (76, 77, 81):
                fixed = {76: 100, 77: 108, 81: 80}[kind]
                fields = 48 if kind == 81 else 84
                off_info, cb_info, off_bits, cb_bits = struct.unpack_from("<4I", data, fields)
                info, bits = slice_field(data, off_info, cb_info), slice_field(data, off_bits, cb_bits)
                usage = dword(data, 64 if kind == 81 else 80)
                if kind == 81:
                    x, y, w, h = struct.unpack_from("<4i", data, 32)
                    if dword(data, 68) == 0xCC0020 and w >= 0 and h >= 0 and (
                        x + w <= 0 or y + h <= 0 or x >= signed(info, 4) or y >= abs(signed(info, 8))
                    ):
                        reason = "outside_source"
                if reason is None:
                    pixels = decode_dib(info, bits, usage)
                    decoded_info, decoded_bits = rgb_dib(pixels, top_down=signed(info, 8) < 0)
                    rebuilt = bytearray(data[:fixed]) + decoded_info + decoded_bits
                    struct.pack_into("<I", rebuilt, 4, len(rebuilt))
                    struct.pack_into("<4I", rebuilt, fields, fixed, len(decoded_info), fixed + len(decoded_info), len(decoded_bits))
                    struct.pack_into("<I", rebuilt, 64 if kind == 81 else 80, 0)
                    buffer = C.create_string_buffer(bytes(rebuilt))
                    if not g.PlayEnhMetaFileRecord(dc, table, buffer, objects):
                        raise OSError(f"Decoded DIB rejected: {C.get_last_error()}")
                    reason = "compressed_dib" if dword(info, 16) in (4, 5) else "short_palette"
            else:
                raise ValueError("No defined recovery for rejected record")
        except Exception as exc:
            failures.append({"index": record_index, "type": kind, "native_error": error, "error": str(exc)})
            return 0
        recoveries.append({"index": record_index, "type": kind, "native_error": error, "reason": reason})
        return 1

    cb = CALLBACK(callback)
    try:
        ok = g.EnumEnhMetaFile(dc, metafile, cb, None, C.byref(Rect(0, 0, width - 1, height - 1)))
        if not ok or failures:
            raise RuntimeError(f"{source.name}: incomplete reference playback: {failures}")
        g.GdiFlush()
        image = Image.frombytes("RGB", (width, height), C.string_at(storage, width * height * 4), "raw", "BGRX")
        encoded = io.BytesIO()
        image.save(encoded, format="BMP")
        write_reference(output, encoded.getvalue())
        return recoveries
    finally:
        g.DeleteEnhMetaFile(metafile)
        g.SelectObject(dc, previous)
        g.DeleteDC(dc)
        g.DeleteObject(bitmap)
        # EMR_DELETEOBJECT normally disposes of pens during enumeration.
        for handle in owned:
            g.DeleteObject(handle)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixtures", type=Path, default=Path(__file__).resolve().parent.parent / "tests/fixtures/emf")
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parent.parent / "tests/build/emf-reference")
    args = parser.parse_args()
    g = api()
    manifest = []
    for source in sorted(args.fixtures.glob("*.emf")):
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        entry = {"name": source.stem, "sha256": digest, "scales": {}}
        for scale in (1, 2):
            out = args.output if scale == 1 else args.output / "2x"
            out.mkdir(parents=True, exist_ok=True)
            recovered = render(g, source, 384 * scale, 256 * scale, out / (source.stem + "-reference.bmp"))
            entry["scales"][str(scale)] = recovered
        if hashlib.sha256(source.read_bytes()).hexdigest() != digest:
            raise RuntimeError(f"Source fixture changed: {source}")
        manifest.append(entry)
        print(f"{source.name}: {len(entry['scales']['1'])} compatibility records", flush=True)
    if not manifest:
        raise ValueError("No EMF fixtures found")
    write_reference(args.output / "manifest.json", json.dumps(manifest, indent=2).encode("utf-8"))
    print(f"{len(manifest)} immutable fixtures / {len(manifest) * 2} complete reference images")


if __name__ == "__main__":
    main()
