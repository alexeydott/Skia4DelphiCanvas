"""Deterministic opaque text matrix: world/font rotation, clipping and UPDATECP.

Uses the existing Arial LOGFONT and EMF device header; no installed generator
toolchain or GDI calls are needed. The GDI/Pillow oracle renders these separately.
"""
import math
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parent / 'emf'


def record(kind, data):
    data += b'\0' * (-len(data) % 4)
    return struct.pack('<II', kind, len(data) + 8) + data


def text(value, x, y, bounds, flags):
    encoded = value.encode('utf-16-le')
    count = len(encoded) // 2
    dx_offset = 76 + len(encoded)
    return record(84, struct.pack('<4iI2f2i3I4iI', 0, 0, 383, 255, 2, 1, 1,
                                 x, y, count, 76, flags, *bounds, dx_offset)
                  + encoded + struct.pack('<' + 'i' * count, *([18] * count)))


def main():
    source = (ROOT / 'exttextoutw_opaque.emf').read_bytes()
    offset = 0
    font = None
    while offset < len(source):
        kind, size = struct.unpack_from('<II', source, offset)
        if kind == 82:
            font = bytearray(source[offset:offset + size])
        offset += size
    assert font is not None
    # Eight extra cases apply the DC clip before the transform and do not use
    # ETO_CLIPPED: rotated text must remain visible within the fixed device clip.
    for mode in [*range(16), *(m | 16 for m in range(16) if m & 2)]:
        header = bytearray(source[:108])
        struct.pack_into('<4i', header, 8, 0, 0, 383, 255)
        device_x, device_y, mm_x, mm_y = struct.unpack_from('<4i', header, 72)
        struct.pack_into('<4i', header, 24, 0, 0,
                         round(384 * mm_x * 100 / device_x),
                         round(256 * mm_y * 100 / device_y))
        angle = math.pi / 6 if mode & 1 else 0
        lf = bytearray(font)
        struct.pack_into('<I', lf, 8, 1)
        struct.pack_into('<iiii', lf, 12, -28, 0, 300 if mode & 8 else 0, 300 if mode & 8 else 0)
        parts = [bytes(header), bytes(lf), record(37, struct.pack('<I', 1)),
                 record(35, struct.pack('<6f', math.cos(angle), math.sin(angle),
                                        -math.sin(angle), math.cos(angle), 110, 70)),
                 record(18, struct.pack('<I', 2)),
                 record(25, struct.pack('<I', 0xB0FFFF)),
                 record(24, struct.pack('<I', 0x800000)),
                 record(22, struct.pack('<I', 1 if mode & 4 else 0)),
                 record(27, struct.pack('<2i', 8, 12))]
        if mode & 16:
            parts.insert(3, record(30, struct.pack('<4i', 90, 50, 275, 165)))
        elif mode & 2:
            parts.append(record(30, struct.pack('<4i', -5, -5, 170, 95)))
        flags = 2 | (4 if mode & 2 and not mode & 16 else 0)
        parts.extend([text('AVATAR', 8, 12, (0, 0, 115, 44), flags),
                      text('office', 108, 40, (110, 4, 190, 55), flags),
                      record(37, struct.pack('<I', 0x8000000D)),
                      record(40, struct.pack('<I', 1)),
                      record(14, struct.pack('<3I', 0, 16, 20))])
        struct.pack_into('<IIH', header, 48, sum(map(len, parts)), len(parts), 2)
        parts[0] = bytes(header)
        name = f'exttextoutw_opaque_transform_{mode:02d}'
        (ROOT / (name + '.emf')).write_bytes(b''.join(parts))
        print(name, 'world_rotation=', bool(mode & 1), 'clipped=', bool(mode & 2),
              'update_cp=', bool(mode & 4), 'font_rotation=', bool(mode & 8),
              'clip_before_world=', bool(mode & 16))
        if mode in (4, 12):
            # A following LineTo must start from the current point advanced by
            # both text records, including rotated font escapement.
            line_parts = parts[:-3] + [
                record(38, struct.pack('<IIiiI', 2, 0, 3, 0, 0x0000FF)),
                record(37, struct.pack('<I', 2)),
                record(54, struct.pack('<2i', 250, 130)),
                record(37, struct.pack('<I', 0x80000007)),
                record(40, struct.pack('<I', 2)),
            ] + parts[-3:]
            line_header = bytearray(header)
            struct.pack_into('<IIH', line_header, 48, sum(map(len, line_parts)), len(line_parts), 3)
            line_parts[0] = bytes(line_header)
            (ROOT / f'exttextoutw_opaque_transform_cp_line_{mode:02d}.emf').write_bytes(b''.join(line_parts))


if __name__ == '__main__':
    main()
