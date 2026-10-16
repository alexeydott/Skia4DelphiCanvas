"""Opaque glyph/RTL paired advances under non-rigid world transforms.

Builds 192 deterministic EMFs from supplied opaque vertical fixtures. Each
transform composes with 30-degree world and -20-degree font rotation. Left
alignment covers UPDATECP on/off; center/right use UPDATECP. All have clipped
and unclipped variants, baseline/bottom alignment, and two background colors.
"""
import math
import struct
from generate_opaque_emf import ROOT
from generate_glyph_rtl_emf import records


TRANSFORMS = {
    'reflect_x': (-1, 0, 0, 1),
    'reflect_y': (1, 0, 0, -1),
    'stretch': (1.4, 0, 0, .65),
    'shear': (1, .6, .35, 1),
}


def transform(values):
    """Compose affine * rotation, placing logical (30,70) at device (192,128)."""
    a, c, b, d = values
    cosine, sine = math.cos(math.pi / 6), math.sin(math.pi / 6)
    m11, m12 = a * cosine + c * sine, b * cosine + d * sine
    m21, m22 = -a * sine + c * cosine, -b * sine + d * cosine
    return m11, m12, m21, m22, 192 - m11 * 30 - m21 * 70, 128 - m12 * 30 - m22 * 70


def main():
    for affine, values in TRANSFORMS.items():
        for vertical in ('baseline', 'bottom'):
            for horizontal in ('left', 'center', 'right'):
                for family in ('glyph', 'glyph_rtl', 'rtl'):
                    for update_cp in ((False, True) if horizontal == 'left' else (True,)):
                        for clipped in (False, True):
                            mode = 12 | int(update_cp) | (2 if clipped else 0)
                            source_mode = mode | 1
                            source = ROOT / f'exttextoutw_index_rtl_pdy_vertical_opaque_{vertical}_{horizontal}_{family}_{source_mode:02d}.emf'
                            parts = []
                            for kind, data in records(source.read_bytes()):
                                data = bytearray(data)
                                if kind == 35:
                                    struct.pack_into('<6f', data, 8, *transform(values))
                                elif kind == 22:
                                    flags = struct.unpack_from('<I', data, 8)[0]
                                    struct.pack_into('<I', data, 8, (flags & ~1) | int(update_cp))
                                parts.append(data)
                            name = f'exttextoutw_index_rtl_pdy_affine_opaque_{affine}_{vertical}_{horizontal}_{family}_{mode:02d}'
                            (ROOT / (name + '.emf')).write_bytes(b''.join(parts))
                            print(name)


if __name__ == '__main__':
    main()
