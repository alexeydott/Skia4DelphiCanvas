#!/usr/bin/env python3
"""Generate small structural EMF parser fuzz inputs using only the stdlib.

The files are intentionally a mixture of valid framing and malformed record
payloads. They are suitable for SetEnhMetaFileBits: GDI may reject many of
these, which is recorded by the harness and is part of the corpus design.
"""
import argparse, json, struct
from pathlib import Path

TYPES_PATH = Path(__file__).resolve().parents[1] / "fixtures" / "emf-record-types.json"
BUILTIN = {
    "EMR_HEADER": 1, "EMR_EOF": 14, "EMR_POLYBEZIER": 2, "EMR_POLYGON": 3,
    "EMR_POLYLINE": 4, "EMR_POLYBEZIERTO": 5, "EMR_POLYLINETO": 6,
    "EMR_POLYPOLYLINE": 7, "EMR_POLYPOLYGON": 8, "EMR_SETWINDOWEXTEX": 9,
    "EMR_SETWINDOWORGEX": 10, "EMR_SETVIEWPORTEXTEX": 11,
    "EMR_SETVIEWPORTORGEX": 12, "EMR_SETBRUSHORGEX": 13, "EMR_SETPIXELV": 15,
    "EMR_SETMAPPERFLAGS": 16, "EMR_SETMAPMODE": 17, "EMR_SETBKMODE": 18,
    "EMR_SETPOLYFILLMODE": 19, "EMR_SETROP2": 20,
    "EMR_SETSTRETCHBLTMODE": 21, "EMR_SETTEXTALIGN": 22,
    "EMR_SETCOLORADJUSTMENT": 23, "EMR_SETTEXTCOLOR": 24,
    "EMR_SETBKCOLOR": 25, "EMR_OFFSETCLIPRGN": 26, "EMR_MOVETOEX": 27,
    "EMR_SETMETARGN": 28, "EMR_EXCLUDECLIPRECT": 29,
    "EMR_INTERSECTCLIPRECT": 30, "EMR_SCALEVIEWPORTEXTEX": 31,
    "EMR_SCALEWINDOWEXTEX": 32, "EMR_SAVEDC": 33, "EMR_RESTOREDC": 34,
    "EMR_SETWORLDTRANSFORM": 35, "EMR_MODIFYWORLDTRANSFORM": 36,
    "EMR_SELECTOBJECT": 37, "EMR_CREATEPEN": 38,
    "EMR_CREATEBRUSHINDIRECT": 39, "EMR_DELETEOBJECT": 40,
    "EMR_ANGLEARC": 41, "EMR_ELLIPSE": 42, "EMR_RECTANGLE": 43,
    "EMR_ROUNDRECT": 44, "EMR_ARC": 45, "EMR_CHORD": 46, "EMR_PIE": 47,
    "EMR_LINETO": 54, "EMR_ARCTO": 55, "EMR_POLYDRAW": 56,
    "EMR_SETARCDIRECTION": 57, "EMR_SETMITERLIMIT": 58,
    "EMR_BEGINPATH": 59, "EMR_ENDPATH": 60, "EMR_CLOSEFIGURE": 61,
    "EMR_FILLPATH": 62, "EMR_STROKEANDFILLPATH": 63, "EMR_STROKEPATH": 64,
    "EMR_FLATTENPATH": 65, "EMR_WIDENPATH": 66,
    "EMR_SELECTCLIPPATH": 67, "EMR_ABORTPATH": 68, "EMR_FILLRGN": 71,
    "EMR_FRAMERGN": 72, "EMR_INVERTRGN": 73, "EMR_PAINTRGN": 74,
    "EMR_EXTSELECTCLIPRGN": 75, "EMR_BITBLT": 76, "EMR_STRETCHBLT": 77,
    "EMR_MASKBLT": 78, "EMR_PLGBLT": 79, "EMR_SETDIBITSTODEVICE": 80,
    "EMR_EXTTEXTOUTA": 83, "EMR_EXTTEXTOUTW": 84, "EMR_POLYBEZIER16": 85,
    "EMR_POLYGON16": 86, "EMR_POLYLINE16": 87, "EMR_POLYBEZIERTO16": 88,
    "EMR_POLYLINETO16": 89, "EMR_POLYPOLYLINE16": 90, "EMR_POLYPOLYGON16": 91,
    "EMR_POLYDRAW16": 92, "EMR_CREATEMONOBRUSH": 93, "EMR_CREATEDIBPATTERNBRUSHPT": 94,
    "EMR_EXTCREATEFONTINDIRECTW": 82, "EMR_EXTCREATEPEN": 95,
    "EMR_POLYTEXTOUTA": 96, "EMR_POLYTEXTOUTW": 97, "EMR_SETICMMODE": 98,
    "EMR_CREATECOLORSPACE": 99, "EMR_SETCOLORSPACE": 100,
    "EMR_DELETECOLORSPACE": 101, "EMR_GLSRECORD": 102, "EMR_GLSBOUNDEDRECORD": 103,
    "EMR_PIXELFORMAT": 104, "EMR_RESERVED_105": 105, "EMR_RESERVED_106": 106,
    "EMR_RESERVED_107": 107, "EMR_RESERVED_108": 108, "EMR_RESERVED_109": 109,
    "EMR_RESERVED_110": 110, "EMR_GRADIENTFILL": 118, "EMR_SETLAYOUT": 115,
    "EMR_SMALLTEXTOUT": 108, "EMR_FORCEUFIMAPPING": 109, "EMR_NAMEDESC": 110,
}

