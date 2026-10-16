"""Compare every native Linux demo PDF/SVG page with its raster scene.

Run render_fpc_exports.sh first. Uses 8x8 block averages so different edge
rasterizers can differ at glyph and path boundaries, while missing fills,
wrong channels, clipping, misplaced text and lost pages still fail.
"""
import argparse
from pathlib import Path
from xml.etree import ElementTree as ET
from PIL import Image, ImageChops, ImageStat
from verify_fpc_exports import NAMES


def compare(reference, rendered):
    expected = Image.open(reference).convert("RGB")
    actual = Image.open(rendered).convert("RGB")
    if (rendered.name.startswith("atlas-aa-") or rendered.name=="quickstart-aa.png"):
        assert actual.size == tuple(d*2 for d in expected.size), (rendered.name,actual.size)
        actual=actual.resize(expected.size,Image.Resampling.LANCZOS)
    assert actual.size == expected.size, (rendered.name, actual.size, expected.size)
    size = tuple((dimension + 7) // 8 for dimension in expected.size)
    difference = ImageChops.difference(
        expected.resize(size, Image.Resampling.BOX),
        actual.resize(size, Image.Resampling.BOX),
    )
    mean = sum(ImageStat.Stat(difference).mean) / 3
    pixels = list(difference.getdata())
    bad_fraction = sum(max(pixel) > 24 for pixel in pixels) / len(pixels)
    print(f"{rendered.name}: block RGB mean={mean:.3f}; bad={bad_fraction:.3%}")
    assert mean < 2 and bad_fraction < 0.02, (rendered.name, mean, bad_fraction)


def check(directory):
    ns = '{http://www.w3.org/2000/svg}'
    quickstart = ET.parse(directory / 'quickstart.svg').getroot()
    gradients = quickstart.findall('.//' + ns + 'linearGradient')
    assert gradients, 'Quickstart gradient must remain vector geometry'
    assert not quickstart.findall('.//' + ns + 'image'), 'Quickstart has raster fragments'
    gradient_ids = {gradient.attrib['id'] for gradient in gradients}
    assert any(element.attrib.get('fill') == f'url(#{gradient_id})'
               for element in quickstart.iter() for gradient_id in gradient_ids), 'Unused gradient definitions'
    for name in ('skia_demo', '03-brushes'):
        svg = ET.parse(directory / (name + '.svg')).getroot()
        assert svg.findall('.//' + ns + 'linearGradient'), name + ': missing vector gradients'
    pdf = directory / "skia_demo.pdf"
    digits = len(str(len(NAMES)))
    for page, name in enumerate(NAMES, 1):
        preview = directory / f"atlas-aa-{page:0{digits}d}.png"
        svg_preview = directory / f"{name}-preview.png"
        assert preview.stat().st_mtime >= pdf.stat().st_mtime, "Stale PDF rendering"
        assert svg_preview.stat().st_mtime >= (directory / f"{name}.svg").stat().st_mtime, "Stale SVG rendering"
        compare(directory / f"{name}.bmp", preview)
        compare(directory / f"{name}.bmp", svg_preview)
    for name in ("quickstart-aa.png", "quickstart-preview.png"):
        compare(directory / "quickstart.bmp", directory / name)
    print("PASS: all 12 atlas pages and quickstart agree across raster, PDF and SVG")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    check(parser.parse_args().directory)
