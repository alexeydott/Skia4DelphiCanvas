"""Small deterministic controls for previously uncovered EMF record handlers.

Uses supplied header/font data; no Windows API or installed font lookup.
"""
import struct
from generate_opaque_emf import ROOT, record
from generate_glyph_rtl_emf import records
from generate_glyph_rtl_pdy_emf import text
from generate_affine_text_emf import transform


def save(name, body):
    header = bytearray((ROOT / 'exttextoutw_glyphs.emf').read_bytes()[:108])
    struct.pack_into('<4i', header, 8, 0, 0, 383, 255)
    dx, dy, mx, my = struct.unpack_from('<4i', header, 72)
    struct.pack_into('<4i', header, 24, 0, 0, round(384 * mx * 100 / dx), round(256 * my * 100 / dy))
    parts = [header, *body, record(14, struct.pack('<3I', 0, 16, 20))]
    struct.pack_into('<IIH', header, 48, sum(map(len, parts)), len(parts), 4)
    (ROOT / (name + '.emf')).write_bytes(b''.join(parts))
    print(name)


def pen():
    return [record(38, struct.pack('<IIiiI', 2, 0, 3, 0, 0x800000)),
            record(37, struct.pack('<I', 2)), record(37, struct.pack('<I', 0x80000005))]


def font():
    result = next(bytearray(data) for kind, data in records((ROOT / 'exttextoutw_glyphs.emf').read_bytes()) if kind == 82)
    struct.pack_into('<I4i', result, 8, 1, -28, 0, 0, 0)
    return [result, record(37, struct.pack('<I', 1)), record(18, struct.pack('<I', 1)),
            record(24, struct.pack('<I', 0x800000)), record(25, struct.pack('<I', 0xB0FFFF))]


def poly_text(wide, opaque, overlap=False, clipped=False):
    strings = ('First', 'Second')
    encoded = [s.encode('utf-16-le' if wide else 'ascii') for s in strings]
    # Fixed 40-byte prefix and two 40-byte EMRTEXT descriptors, including EMR.
    offset = 120
    descriptors, tail = [], b''
    for i, data in enumerate(encoded):
        data += b'\0' * (-len(data) % 4)
        dx = struct.pack('<' + 'i' * len(strings[i]), *([20] * len(strings[i])))
        x, y = (90, 85) if overlap and i else (45, 65 + 80 * i)
        bounds = (60, 65, 240, 125) if overlap and i else (20, 35 + 80 * i, 260, 95 + 80 * i)
        descriptors.append(struct.pack('<2i3I4iI', x, y, len(strings[i]), offset,
                                       (2 if opaque else 0) | (4 if clipped else 0), *bounds, offset + len(data)))
        tail += data + dx
        offset += len(data) + len(dx)
    return record(97 if wide else 96, struct.pack('<4iI2fi', 0, 0, 383, 255, 2, 1, 1, 2)
                  + b''.join(descriptors) + tail)