def load_types():
    try:
        obj = json.loads(TYPES_PATH.read_text(encoding="utf-8"))
        if isinstance(obj, dict) and all(isinstance(v, int) for v in obj.values()):
            return obj
    except (OSError, ValueError):
        pass
    return BUILTIN

def rec(kind, payload=b"", declared=None, align=True):
    body = bytes(payload)
    if align:
        body += b"\0" * ((-len(body)) & 3)
    size = 8 + len(body) if declared is None else declared
    return struct.pack("<II", kind & 0xffffffff, size & 0xffffffff) + body

def header(parts, count):
    total = 108 + sum(map(len, parts))
    h = bytearray(108)
    struct.pack_into("<II", h, 0, 1, 108)
    struct.pack_into("<4i", h, 8, 0, 0, 256, 256)
    struct.pack_into("<4i", h, 24, 0, 0, 6773, 6773)  # .01mm frame
    struct.pack_into("<I", h, 40, 0x464d4520)
    struct.pack_into("<I", h, 44, 0x00010000)
    struct.pack_into("<II", h, 48, total, count)
    struct.pack_into("<H", h, 56, 1)
    struct.pack_into("<4i", h, 72, 256, 256, 67, 67)
    struct.pack_into("<2i", h, 100, 67000, 67000)
    return bytes(h)

