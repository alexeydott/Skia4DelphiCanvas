"""Render and verify all font-settings/pixmap affine regressions (run in WSL)."""
import argparse
import itertools
import json
import math
import re
import subprocess
from pathlib import Path
from xml.etree import ElementTree as ET

from PIL import Image
from pypdf import PdfReader
from verify_emf_images import metrics, pdf_image_count

NS = '{http://www.w3.org/2000/svg}'


def check_mark_anchors(root):
    failures = []
    for path, transform, edging, hinting, subpixel in itertools.product(range(2), range(6), range(3), range(4), range(2)):
        suffix = f'_path{path}_e{edging}_h{hinting}_s{subpixel}_t{transform}_c0.svg'
        plain = ET.parse(root / ('lang2'+suffix)).getroot().findall('.//' + NS + 'path')
        marked = ET.parse(root / ('lang4'+suffix)).getroot().findall('.//' + NS + 'path')
        base_shapes = {node.get('d') for node in plain}
        bases = [node for node in marked if node.get('d') in base_shapes]
        marks = [node for node in marked if node.get('d') not in base_shapes]
        def linear(node):
            return [float(x) for x in re.findall(r'[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?', node.get('transform', ''))][:4]
        if len(bases) != len(plain) or len(marks) < 2:
            failures.append(f'marked path{path} t{transform}: base glyphs or vowel marks missing')
        for base in bases:
            reference = next(node for node in plain if node.get('d') == base.get('d'))
            def matrix6(node):
                return [float(x) for x in re.findall(r'[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?', node.get('transform', ''))]
            left, right = matrix6(base), matrix6(reference)
            if len(left) != 6 or len(right) != 6 or max(abs(a-b) for a,b in zip(left,right)) > .01:
                failures.append(f'marked{suffix}: vowel marks moved base glyph geometry')
        for mark in marks:
            matrix = linear(mark)
            if len(matrix) != 4 or not any(len(linear(base)) == 4 and max(abs(a-b) for a,b in zip(matrix,linear(base))) < 0.0001 for base in bases):
                failures.append(f'marked path{path} t{transform}: vowel mark detached from base tangent')
    return failures


