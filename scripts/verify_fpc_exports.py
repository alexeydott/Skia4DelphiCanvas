"""Validate native FPC demo exports; requires Pillow and pypdf.
Run after demo/run_demos_fpc.cmd, from any working directory.
"""
from pathlib import Path
import argparse
import re
from xml.etree import ElementTree as ET
from PIL import Image
from pypdf import PdfReader

ROOT = Path(__file__).resolve().parent.parent
NAMES = ['skia_demo', '02-primitives', '03-brushes', '04-pens',
         '05-transfers', '06-clips-transforms', '07-text-fonts',
         '08-raster-resources', '09-rop-formatting', '10-unicode-fonts', '11-unicode-rtl', '12-text-on-path']
NS = '{http://www.w3.org/2000/svg}'

def check(directory):
    pdf = PdfReader(directory / 'skia_demo.pdf', strict=True)
    assert len(pdf.pages) == len(NAMES), 'Atlas PDF page count'
    for page, name in zip(pdf.pages, NAMES):
        assert list(page.mediabox) == [0, 0, 1000, 1280], name
        bitmap = Image.open(directory / (name + '.bmp')).convert('RGB')
        assert bitmap.size == (1000, 1280), name
        assert len(bitmap.resize((100, 128)).getcolors(12800)) > 30, name
        svg = ET.parse(directory / (name + '.svg')).getroot()
        assert svg.attrib['width'] == '1000' and svg.attrib['height'] == '1280', name
        # Native Skia may merge a shaped run into one path; count contours, not elements.
        contours=sum(len(re.findall('[Mm]',path.attrib.get('d',''))) for path in svg.findall('.//' + NS + 'path'))
        assert contours > 100, (name,contours)
        assert not svg.findall('.//' + NS + 'text'), name + ': font-dependent SVG text'
        if name in ('07-text-fonts', '12-text-on-path'):
            assert not svg.findall('.//' + NS + 'image'), name + ': SVG text contains raster fragments'
            assert not list(page.images), name + ': PDF text contains raster fragments'
        assert (directory / (name + '.skp')).read_bytes().startswith(b'skiapict'), name
    quick = PdfReader(directory / 'quickstart.pdf', strict=True)
    assert len(quick.pages) == 1 and list(quick.pages[0].mediabox) == [0, 0, 600, 360]
    assert Image.open(directory / 'quickstart.bmp').size == (600, 360)
    ET.parse(directory / 'quickstart.svg')
    # Pixel assertions verify the rendered geometry.
    clip = Image.open(directory / '06-clips-transforms.bmp').convert('RGB')
    assert clip.getpixel((255, 320)) == clip.getpixel((60, 320)), 'Excluded clip hole'
    assert clip.getpixel((160, 320)) != clip.getpixel((255, 320)), 'Clip fill interior'
    transfer = Image.open(directory / '05-transfers.bmp').convert('RGB')
    assert transfer.getpixel((345, 1047)) != transfer.getpixel((250, 984)), 'Curved mask'
    rops = Image.open(directory / '09-rop-formatting.bmp').convert('RGB')
    assert rops.getpixel((44, 215)) == (0, 0, 0), 'BLACKNESS'
    assert rops.getpixel((752, 779)) == (0, 0, 255), 'SRCCOPY'
    assert rops.getpixel((44, 920)) == (255, 0, 0), 'PATCOPY'
    # When previews have been rendered, check the exported appearance too.
    for suffix in ('-preview.png',):
        preview = directory / ('05-transfers' + suffix)
        if preview.exists():
            image = Image.open(preview).convert('RGB')
            assert image.getpixel((230, 270)) == (145, 145, 255), 'SVG image opacity'
            pens = Image.open(directory / ('04-pens' + suffix)).convert('RGB')
            counts = [sum(max(pens.getpixel((x, 252+i*24))) < 150
                          for x in range(169, 459)) for i in range(7)]
            assert counts[0] == 290 and counts[5] == 0, 'SVG solid/clear pen'
            assert all(0 < counts[i] < 290 for i in (1, 2, 3, 4)), 'SVG dash gaps'
            image = Image.open(directory / ('06-clips-transforms' + suffix)).convert('RGB')
            assert image.getpixel((255, 320)) == image.getpixel((60, 320)), 'SVG excluded clip'
    pdf_preview = directory / f'atlas-{5:0{len(str(len(pdf.pages)))}d}.png'
    if pdf_preview.exists():
        assert pdf_preview.stat().st_mtime >= (directory / 'skia_demo.pdf').stat().st_mtime, 'Stale PDF preview'
        image = Image.open(pdf_preview).convert('RGB')
        assert image.getpixel((230, 270)) == (145, 145, 255), 'PDF image opacity'
    print('PASS: real PDF pages, SVG contours, BMP pixels and native SKP signatures')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', nargs='?', type=Path,
                        default=ROOT / 'demo/build/fpc-native-win64')
    check(parser.parse_args().directory)

