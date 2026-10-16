"""Opaque baseline/bottom text with glyph indexes, RTL and paired advances.

Copies the 120 supplied vertical fixtures and adds distinct opaque rectangles
and character-cell backgrounds. Font data, advances and current-point cases
remain unchanged. No font lookup or GDI generation step is needed.
"""
import struct
from generate_opaque_emf import ROOT, record
from generate_glyph_rtl_emf import records


def main():
    sources = sorted(p for vertical in ('baseline', 'bottom')
                     for p in ROOT.glob(f'exttextoutw_index_rtl_pdy_vertical_{vertical}_*.emf'))
    assert len(sources) == 120
    for source in sources:
        parts = []
        text_index = 0
        for kind, data in records(source.read_bytes()):
            data = bytearray(data)
            if kind == 18:
                struct.pack_into('<I', data, 8, 2)
            elif kind == 84:
                color = 0xB0FFFF if text_index == 0 else 0xE0FFB0
                parts.append(record(25, struct.pack('<I', color)))
                flags = struct.unpack_from('<I', data, 52)[0]
                struct.pack_into('<I', data, 52, flags | 2)
                bounds = (-40, 30, 100, 70) if text_index == 0 else (-30, 75, 110, 115)
                struct.pack_into('<4i', data, 56, *bounds)
                text_index += 1
            parts.append(data)
        assert text_index == 2
        header = parts[0]
        struct.pack_into('<II', header, 48, sum(map(len, parts)), len(parts))
        name = source.stem.replace('_vertical_', '_vertical_opaque_', 1)
        (ROOT / (name + '.emf')).write_bytes(b''.join(parts))
        print(name)


if __name__ == '__main__':
    main()
