"""Compare parser playback with Windows GDI and rendered PDF/SVG exports.

Run the native tests first. Use --render on Linux or Windows with WSL, Poppler
and librsvg installed. Outputs include numerical metrics and amplified difference
images; native GDI rejection is reported separately from image agreement.
"""
import argparse
import json
import re
import hashlib
import os
import subprocess
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageStat, ImageFilter
from pypdf import PdfReader
import xml.etree.ElementTree as ET


def pdf_image_count(resources, seen=None):
    """Count image XObjects, including nested forms, without decoding their pixels."""
    if seen is None:
        seen = set()
    if hasattr(resources, 'get_object'):
        resources = resources.get_object()
    objects = resources.get('/XObject', {})
    if hasattr(objects, 'get_object'):
        objects = objects.get_object()
    count = 0
    for reference in objects.values():
        obj = reference.get_object()
        if id(obj) in seen:
            continue
        seen.add(id(obj))
        if obj.get('/Subtype') == '/Image':
            count += 1
        elif obj.get('/Subtype') == '/Form':
            count += pdf_image_count(obj.get('/Resources', resources), seen)
    return count


def max_channel_histogram(image):
    red, green, blue = image.split()
    return ImageChops.lighter(ImageChops.lighter(red, green), blue).histogram()


def metrics(actual, expected):
    diff = ImageChops.difference(actual, expected)
    pixel_histogram = max_channel_histogram(diff)
    pixel_count = actual.width * actual.height
    small = (actual.width // 8, actual.height // 8)
    coarse = ImageChops.difference(actual.resize(small, Image.Resampling.BOX),
                                  expected.resize(small, Image.Resampling.BOX))
    return {
        "mean_channel_error": sum(ImageStat.Stat(diff).mean) / 3,
        "different_pixels": pixel_count - pixel_histogram[0],
        "severe_pixel_fraction": sum(pixel_histogram[46:]) / pixel_count,
        "severe_block_fraction": sum(max_channel_histogram(coarse)[46:]) / (small[0] * small[1]),
    }, diff


def paired_text_geometry(actual, expected):
    """Compare blue text independently of the red current-point test line.

    GDI's aliased cosmetic line and Skia's AA line can differ by a pixel. The
    page comparison still checks that line; this stricter check isolates glyphs
    so line rasterization cannot hide misplaced paired text advances.
    """
    masks = []
    small = (actual.width // 8, actual.height // 8)
    for image in (actual, expected):
        red, green, blue = image.split()
        ink = ImageChops.subtract(blue, ImageChops.lighter(red, green))
        masks.append(ink.point(lambda value: 0 if value > 16 else 255).resize(small, Image.Resampling.BOX))
    diff = ImageChops.difference(*masks)
    return {"severe_block_fraction": sum(diff.histogram()[46:]) / (small[0] * small[1])}


def opaque_background_geometry(actual, expected):
    """Check each regression background separately, allowing only edge AA.

    The two text records use different colors so overlap/order mistakes cannot
    hide behind the same full-page opaque area or the foreground glyphs.
    """
    scores = {}
    small = (actual.width // 8, actual.height // 8)
    for label, color in (('first', (255, 255, 176)), ('second', (176, 255, 224))):
        masks = []
        for image in (actual, expected):
            red, green, blue = ImageChops.difference(image, Image.new('RGB', image.size, color)).split()
            distance = ImageChops.lighter(ImageChops.lighter(red, green), blue)
            masks.append(distance.point(lambda value: 255 if value <= 24 else 0))
        # GDI's integer polygon edges and AA export edges can select adjacent
        # boundary pixels, particularly after reflection. Compare interiors
        # beyond a one-device-pixel halo instead of counting that edge phase.
        missing = ImageChops.subtract(masks[0], masks[1].filter(ImageFilter.MaxFilter(3)))
        extra = ImageChops.subtract(masks[1], masks[0].filter(ImageFilter.MaxFilter(3)))
        unmatched = ImageChops.lighter(missing, extra).resize(small, Image.Resampling.BOX)
        histogram = unmatched.histogram()
        scores[label] = sum(histogram[46:]) / (small[0] * small[1])
    return scores


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--log", type=Path)
    parser.add_argument("--render", action="store_true")
    parser.add_argument("--scale", choices=("both", "1", "2"), default="both",
                        help="Verify one rendered scale or both (default)")
    parser.add_argument("--reference-root", type=Path, default=Path(__file__).resolve().parent.parent / "tests/build/emf-reference")
    parser.add_argument("--fixtures", type=Path, default=Path(__file__).resolve().parent.parent / "tests/fixtures/emf")
    args = parser.parse_args()
    root = args.directory.resolve()
    manifest = {entry['name']: entry for entry in json.loads((args.reference_root / 'manifest.json').read_text())}
    accepted = {}
    if args.log:
        log_bytes = args.log.read_bytes()
        log_encoding = 'utf-16' if log_bytes.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig'
        log_text = log_bytes.decode(log_encoding, errors='replace')
        for name, w, h, status in re.findall(r"EMF (.*?) @(\d+)x(\d+):.*?native=(TRUE|FALSE)", log_text):
            accepted[(name, int(w), int(h))] = status == "TRUE"
    report = []
    failures = []
    fixtures = {path.stem for path in args.fixtures.glob('*.emf')}
    for reference in sorted(root.rglob("*-gdi.bmp")):
        name = reference.stem.removesuffix("-gdi")
        # Retired fixtures can leave outputs from a previous native run.
        if name not in fixtures:
            continue
        base = reference.parent / name
        actual = Image.open(base.with_suffix(".bmp")).convert("RGB")
        if args.scale != "both" and actual.width != 384 * int(args.scale):
            continue
        native = Image.open(reference).convert("RGB")
        reference_path = args.reference_root / ("2x" if actual.width == 768 else "") / (name + "-reference.bmp")
        expected = Image.open(reference_path).convert("RGB")
        if name.startswith(('test_records_', 'polytextout', 'smalltextout',
                            'exttextoutw_affine_combined_', 'exttextoutw_justification')) and not any(
                                low < 255 for low, high in expected.getextrema()):
            failures.append(f'Coverage control must draw visible content: {base}')
        source = args.fixtures / (name + ".emf")
        if hashlib.sha256(source.read_bytes()).hexdigest() != manifest[name]['sha256']:
            raise ValueError(f"Reference is stale: {source}")
        if actual.size != expected.size:
            raise ValueError(f"Image dimensions differ: {base}")
        score, diff = metrics(actual, expected)
        # Raster Boolean operations must agree exactly, without AA tolerances.
        recovered = manifest[name]['scales']['2' if actual.width == 768 else '1']
        exact = bool(recovered) or name.startswith(("bitblt_", "maskblt_", "patblt_", "plgblt_", "stretchblt_", "extcreatepen_",
                "test_records_setpixel", "test_records_alphablend", "test_records_transparentblt", "test_records_setdibitstodevice"))
        # Mixed-direction strings can keep the same opaque rectangle while
        # moving only a few glyphs. Tighten the reference check for this matrix
        # so lost RTL processing cannot hide inside the page-wide AA allowance.
        paired = name.startswith(('exttextoutw_index_rtl_pdy_', 'polytextout', 'smalltextout', 'exttextoutw_justification'))
        reference_limit = .002 if name.startswith('exttextoutw_index_rtl_') and not paired else .01
        ok = score["different_pixels"] == 0 if exact else score["severe_block_fraction"] < reference_limit
        text_score = paired_text_geometry(actual, expected) if paired else None
        if text_score is not None:
            ok = ok and text_score["severe_block_fraction"] < .002
        entry = {"name": name, "size": actual.size, "reference_accepted": accepted.get((name, *actual.size)),
                 "exact_required": exact, "reference": score, "native_gdi": metrics(actual, native)[0],
                 "sha256": manifest[name]['sha256'], "recoveries": recovered, "passed": ok}
        if text_score is not None:
            entry['text_reference'] = text_score
        if name.startswith(('exttextoutw_index_rtl_pdy_vertical_opaque_', 'exttextoutw_index_rtl_pdy_affine_opaque_', 'exttextoutw_affine_combined_')):
            background_score = opaque_background_geometry(actual, expected)
            entry['background_reference'] = background_score
            ok = ok and all(value < .002 for value in background_score.values())
            entry['passed'] = ok
        if not ok:
            failures.append(f"Complete reference: {base}")
        diff = diff.point(lambda x: min(255, x * 4))
        diff.save(base.parent / (name + "-diff.png"))
        panels = [("Complete reference", expected), ("Skia parser", actual), ("Difference x4", diff)]
        if recovered:
            panels.insert(0, ("Original GDI (record errors)", native))
            ImageChops.difference(expected, native).point(lambda x: min(255, x * 4)).save(base.parent / (name + "-native-missing.png"))
        sheet = Image.new("RGB", (actual.width * len(panels), actual.height + 24), "white")
        draw = ImageDraw.Draw(sheet)
        for i, (label, im) in enumerate(panels):
            draw.text((i * actual.width + 4, 5), label, fill="black")
            sheet.paste(im, (i * actual.width, 24))
        sheet.save(base.parent / (name + "-compare.png"))
        pdf = PdfReader(base.with_suffix(".pdf"))
        if len(pdf.pages) != 1 or tuple(round(float(v)) for v in (pdf.pages[0].mediabox.width, pdf.pages[0].mediabox.height)) != actual.size:
            failures.append(f"PDF dimensions: {base}")
        svg = ET.parse(base.with_suffix(".svg")).getroot()
        ns = '{http://www.w3.org/2000/svg}'
        entry['vector'] = {
            'svg_paths': len(svg.findall('.//' + ns + 'path')),
            'svg_images': len(svg.findall('.//' + ns + 'image')),
            'svg_text': len(svg.findall('.//' + ns + 'text')),
            'pdf_images': pdf_image_count(pdf.pages[0].get('/Resources', {})),
        }
        if name.startswith(('exttextout', 'polytextout', 'smalltextout')) or name == 'test_records_setpixel':
            vector = entry['vector']
            vector['visible_content'] = any(low < 255 for low, high in expected.getextrema())
            if (vector['visible_content'] and not vector['svg_paths']) or vector['svg_images'] or vector['svg_text'] or vector['pdf_images']:
                failures.append(f'Text/pixel control must remain vector outlines: {base}')
        if args.render:
            renderer = ['wsl'] if os.name == 'nt' else []
            render_path = "/mnt/" + str(base)[0].lower() + str(base)[2:].replace("\\", "/") if renderer else str(base)
            subprocess.run([*renderer, "pdftoppm", "-r", "72", "-singlefile", "-png", render_path + ".pdf", render_path + "-pdf"], check=True, capture_output=True)
            # Poppler's 72 dpi edge quantization strongly darkens subpixel text.
            # Keep that rendering, and use a 2x rendering downsampled to the
            # target size for the geometry assertion. This does not blur or
            # alter the GDI reference comparison above.
            subprocess.run([*renderer, "pdftoppm", "-r", "144", "-singlefile", "-png", render_path + ".pdf", render_path + "-pdf-aa"], check=True, capture_output=True)
            with Image.open(base.parent / (name + "-pdf-aa.png")) as doubled:
                if doubled.size != (actual.width * 2, actual.height * 2):
                    raise ValueError(f"PDF supersample dimensions: {base}")
                doubled.convert("RGB").resize(actual.size, Image.Resampling.LANCZOS).save(base.parent / (name + "-pdf-aa.png"))
            subprocess.run([*renderer, "rsvg-convert", render_path + ".svg", "-o", render_path + "-svg.png"], check=True, capture_output=True)
        for kind in ("pdf", "svg"):
            rendered = base.parent / (name + "-" + kind + ".png")
            if not rendered.exists():
                continue
            im = Image.open(rendered).convert("RGB")
            if im.size != actual.size:
                failures.append(f"{kind} image dimensions: {base}")
                continue
            export_score, export_diff = metrics(im, actual)
            entry[kind] = export_score
            export_diff.point(lambda x: min(255, x * 4)).save(base.parent / (name + "-" + kind + "-diff.png"))
            if kind == "pdf" and (base.parent / (name + "-pdf-aa.png")).exists():
                aa = Image.open(base.parent / (name + "-pdf-aa.png")).convert("RGB")
                export_score, aa_diff = metrics(aa, actual)
                entry["pdf_supersampled"] = export_score
                aa_diff.point(lambda x: min(255, x * 4)).save(base.parent / (name + "-pdf-aa-diff.png"))
            if export_score["severe_block_fraction"] >= .01:
                failures.append(f"{kind} geometry: {base}")
            if name.startswith(('exttextoutw_index_rtl_pdy_vertical_opaque_', 'exttextoutw_index_rtl_pdy_affine_opaque_', 'exttextoutw_affine_combined_')):
                exported = aa if kind == 'pdf' and 'pdf_supersampled' in entry else im
                background = opaque_background_geometry(exported, actual)
                text = paired_text_geometry(exported, actual)
                entry.setdefault('opaque_exports', {})[kind] = {'background': background, 'text': text}
                if any(value >= .002 for value in background.values()) or text['severe_block_fraction'] >= .002:
                    failures.append(f'{kind} opaque text/background geometry: {base}')
        sibling = name.replace('_glyph_rtl_', '_glyph_', 1)
        sibling_bitmap = base.parent / (sibling + '.bmp')
        if name.startswith('exttextoutw_index_rtl_') and '_glyph_rtl_' in name and sibling_bitmap.exists():
            # ETO_GLYPH_INDEX bypasses language processing: adding RTLREADING
            # must not reverse the glyph IDs or their advances. Check exact
            # equality independently of the ordinary AA geometry tolerance.
            checks = {}
            sibling_reference = reference_path.with_name(sibling + '-reference.bmp')
            with Image.open(sibling_reference) as other:
                checks['reference'] = ImageChops.difference(expected, other.convert('RGB')).getbbox() is None
            with Image.open(sibling_bitmap) as other:
                checks['bitmap'] = ImageChops.difference(actual, other.convert('RGB')).getbbox() is None
            if args.render:
                for kind in ('pdf-aa', 'svg'):
                    with Image.open(base.parent / (name + '-' + kind + '.png')) as image, \
                         Image.open(base.parent / (sibling + '-' + kind + '.png')) as other:
                        checks[kind] = ImageChops.difference(image.convert('RGB'), other.convert('RGB')).getbbox() is None
            entry['glyph_rtl_equivalence'] = checks
            if not all(checks.values()):
                failures.append(f'Glyph-index RTL equivalence: {base}')
        report.append(entry)
        print(f"{name} {actual.size}: complete reference {'PASS' if ok else 'FAIL'}, original GDI={entry['reference_accepted']}", flush=True)
    if not report:
        raise ValueError("No reference image pairs found")
    scales = (1, 2) if args.scale == 'both' else (int(args.scale),)
    expected_cases = {(name, (384 * scale, 256 * scale)) for name in fixtures for scale in scales}
    actual_cases = {(entry['name'], tuple(entry['size'])) for entry in report}
    if expected_cases != actual_cases or len(report) != len(expected_cases):
        failures.append(f'Incomplete fixture coverage: {len(actual_cases)} / {len(expected_cases)} cases')
    result = {"comparisons": report, "failures": failures}
    (root / "image-comparison.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(f"{len(report)} image pairs; {len(failures)} failures; {sum(e['reference_accepted'] is False for e in report)} original GDI playbacks reported record errors")
    for failure in failures:
        print(failure)
    raise SystemExit(bool(failures))


if __name__ == "__main__":
    main()
