"""Glyph-index/RTL EMFs with world/font rotation, clipping and UPDATECP.

The Arial glyph IDs are copied from the existing immutable glyph-index fixture;
Unicode RTL records contain Hebrew and Arabic with mixed-direction digits.
No shaping API or installed-font lookup is used by this generator.
"""
import math
import struct
from generate_opaque_emf import ROOT, record


def records(data):
    offset = 0
    while offset < len(data):
        kind, size = struct.unpack_from('<II', data, offset)
        yield kind, data[offset:offset + size]
        offset += size


def text(encoded, origin, bounds, options):
    count = len(encoded) // 2
    encoded += b'\0' * (-len(encoded) % 4)
    return record(84, struct.pack('<4iI2f2i3I4iI', 0, 0, 383, 255,
                                 2, 1, 1, *origin, count, 76, options,
                                 *bounds, 76 + len(encoded))
                  + encoded + struct.pack('<' + 'i' * count, *([18] * count)))


def main():
    seed = (ROOT / 'exttextoutw_glyphs.emf').read_bytes()
    font = None
    for kind, data in records(seed):
        if kind == 82:
            font = bytearray(data)
        elif kind == 84:
            count, offset, options = struct.unpack_from('<3I', data, 44)
            assert options & 0x10
            glyphs = data[offset:offset + count * 2]
            break
    assert font is not None and count == 5
    reverse = b''.join(glyphs[i:i + 2] for i in range(len(glyphs) - 2, -1, -2))
    families = (('glyph', 0x10, glyphs, reverse),
                ('glyph_rtl', 0x90, glyphs, reverse),
                # A leading LTR run makes the RTL flag observable; strings
                # starting with a strong RTL character can look identical
                # without ETO_RTLREADING because of inferred paragraph order.
                ('rtl', 0x80, 'abc \u05e9\u05dc\u05d5\u05dd 12'.encode('utf-16-le'),
                 '34 \u0645\u0631\u062d\u0628\u0627 xy'.encode('utf-16-le')))
    for family, options, first, second in families:
        for mode in range(16):
            header = bytearray(seed[:108])
            struct.pack_into('<4i', header, 8, 0, 0, 383, 255)
            dx, dy, mx, my = struct.unpack_from('<4i', header, 72)
            struct.pack_into('<4i', header, 24, 0, 0, round(384 * mx * 100 / dx), round(256 * my * 100 / dy))
            lf = bytearray(font)
            angle = -200 if mode & 8 else 0
            struct.pack_into('<I4i', lf, 8, 1, -28, 0, angle, angle)
            a = math.pi / 6 if mode & 4 else 0
            parts = [bytes(header), bytes(lf), record(37, struct.pack('<I', 1))]
            if mode & 2:
                parts.append(record(30, struct.pack('<4i', 75, 40, 295, 200)))
            parts += [record(35, struct.pack('<6f', math.cos(a), math.sin(a), -math.sin(a), math.cos(a), 105, 60)),
                      record(18, struct.pack('<I', 2)), record(25, struct.pack('<I', 0xB0FFFF)),
                      record(24, struct.pack('<I', 0x800000)), record(22, struct.pack('<I', mode & 1)),
                      record(27, struct.pack('<2i', 15, 20)),
                      text(first, (15, 20), (0, 5, 165, 65), options | 2 | (4 if mode & 2 else 0)),
                      text(second, (35, 75), (15, 55, 190, 115), options | 2 | (4 if mode & 2 else 0)),
                      record(38, struct.pack('<IIiiI', 2, 0, 3, 0, 0x0000FF)),
                      record(37, struct.pack('<I', 2)), record(54, struct.pack('<2i', 145, 120)),
                      record(37, struct.pack('<I', 0x80000007)), record(40, struct.pack('<I', 2)),
                      record(37, struct.pack('<I', 0x8000000D)), record(40, struct.pack('<I', 1)),
                      record(14, struct.pack('<3I', 0, 16, 20))]
            struct.pack_into('<IIH', header, 48, sum(map(len, parts)), len(parts), 3)
            parts[0] = bytes(header)
            name = f'exttextoutw_index_rtl_{family}_{mode:02d}'
            (ROOT / (name + '.emf')).write_bytes(b''.join(parts))
            print(name)


if __name__ == '__main__':
    main()
