"""Verify Windows static Skia executables without third-party PE dependencies."""
import argparse
import json
import struct
from pathlib import Path


def imports(path):
    data = path.read_bytes()
    pe = struct.unpack_from('<I', data, 0x3C)[0]
    if data[:2] != b'MZ' or data[pe:pe + 4] != b'PE\0\0':
        raise ValueError(f'Not a PE executable: {path}')
    sections, optional_size = struct.unpack_from('<H12xH', data, pe + 6)
    optional = pe + 24
    magic = struct.unpack_from('<H', data, optional)[0]
    if magic not in (0x10B, 0x20B):
        raise ValueError(f'Unsupported PE optional header: {magic:x}')
    directories = optional + (112 if magic == 0x20B else 96)
    table = optional + optional_size

    def offset(rva):
        for i in range(sections):
            size, address, raw_size, raw = struct.unpack_from('<4I', data, table + i * 40 + 8)
            if address <= rva < address + max(size, raw_size):
                return raw + rva - address
        raise ValueError(f'Unmapped RVA: {rva:x}')

    def name(rva):
        start = offset(rva)
        return data[start:data.index(b'\0', start)].decode('ascii')

    result = []
    for index, stride, name_offset in ((1, 20, 12), (13, 32, 4)):
        rva, size = struct.unpack_from('<II', data, directories + index * 8)
        if not rva:
            continue
        start = offset(rva)
        for pos in range(start, start + size, stride):
            record = data[pos:pos + stride]
            if not any(record):
                break
            name_rva = struct.unpack_from('<I', record, name_offset)[0]
            if index == 13 and not struct.unpack_from('<I', record)[0] & 1:
                image_base = struct.unpack_from('<Q' if magic == 0x20B else '<I', data,
                                                optional + (24 if magic == 0x20B else 28))[0]
                name_rva -= image_base
            result.append(name(name_rva))
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('executables', nargs='+', type=Path)
    args = parser.parse_args()
    for executable in args.executables:
        libraries = imports(executable)
        if any('sk4d' in library.lower() for library in libraries):
            raise SystemExit(f'FAIL: Skia DLL import in {executable}: {libraries}')
        if (executable.parent / 'sk4d.dll').exists():
            raise SystemExit(f'FAIL: sk4d.dll beside {executable}')
        binary = executable.read_bytes().lower()
        if b'sk4d.dll' in binary or 'sk4d.dll'.encode('utf-16le') in binary:
            raise SystemExit(f'FAIL: Skia DLL name remains embedded in {executable}')
        print(json.dumps({'executable': str(executable.resolve()),
                          'bytes': executable.stat().st_size,
                          'imports': libraries, 'sk4d_dll_import': False}))
