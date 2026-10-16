"""Stage the m151/LLVM-MinGW constexpr fix in the build directory only."""
import argparse
from pathlib import Path
import re


def prepare(source, build):
    original = source / 'src/ports/SkFontMgr_win_dw.cpp'
    text = original.read_text(encoding='utf-8')
    before = 'DWRITE_FONT_SIMULATIONS_BOLD | DWRITE_FONT_SIMULATIONS_OBLIQUE;'
    after = ('static_cast<DWRITE_FONT_SIMULATIONS>('
             'static_cast<int>(DWRITE_FONT_SIMULATIONS_BOLD) | '
             'static_cast<int>(DWRITE_FONT_SIMULATIONS_OBLIQUE));')
    if before not in text:
        print('DirectWrite constexpr workaround unnecessary')
        return
    overlay = build / 'compat/SkFontMgr_win_dw.cpp'
    overlay.parent.mkdir(parents=True, exist_ok=True)
    overlay.write_text(text.replace(before, after, 1), encoding='utf-8', newline='\n')
    count = 0
    for ninja in build.rglob('*.ninja'):
        content = ninja.read_text(encoding='utf-8')
        content, replacements = re.subn(r'(?<=: cxx )[^\n ]*src/ports/SkFontMgr_win_dw\.cpp',
                                       'compat/SkFontMgr_win_dw.cpp', content)
        if replacements:
            ninja.write_text(content, encoding='utf-8', newline='\n')
            count += replacements
    if count != 1:
        raise ValueError(f'Expected one DirectWrite compile rule, found {count}')
    print('DirectWrite constexpr compatibility source staged in', overlay)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--skia-root', type=Path, required=True)
    parser.add_argument('--build-dir', type=Path, required=True)
    args = parser.parse_args()
    prepare(args.skia_root, args.build_dir)
