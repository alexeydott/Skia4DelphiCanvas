"""Check that a native Skia library exports every function used by the Pascal loader."""
import argparse
from pathlib import Path
import re
import subprocess
import struct


def check(library):
    root = Path(__file__).resolve().parent.parent
    api = (root / 'src/fpc/vendor/System.Skia.API.pas').read_text(encoding='utf-8-sig')
    required = set(re.findall(r"PChar\('((?:sk4d|gr4d)_\w+)'\)", api))
    assert required, 'No Pascal imports found'
    if library.suffix.lower() == '.dll':
        data = library.read_bytes()
        pe = struct.unpack_from('<I', data, 0x3c)[0]
        if data[:2] != b'MZ' or data[pe:pe+4] != b'PE\0\0':
            raise ValueError(f'Not a PE library: {library}')
        sections, optional_size = struct.unpack_from('<H12xH', data, pe+6)
        optional = pe+24
        directories = optional + (112 if struct.unpack_from('<H', data, optional)[0] == 0x20b else 96)
        def offset(rva):
            for i in range(sections):
                size, address, raw_size, raw = struct.unpack_from('<4I', data, optional+optional_size+i*40+8)
                if address <= rva < address+max(size, raw_size):
                    return raw+rva-address
            raise ValueError(f'Unmapped PE RVA: {rva:x}')
        exports = offset(struct.unpack_from('<I', data, directories)[0])
        count = struct.unpack_from('<I', data, exports+24)[0]
        names = offset(struct.unpack_from('<I', data, exports+32)[0])
        exported = set()
        for i in range(count):
            start = offset(struct.unpack_from('<I', data, names+4*i)[0])
            exported.add(data[start:data.index(b'\0',start)].decode('ascii'))
    else:
        output = subprocess.check_output(['nm', '-D', '--defined-only', str(library)], text=True)
        exported = {line.split()[-1] for line in output.splitlines() if line.split()}
    missing = sorted(required - exported)
    if missing:
        raise SystemExit('Missing Pascal API exports: ' + ', '.join(missing))
    print(f'PASS: all {len(required)} Pascal API imports exported by {library.name}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('library', type=Path)
    check(parser.parse_args().library)