def check(root, text_on_path=False):
    names = {f'text_e{e}_h{h}_s{s}_t{t}_c{c}'
             for e,h,s,t,c in itertools.product(range(3), range(4), range(2), range(6), range(3))}
    names |= {f'pixmap_t{t}_c{c}' for t,c in itertools.product(range(6), range(3))}
    if text_on_path:
        names = {f'path{p}_e{e}_h{h}_s{s}_t{t}_c{c}'
                 for p,e,h,s,t,c in itertools.product(range(2), range(3), range(4), range(2), range(6), range(3))}
    if text_on_path:
        names |= {f'lang{lang}_'+name for lang in (1, 2, 3, 4) for name in tuple(names)}
    assert {p.stem for p in root.glob('*.bmp')} == names, 'Incomplete affine matrix'
    results = []
    failures = []
    contour_baselines = {}
    if text_on_path:
        failures.extend(check_mark_anchors(root))
    if text_on_path:
        for language, path in itertools.product(range(5), range(2)):
            prefix = (f'lang{language}_' if language else '') + f'path{path}'
            alias = Image.open(root / (prefix+'_e0_h0_s0_t0_c0.bmp')).convert('RGB')
            antialias = Image.open(root / (prefix+'_e1_h0_s0_t0_c0.bmp')).convert('RGB')
            if alias.tobytes() == antialias.tobytes():
                failures.append(prefix + ': edging did not change raster pixels')

    for name in sorted(names):
        base = root / name
        svg = ET.parse(base.with_suffix('.svg')).getroot()
        pdf = PdfReader(base.with_suffix('.pdf'))
        assert len(pdf.pages) == 1 and list(pdf.pages[0].mediabox) == [0,0,320,240], name
        vector = dict(svg_images=len(svg.findall('.//' + NS + 'image')),
                      svg_paths=len(svg.findall('.//' + NS + 'path')),
                      svg_text=len(svg.findall('.//' + NS + 'text')),
                      pdf_images=pdf_image_count(pdf.pages[0].get('/Resources', {})))
        text = name.startswith(('text_', 'path', 'lang'))
        if text_on_path and name.endswith('_c0'):
            # Only compare unclipped outlines: backend culling can omit paths
            # fully outside a clip without changing any visible pixels.
            # TextOnPath renders outlines: raster hinting/subpixel cannot move
            # vector contours, even when transforms and clips are composed.
            key = re.sub(r'_h[0-3]_s[01]', '', name)
            contours = tuple(node.get('d') for node in svg.findall('.//' + NS + 'path'))
            baseline = contour_baselines.setdefault(key, contours)
            if contours != baseline:
                failures.append(name + ': hinting/subpixel changed vector contours')
        if text and (vector['svg_images'] or vector['svg_text'] or vector['pdf_images'] or not vector['svg_paths']):
            failures.append(name + ': text rasterized or missing')
        if not text and any(image.get('image-rendering') != 'pixelated' for image in svg.findall('.//' + NS + 'image')):
            failures.append(name + ': nearest sampling lost in SVG')
        if not text and (not vector['svg_images'] or not vector['pdf_images']):
            failures.append(name + ': pixmap missing from export')
        subprocess.run(['pdftoppm','-r','144','-singlefile','-png',str(base)+'.pdf',str(base)+'-pdf-aa'],check=True,capture_output=True)
        subprocess.run(['rsvg-convert',str(base)+'.svg','-o',str(base)+'-svg.png'],check=True,capture_output=True)
        actual = Image.open(base.with_suffix('.bmp')).convert('RGB')
        with Image.open(str(base)+'-pdf-aa.png') as image:
            assert image.size == (640,480),name
            image.convert('RGB').resize((320,240),Image.Resampling.LANCZOS).save(str(base)+'-pdf.png')
        entry = dict(name=name,vector=vector)
        for kind in ('pdf','svg'):
            exported = Image.open(str(base)+'-'+kind+'.png').convert('RGB')
            assert exported.size == (320,240),name
            score,diff = metrics(exported,actual)
            entry[kind] = score
            if text and sum(value < 245 for value in exported.convert('L').tobytes()) <= 10:
                failures.append(name + ': ' + kind + ' visible text missing')
            if score['severe_block_fraction'] >= .01:
                failures.append(name + ': ' + kind + ' geometry')
            if not name.endswith('_c0'):
                outside = 0
                transform = int(re.search(r'_t(\d)', name)[1])
                angle = math.pi/6 if transform == 1 else math.pi/7 if transform == 5 else 0
                sx = -1 if transform == 2 else 1.8 if transform == 4 else -1.4 if transform == 5 else 1
                sy = -1 if transform == 3 else .65 if transform == 4 else .75 if transform == 5 else 1
                for y in range(240):
                    for x in range(320):
                        if name.endswith('_c1'):
                            excluded = x < 143 or x > 176 or y < 88 or y > 151
                        else:
                            dx,dy = x+.5-160,y+.5-120
                            lx = (dx*math.cos(angle)+dy*math.sin(angle))/sx
                            ly = (-dx*math.sin(angle)+dy*math.cos(angle))/sy
                            excluded = abs(lx)>18 or abs(ly)>33
                        if excluded and min(exported.getpixel((x,y))) < 245:
                            outside += 1
                entry[kind]['outside_clip_pixels'] = outside
                if outside:
                    failures.append(name + ': ' + kind + ' device clipping')
        results.append(entry)
        print(name + ': rendered',flush=True)
    report = dict(cases=results,failures=failures)
    (root/'affine-export-comparison.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(f'{len(results)} affine PDF/SVG pairs; {len(failures)} failures')
    for failure in failures:
        print(failure)
    return bool(failures)


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory',type=Path)
    parser.add_argument('--text-on-path', action='store_true')
    args = parser.parse_args()
    raise SystemExit(check(args.directory.resolve(), args.text_on_path))