def base_payload(kind):
    # Payloads follow the packed layouts consumed by the parser. For records
    # with variable tails, include a deliberately small, coherent prefix.
    if kind in (2,3,4,5,6,85,86,87,88,89): return struct.pack("<4i",0,0,256,256)+struct.pack("<I",1)+struct.pack("<2i",1,1)
    if kind in (7,8,90,91): return struct.pack("<4iII",0,0,256,256,1,1)+struct.pack("<I",1)+struct.pack("<2i",1,1)
    if kind in (9,11,31,32): return struct.pack("<ii",256,256)
    if kind in (10,12,13,15,27,54): return struct.pack("<ii",1,1)
    if kind in (16,17,18,19,20,21,22,24,25,28,33,34,37,40,52,57,58,67,68,98,100,101,115): return struct.pack("<I",1)
    if kind in (29,30,42,43): return struct.pack("<4i",0,0,256,256)
    if kind in (35,36): return struct.pack("<6f",1.0,0.0,0.0,1.0,0.0,0.0)
    if kind in (38,): return struct.pack("<IIiiI",1,0,1,0,0)
    if kind in (39,): return struct.pack("<III",0,0,0)
    if kind in (41,): return struct.pack("<4i f",1,1,100,100,1.0)
    if kind in (44,45,46,47,55): return struct.pack("<8i",0,0,256,256,0,128,256,128)
    if kind in (59,60,61,62,63,64,65,66,74): return b""
    if kind in (71,72,73): return struct.pack("<4iII",0,0,256,256,0,0)
    if kind in (75,): return struct.pack("<II",0,1)
    if kind in (76,77,78,79,80): return struct.pack("<4i",0,0,256,256)+b"\0"*64
    if kind in (82,): return b"\0"*92
    if kind in (83,84): return struct.pack("<4iI2f2i3I4iI",0,0,256,256,1,1,1,8,20,1,76,0,0,0,256,256,76)+b"A\0"
    if kind in (92,): return struct.pack("<4iII",0,0,256,256,1,1)+struct.pack("<2hB",1,1,6)
    if kind in (93,94): return struct.pack("<IIII",0,0,0,0)
    if kind in (95,): return struct.pack("<II4iII",1,0,1,0,0,0,0,0)
    if kind in (96,97): return struct.pack("<4iI",0,0,256,256,1)+b"\0"*32
    if kind in (99,): return struct.pack("<IIII",0,0,0,0)
    if kind in (102,103): return struct.pack("<II",0,0)+b"\0"*32
    if kind in (104,): return b"\0"*40
    if kind in (118,): return struct.pack("<4iIIIII",0,0,256,256,0,0,0,0,0)
    return b"\0"*8

def variants(name, kind):
    p = base_payload(kind)
    # Every fixed-prefix boundary, then count/offset and record framing cases.
    lengths = sorted(set([0,1,2,3,4,8,12,16,min(len(p),24),len(p)] + list(range(0, len(p) + 1, 4))))
    for n in lengths:
        yield f"{name.lower()}_trunc_{n:03d}", rec(kind, p[:n])
    boundary = bytearray(p)
    for off in range(0, len(boundary) - 3, 4):
        old = struct.unpack_from("<I", boundary, off)[0]
        if old in (0,1) or off < 24:
            struct.pack_into("<I", boundary, off, 0xffffffff)
            yield f"{name.lower()}_boundary_{off:03d}", rec(kind, boundary)
            struct.pack_into("<I", boundary, off, old)
    yield f"{name.lower()}_declared_short", rec(kind, p, 4)
    yield f"{name.lower()}_declared_unaligned", rec(kind, p, 9, align=False)
    yield f"{name.lower()}_declared_huge", rec(kind, p, 0xfffffff0)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--limit", type=int, default=0, help="limit record types (0 = all)")
    args = ap.parse_args()
    out = Path(args.out); out.mkdir(parents=True, exist_ok=True)
    types = list(load_types().items())
    if args.limit: types = types[:args.limit]
    manifest = {"generator":"gen_emf_corpus.py", "format":"EMF", "files":[]}
    for name, kind in types:
        if kind in (1,14): continue
        for stem, malformed in variants(name, kind):
            eof = rec(14, struct.pack("<III",0,0,20))
            data = header([b""], 0) + malformed + eof
            # Header nBytes/nRecords deliberately describe this exact stream.
            h = bytearray(data[:108]); struct.pack_into("<II", h, 48, len(data), 3); data = bytes(h) + data[108:]
            path = out / (stem + ".emf"); path.write_bytes(data)
            manifest["files"].append({"file":path.name,"record":name,"type":kind,"size":len(data),"variants":[stem.split("_", 1)[1]]})
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"generated {len(manifest['files'])} EMFs in {out}")

if __name__ == "__main__": main()
