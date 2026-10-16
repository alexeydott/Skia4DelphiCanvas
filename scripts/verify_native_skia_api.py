"""Check that a Linux Skia library exports every function used by the Pascal loader."""
import argparse
from pathlib import Path
import re
import subprocess


def check(library):
    root = Path(__file__).resolve().parent.parent
    api = (root / 'src/fpc/vendor/System.Skia.API.pas').read_text(encoding='utf-8-sig')
    required = set(re.findall(r"PChar\('((?:sk4d|gr4d)_\w+)'\)", api))
    assert required, 'No Pascal imports found'
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
