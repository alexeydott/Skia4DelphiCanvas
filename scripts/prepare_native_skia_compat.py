"""Stage m151 compiler and SVG sampling fixes in the build directory only."""
import argparse
import json
import hashlib
from pathlib import Path
import re


def prepare_directwrite(source, build):
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


def prepare_svg_sampling(source, build):
    """Keep image sampling in SVG rather than silently using viewer interpolation."""
    directory = build / 'compat'
    directory.mkdir(parents=True, exist_ok=True)
    header = (source / 'src/svg/SkSVGDevice.h').read_text(encoding='utf-8')
    declaration = 'void drawBitmapCommon(const MxCp&, const SkBitmap& bm, const SkPaint& paint);'
    if declaration not in header:
        raise ValueError('Unexpected SVG device declaration')
    header = header.replace(declaration, 'void drawBitmapCommon(const MxCp&, const SkBitmap& bm, const SkPaint& paint, bool nearest = false);')
    (directory / 'SkSVGDevice.h').write_text(header, encoding='utf-8', newline='\n')
    device = (source / 'src/svg/SkSVGDevice.cpp').read_text(encoding='utf-8')
    device = device.replace('#include "src/svg/SkSVGDevice.h"', '#include "SkSVGDevice.h"\n#include "include/core/SkSamplingOptions.h"')
    device = device.replace('const SkPaint& paint) {\n    sk_sp<SkData> pngData', 'const SkPaint& paint, bool nearest) {\n    sk_sp<SkData> pngData', 1)
    device = device.replace('image.addAttribute("height", bm.height());', 'image.addAttribute("height", bm.height());\n            if (nearest) { image.addAttribute("image-rendering", "pixelated"); }', 1)
    device = device.replace('drawBitmapCommon(MxCp(this->localToGlobal(adjustedMatrix), cs), bm, paint);', 'drawBitmapCommon(MxCp(this->localToGlobal(adjustedMatrix), cs), bm, paint,\n                     !sampling.useCubic && sampling.filter == SkFilterMode::kNearest);', 1)
    device = device.replace('const SkSamplingOptions&,\n                              const SkPaint& paint,', 'const SkSamplingOptions& sampling,\n                              const SkPaint& paint,', 1)
    device = device.replace('bm, *imagePaint);', 'bm, *imagePaint,\n                           !sampling.useCubic && sampling.filter == SkFilterMode::kNearest);', 1)
    (directory / 'SkSVGDevice.cpp').write_text(device, encoding='utf-8', newline='\n')
    canvas = (source / 'src/svg/SkSVGCanvas.cpp').read_text(encoding='utf-8').replace('#include "src/svg/SkSVGDevice.h"', '#include "SkSVGDevice.h"')
    (directory / 'SkSVGCanvas.cpp').write_text(canvas, encoding='utf-8', newline='\n')
    for filename in ('SkSVGDevice.cpp', 'SkSVGCanvas.cpp'):
        count = 0
        for ninja in build.rglob('*.ninja'):
            content = ninja.read_text(encoding='utf-8')
            content, changes = re.subn(r'(?<=: cxx )[^\n ]*src/svg/' + re.escape(filename), 'compat/' + filename, content)
            if changes:
                ninja.write_text(content, encoding='utf-8', newline='\n')
                count += changes
        if count != 1:
            raise ValueError(f'Expected one SVG compile rule for {filename}, found {count}')
    print('SVG nearest-neighbor sampling compatibility sources staged in', directory)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--skia-root', type=Path, required=True)
    parser.add_argument('--build-dir', type=Path, required=True)
    parser.add_argument('--svg-only', action='store_true')
    args = parser.parse_args()
    if not args.svg_only:
        prepare_directwrite(args.skia_root, args.build_dir)
    prepare_svg_sampling(args.skia_root, args.build_dir)

    metadata = {'patches': ['svg-nearest-neighbor'] + ([] if args.svg_only else ['directwrite-constexpr']),
                'source_sha256': {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                                  for p in (args.build_dir / 'compat').glob('*') if p.suffix in ('.cpp', '.h')}}
    (args.build_dir / 'compat/manifest.json').write_text(json.dumps(metadata, indent=2) + '\n', encoding='utf-8')