def dib():
    width, height = 32, 24
    pixels = b''.join(bytes((0, 0, 0, 0)) if (x // 8 + y // 6) % 2 == 0 else bytes((0, 0, 128, 128))
                      for y in range(height) for x in range(width))
    info = struct.pack('<IiiHH6I', 40, width, -height, 1, 32, 0, len(pixels), 0, 0, 0, 0)
    return width, height, info, pixels


def main():
    save('test_records_setpixel', [record(15, struct.pack('<2iI', x, y, color))
                                 for x0, y0, color in ((40, 40, 0x0000FF), (180, 110, 0xFF0000))
                                 for x in range(x0, x0 + 24) for y in range(y0, y0 + 24)])
    for kind, name in ((31, 'scaleviewport'), (32, 'scalewindow')):
        save('test_records_' + name, [*pen(), record(17, struct.pack('<I', 8)),
             record(9, struct.pack('<2i', 384, 256)), record(11, struct.pack('<2i', 384, 256)),
             record(33, b''), record(kind, struct.pack('<4i', 3, 2, 2, 3)),
             record(43, struct.pack('<4i', 35, 35, 180, 160)), record(34, struct.pack('<i', -1)),
             record(27, struct.pack('<2i', 20, 210)), record(54, struct.pack('<2i', 340, 210))])
    save('test_records_anglearc', [*pen(), record(27, struct.pack('<2i', 40, 70)),
         record(41, struct.pack('<2iI2f', 160, 120, 75, 20, 220)), record(54, struct.pack('<2i', 330, 210))])
    points = ((40, 100), (80, 40), (140, 30), (140, 190), (200, 150), (240, 60), (300, 170))
    for kind, name, fmt in ((56, 'polydraw', '<2i'), (92, 'polydraw16', '<2h')):
        save('test_records_' + name, [*pen(), record(kind, struct.pack('<4iI', 0, 0, 383, 255, len(points))
             + b''.join(struct.pack(fmt, *p) for p in points) + bytes((6, 2, 4, 4, 4, 2, 3)))])
    for kind, name in ((65, 'flattenpath'), (66, 'widenpath')):
        save('test_records_' + name, [*pen(), record(59, b''), record(2, struct.pack('<4iI8i',
             0, 0, 383, 255, 4, 30, 130, 100, 20, 230, 230, 330, 90)), record(60, b''),
             record(kind, b''), *([record(37, struct.pack('<I', 0x80000004))] if kind == 66 else []),
             record(62 if kind == 66 else 64, struct.pack('<4i', 0, 0, 383, 255))])
    for wide in (False, True):
        for opaque in (False, True):
            save('polytextout' + ('w' if wide else 'a') + ('_opaque' if opaque else '_transparent'),
                 [*font(), poly_text(wide, opaque)])
        for update in (False, True):
            save('polytextout' + ('w' if wide else 'a') + '_overlap_clipped' + ('_cp' if update else ''),
                 [*font(), record(18, struct.pack('<I', 2)), record(22, struct.pack('<I', int(update))),
                  record(27, struct.pack('<2i', 45, 65)), poly_text(wide, True, True, True),
                  *pen(), record(54, struct.pack('<2i', 300, 210))])
    for small in (False, True):
        for bounded in (False, True):
            value = 'Small text'.encode('ascii' if small else 'utf-16-le')
            options = (0x200 if small else 0) | (6 if bounded else 0x100)
            save('smalltextout_' + ('ansi' if small else 'unicode') + ('_clipped_opaque' if bounded else '_no_rect'),
                 [*font(), record(108, struct.pack('<2i3I2f', 45, 70, 10, options, 2, 1, 1)
                  + (struct.pack('<4i', 30, 40, 145, 100) if bounded else b'') + value)])
        save('smalltextout_' + ('ansi' if small else 'unicode') + '_rotated_clipped_cp',
             [*font(), record(18, struct.pack('<I', 2)), record(22, struct.pack('<I', 1)),
              record(35, struct.pack('<6f', .8660254, .5, -.5, .8660254, 120, 30)),
              record(27, struct.pack('<2i', 45, 70)), record(108, struct.pack('<2i3I2f', 45, 70, 10,
                    (0x200 if small else 0) | 6, 2, 1, 1) + struct.pack('<4i', 30, 40, 145, 100)
                    + 'Small text'.encode('ascii' if small else 'utf-16-le')),
              *pen(), record(54, struct.pack('<2i', 200, 140))])
    save('exttextoutw_justification', [*font(), record(120, struct.pack('<2i', 60, 3)),
         record(84, struct.pack('<4iI2f2i3I4iI', 0, 0, 383, 255, 2, 1, 1, 35, 110,
                                7, 76, 0, 0, 0, 0, 0, 0) + 'A B C D'.encode('utf-16-le'))])
    width, height, info, pixels = dib()
    for kind, name, rop in ((114, 'alphablend', 0x01C00000), (116, 'transparentblt', 0)):
        fixed = bytearray(108)
        struct.pack_into('<4i4iI2i6f6I2i', fixed, 8, 0, 0, 383, 255, 45, 60, 256, 144,
                         rop, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 108, len(info), 108 + len(info), len(pixels),
                         width, height)
        save('test_records_' + name, [record(kind, bytes(fixed[8:]) + info + pixels)])
    save('test_records_setdibitstodevice', [record(80, struct.pack('<4i6i7I', 0, 0, 383, 255,
         80, 90, 0, 0, width, height, 76, len(info), 76 + len(info), len(pixels), 0, 0, height) + info + pixels)])
    for glyph in (False, True):
        for update in (False, True):
            source = ROOT / ('exttextoutw_index_rtl_pdy_affine_opaque_stretch_baseline_center_glyph_13.emf' if glyph
                             else 'exttextoutw_index_rtl_pdy_affine_opaque_stretch_bottom_right_rtl_13.emf')
            body, index = [], 0
            for kind, data in records(source.read_bytes()):
                if kind in (1, 14):
                    continue
                data = bytearray(data)
                if kind == 35:
                    struct.pack_into('<6f', data, 8, *transform((-1.2, -.45, .25, .8)))
                elif kind == 22:
                    struct.pack_into('<I', data, 8, (struct.unpack_from('<I', data, 8)[0] & ~1) | int(update))
                elif kind == 84 and not glyph:
                    data = text(('AVATAR' if index == 0 else 'office').encode('utf-16-le'),
                                (30, 45) if index == 0 else (65, 95),
                                (-40, 30, 100, 70) if index == 0 else (-30, 75, 110, 115), 2)
                    index += 1
                body.append(data)
            save('exttextoutw_affine_combined_' + ('glyph' if glyph else 'unicode') + ('_cp' if update else '_no_cp'), body)


if __name__ == '__main__':
    main()
