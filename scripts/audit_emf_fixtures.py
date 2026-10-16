"""Audit immutable EMF controls for duplicates and parser record coverage.

Record identifiers are the Windows API constants in emf-record-types.json.
Identical pixels alone do not make inputs redundant: glyph-index/RTL pairs
deliberately exercise different flag combinations with identical output.
"""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import re
import struct

ROOT = Path(__file__).resolve().parent.parent


def records(data):
    offset = 0
    while offset < len(data):
        if len(data) - offset < 8:
            raise ValueError(f'truncated record at {offset}')
        kind, size = struct.unpack_from('<II', data, offset)
        if size < 8 or size % 4 or size > len(data) - offset:
            raise ValueError(f'invalid record size {size} at {offset}')
        yield kind, data[offset:offset + size]
        offset += size


def audit(directory, parser_path=ROOT / 'src/Vcl.GraphUtil.MetafileParser.pas'):
    constants = json.loads((ROOT / 'tests/fixtures/emf-record-types.json').read_text())
    source = parser_path.read_text(encoding='utf-8-sig')
    local_constants = {name: int(value) for name, value in re.findall(r'\b(EMR_\w+_LOCAL)\s*=\s*(\d+)\s*;', source)}
    section = source.split('function TMetafileParser.EnumRecord', 1)[1].split(
        'function TMetafileParser.CurrentTextToFlatPolygons(out', 1)[0]
    supported = {}
    unresolved = []
    for name in sorted(set(re.findall(r'\bEMR_\w+', section))):
        canonical = name.removesuffix('_LOCAL')
        if canonical in constants:
            supported[canonical] = constants[canonical]
        elif name in local_constants:
            supported[canonical] = local_constants[name]
        else:
            unresolved.append(name)
    exact, programs = defaultdict(list), defaultdict(list)
    counts, examples = Counter(), defaultdict(list)
    failures, headers = [], []
    for path in sorted(directory.glob('*.emf')):
        try:
            data = path.read_bytes()
            parts = list(records(data))
            if not parts or parts[0][0] != 1 or parts[-1][0] != 14:
                raise ValueError('missing header or EOF')
            if len(parts[0][1]) < 88:
                raise ValueError('short EMF header')
            size, number = struct.unpack_from('<II', parts[0][1], 48)
            if size != len(data) or number != len(parts):
                headers.append({'name': path.name, 'bytes': [size, len(data)], 'records': [number, len(parts)]})
            exact[hashlib.sha256(data).hexdigest()].append(path.name)
            header = parts[0][1]
            description = struct.unpack_from('<I', header, 64)[0]
            # Retain rendering-relevant header fields (especially the frame,
            # device dimensions and physical units). Only description metadata,
            # record/header byte counts and padding are ignored.
            fixed_end = min(len(header), 108, description or 108)
            program = header[8:48] + header[56:60] + header[68:fixed_end]
            if fixed_end >= 100:
                pixel_size, pixel_offset = struct.unpack_from('<II', header, 88)
                if pixel_size:
                    program += header[pixel_offset:pixel_offset + pixel_size]
            program += b''.join(record for kind, record in parts if kind != 1)
            programs[hashlib.sha256(program).hexdigest()].append(path.name)
            counts.update(kind for kind, _ in parts)
            for kind in set(kind for kind, _ in parts):
                examples[kind].append(path.name)
        except (ValueError, struct.error) as error:
            failures.append({'name': path.name, 'error': str(error)})
    missing = {name: kind for name, kind in supported.items() if not counts[kind]}
    duplicates = [group for group in exact.values() if len(group) > 1]
    equivalent = [group for group in programs.values() if len(group) > 1]
    return {'fixtures': sum(map(len, exact.values())), 'duplicates': duplicates,
            'equivalent_record_programs': equivalent, 'missing_supported_records': missing,
            'unresolved_record_identifiers': unresolved, 'invalid_files': failures,
            'header_mismatches': headers,
            'coverage': {name: {'type': kind, 'records': counts[kind], 'fixtures': examples[kind]}
                         for name, kind in sorted(supported.items(), key=lambda item: item[1])}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixtures', type=Path, default=ROOT / 'tests/fixtures/emf')
    parser.add_argument('--json', type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    report = audit(args.fixtures)
    if args.json:
        args.json.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    errors = ('duplicates', 'equivalent_record_programs', 'missing_supported_records',
              'unresolved_record_identifiers', 'invalid_files', 'header_mismatches')
    print(f"{report['fixtures']} EMF controls; {len(report['coverage'])} supported record types")
    for key in errors:
        print(f'{key}: {len(report[key])}')
        if report[key]:
            print(json.dumps(report[key], indent=2))
    if args.check and (not report['fixtures'] or any(report[key] for key in errors)):
        raise SystemExit(1)


if __name__ == '__main__':
    main()
