"""Audit vector text in every text-bearing EMF without bitmap source records.

Run after the native suite and alongside verify_emf_images.py --render. Mixed
bitmap/vector fixtures are inspected by the image verifier; their legitimate
bitmap operations prevent a whole-page no-image assertion.
"""
import argparse
import json
from pathlib import Path
from xml.etree import ElementTree as ET

from pypdf import PdfReader
from audit_emf_fixtures import records
from verify_emf_images import pdf_image_count

ROOT = Path(__file__).resolve().parent.parent
NS = '{http://www.w3.org/2000/svg}'


def check(directory, fixtures):
    constants = json.loads((ROOT / 'tests/fixtures/emf-record-types.json').read_text())
    text = {constants[name] for name in ('EMR_EXTTEXTOUTA', 'EMR_EXTTEXTOUTW',
                                        'EMR_POLYTEXTOUTA', 'EMR_POLYTEXTOUTW', 'EMR_SMALLTEXTOUT')}
    bitmap = {constants[name] for name in ('EMR_BITBLT', 'EMR_STRETCHBLT', 'EMR_MASKBLT',
              'EMR_PLGBLT', 'EMR_SETDIBITSTODEVICE', 'EMR_STRETCHDIBITS', 'EMR_ALPHABLEND',
              'EMR_TRANSPARENTBLT', 'EMR_CREATEMONOBRUSH', 'EMR_CREATEDIBPATTERNBRUSHPT')}
    results = []
    failures = []
    selected = 0
    for fixture in sorted(fixtures.glob('*.emf')):
        source_records = list(records(fixture.read_bytes()))
        kinds = {kind for kind, data in source_records}
        # Extended pens can contain DIB brush resources too.
        has_bitmap_pen = any(kind == constants['EMR_EXTCREATEPEN'] and len(data) >= 28 and
                             (int.from_bytes(data[16:20], 'little') or
                              int.from_bytes(data[24:28], 'little'))
                             for kind, data in source_records)
        if not kinds & text or kinds & bitmap or has_bitmap_pen:
            continue
        selected += 1
        for scale, subdirectory in ((1, directory), (2, directory / '2x')):
            base = subdirectory / fixture.stem
            svg = ET.parse(base.with_suffix('.svg')).getroot()
            pdf = PdfReader(base.with_suffix('.pdf'))
            entry = dict(name=fixture.stem, scale=scale,
                         svg_paths=len(svg.findall('.//' + NS + 'path')),
                         svg_images=len(svg.findall('.//' + NS + 'image')),
                         svg_text=len(svg.findall('.//' + NS + 'text')),
                         pdf_images=sum(pdf_image_count(page.get('/Resources', {})) for page in pdf.pages))
            entry['passed'] = not (entry['svg_images'] or entry['svg_text'] or entry['pdf_images'])
            if not entry['passed']:
                failures.append(entry)
            results.append(entry)
    if not results:
        raise ValueError('No vector-text fixtures selected')
    report = dict(fixtures=selected, comparisons=results, failures=failures)
    (directory / 'text-vector-audit.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(f'{selected} text-bearing vector fixtures / {len(results)} PDF/SVG pairs; {len(failures)} failures')
    for entry in failures:
        print(entry)
    return bool(failures)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    parser.add_argument('--fixtures', type=Path, default=ROOT / 'tests/fixtures/emf')
    args = parser.parse_args()
    raise SystemExit(check(args.directory.resolve(), args.fixtures))
