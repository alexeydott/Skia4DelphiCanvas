"""Validate explicit public-API catalog completeness and demo source references.
This is a catalog check, not a replacement for native runtime/pixel tests.
"""
from pathlib import Path
import json
import re
ROOT = Path(__file__).resolve().parent.parent

def public_api():
    source = (ROOT / 'src/Vcl.Graphics.Skia.pas').read_text(encoding='utf-8-sig')
    source = re.sub(r'\{.*?\}|\(\*.*?\*\)|//[^\n]*', '', source, flags=re.S)
    source = re.split(r'^\s*implementation\s*$', source, maxsplit=1, flags=re.M)[0]
    result = {}
    for cls, block in re.findall(r'(TSkia\w+)\s*=\s*class(?:\([^\n]+\))?\s*\n(.*?)^\s*end;', source, re.S | re.M):
        active = False
        members = []
        for line in block.splitlines():
            if line.strip() in ('public', 'published'):
                active = True
                continue
            if line.strip() in ('private', 'protected', 'strict private'):
                active = False
            if active:
                members.extend(re.findall(r'\b(?:constructor|destructor|procedure|function|property)\s+(\w+)', line))
        result[cls] = sorted(set(members))
    return result

def check():
    catalog = json.loads((ROOT / 'demo/api-coverage.json').read_text(encoding='utf-8'))
    api = public_api()
    if set(api) != set(catalog['classes']):
        raise SystemExit('Public class catalog differs from source')
    demos = '\n'.join(p.read_text(encoding='utf-8-sig') for p in (p for p in (ROOT / 'demo').iterdir() if p.suffix in ('.pas','.inc')))
    demos = re.sub(r'\{.*?\}|\(\*.*?\*\)|//[^\n]*', '', demos, flags=re.S)
    demos = re.sub(r"'(?:[^']|'')*'", "''", demos)
    references = {m.lower() for m in re.findall(r'\.\s*(\w+)', demos)}
    count = 0
    for cls, members in api.items():
        entries = catalog['classes'][cls]
        if set(members) != set(entries):
            raise SystemExit(f'{cls}: missing/stale members: {set(members) ^ set(entries)}')
        for member, entry in entries.items():
            if not entry['pages'] or any(p < 1 or p > len(catalog['pages']) for p in entry['pages']):
                raise SystemExit(f'{cls}.{member}: invalid page mapping')
            if member.lower() not in references and not entry.get('via'):
                raise SystemExit(f'{cls}.{member}: no demo source reference or lifecycle explanation')
            count += 1
    for name in ('ColorToAlphaColor', 'AlphaColorToColor'):
        if not re.search(r'\b' + name + r'\s*\(', demos):
            raise SystemExit(f'{name}: no direct demonstration')
    print(f'PASS: {len(api)} classes / {count} public member names + 2 color helpers cataloged')
    print('Overloads share member names; native tests and exported images verify behavior separately.')
    return catalog

if __name__ == '__main__':
    check()
