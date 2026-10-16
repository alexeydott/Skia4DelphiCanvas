"""Deterministic TA_CENTER/TA_RIGHT, UPDATECP and ETO_PDY regression EMFs.

Two text records and a following line expose both glyph placement and the native
current-point contract. Uses the existing Arial LOGFONT and physical EMF header.
"""
import math
import struct
from generate_opaque_emf import ROOT, record


def text(value, origin, bounds, pdy, clipped):
    encoded = value.encode('utf-16-le')
    advances = [v for pair in zip([18] * 6, [5, -3, 7, -2, 4, 6]) for v in pair] if pdy else [18] * 6
    flags = 2 | (0x2000 if pdy else 0) | (4 if clipped else 0)
    return record(84, struct.pack('<4iI2f2i3I4iI', 0, 0, 383, 255,
                                 2, 1, 1, *origin, 6, 76, flags,
                                 *bounds, 76 + len(encoded))
                  + encoded + struct.pack('<' + 'i' * len(advances), *advances))


def main():
    source = (ROOT / 'exttextoutw_opaque.emf').read_bytes()
    offset = 0
    while offset < len(source):
        kind, size = struct.unpack_from('<II', source, offset)
        if kind == 82:
            font = bytearray(source[offset:offset + size])
        offset += size
    for alignment, align_flag in (('center', 6), ('right', 2)):
        # The full 16-case matrix combines CP, PDY, both rotations and clipping.
        # Four more cases isolate world/font rotation with PDY + UPDATECP.
        cases = [(m, 30 if m & 4 else 0, -20 if m & 4 else 0) for m in range(16)]
        cases += [(16 + i, world, angle) for i, (world, angle) in enumerate(
            ((30, 0), (0, -20), (30, 0), (0, -20)))]
        for mode, world, angle in cases:
            update = bool(mode & 1) if mode < 16 else True
            pdy = bool(mode & 2) if mode < 16 else True
            clipped = bool(mode & 8) if mode < 16 else mode >= 18
            header = bytearray(source[:108])
            struct.pack_into('<4i', header, 8, 0, 0, 383, 255)
            dx, dy, mx, my = struct.unpack_from('<4i', header, 72)
            struct.pack_into('<4i', header, 24, 0, 0, round(384 * mx * 100 / dx), round(256 * my * 100 / dy))
            lf = bytearray(font)
            struct.pack_into('<I4i', lf, 8, 1, -28, 0, angle * 10, angle * 10)
            a = math.radians(world)
            parts = [bytes(header), bytes(lf), record(37, struct.pack('<I', 1))]
            if clipped:
                # Fixed device clip, then a rotated logical ETO_CLIPPED rectangle.
                parts.append(record(30, struct.pack('<4i', 65, 45, 300, 195)))
            parts += [record(35, struct.pack('<6f', math.cos(a), math.sin(a), -math.sin(a), math.cos(a), 150, 65)),
                      record(18, struct.pack('<I', 2)), record(25, struct.pack('<I', 0xB0FFFF)),
                      record(24, struct.pack('<I', 0x800000)), record(22, struct.pack('<I', align_flag | int(update))),
                      record(27, struct.pack('<2i', 35, 25)),
                      text('AVATAR', (35, 25), (-65, 5, 105, 65), pdy, clipped),
                      text('office', (75, 75), (-65, 45, 125, 115), pdy, clipped),
                      record(38, struct.pack('<IIiiI', 2, 0, 3, 0, 0x0000FF)),
                      record(37, struct.pack('<I', 2)), record(54, struct.pack('<2i', 130, 110)),
                      record(37, struct.pack('<I', 0x80000007)), record(40, struct.pack('<I', 2)),
                      record(37, struct.pack('<I', 0x8000000D)), record(40, struct.pack('<I', 1)),
                      record(14, struct.pack('<3I', 0, 16, 20))]
            struct.pack_into('<IIH', header, 48, sum(map(len, parts)), len(parts), 3)
            parts[0] = bytes(header)
            name = f'exttextoutw_aligned_{alignment}_{mode:02d}'
            (ROOT / (name + '.emf')).write_bytes(b''.join(parts))
            print(name, 'update_cp=', update, 'pdy=', pdy, 'world=', world, 'font=', angle, 'clipped=', clipped)


if __name__ == '__main__':
    main()
