"""Vertical alignment for glyph/RTL paired advances and native current points.

Builds 120 deterministic EMFs from the existing paired-advance fixtures:
baseline/bottom with left alignment cover the full rotation/clip/UPDATECP matrix;
center/right additionally cover both rotations with UPDATECP and optional clips.
"""
import struct
from generate_opaque_emf import ROOT
from generate_glyph_rtl_emf import records


def main():
    for vertical, vertical_flags in (('baseline', 24), ('bottom', 8)):
        for horizontal, horizontal_flags in (('left', 0), ('center', 6), ('right', 2)):
            for family in ('glyph', 'glyph_rtl', 'rtl'):
                for mode in (range(16) if horizontal == 'left' else (13, 15)):
                    source = ROOT / f'exttextoutw_index_rtl_pdy_center_{family}_{mode:02d}.emf'
                    parts = []
                    text_index = 0
                    for kind, data in records(source.read_bytes()):
                        data = bytearray(data)
                        if kind == 22:
                            flags = struct.unpack_from('<I', data, 8)[0]
                            struct.pack_into('<I', data, 8, (flags & ~30) | vertical_flags | horizontal_flags)
                        elif kind == 27:
                            struct.pack_into('<2i', data, 8, 30, 45)
                        elif kind == 30:
                            struct.pack_into('<i', data, 20, 235)
                        elif kind == 35:
                            struct.pack_into('<f', data, 24, 100 if horizontal == 'left' else 185)
                        elif kind == 84:
                            struct.pack_into('<2i', data, 36, 30 if text_index == 0 else 65,
                                             45 if text_index == 0 else 95)
                            text_index += 1
                        parts.append(data)
                    assert text_index == 2
                    name = f'exttextoutw_index_rtl_pdy_vertical_{vertical}_{horizontal}_{family}_{mode:02d}'
                    (ROOT / (name + '.emf')).write_bytes(b''.join(parts))
                    print(name)


if __name__ == '__main__':
    main()
