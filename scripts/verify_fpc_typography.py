"""Check vector text and rendered typography after the native FPC demos.
Requires Pillow, pypdf, and fresh atlas-N.png / NAME-preview.png renderings.
Render the PDF at 72 dpi (pdftoppm) and SVG at native size (rsvg-convert).
"""
import argparse
from pathlib import Path
from PIL import Image
from pypdf import PdfReader
from pdf_content import pdf_operators
from xml.etree import ElementTree as ET
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('directory',nargs='?',type=Path,default=Path(__file__).resolve().parent.parent/'demo/build/fpc-native-win64')
root=parser.parse_args().directory
pdf=PdfReader(root/'skia_demo.pdf',strict=True)
for i,page in enumerate(pdf.pages,1):
 ops=list(pdf_operators(page,pdf))
 assert b'BT' not in ops and b'Tj' not in ops and b'TJ' not in ops, (i,'font text objects')
 assert ops.count(b'm')>100 and ops.count(b'c')>100, (i,'missing vector contours')
 print(f'PDF page {i}: {ops.count(b"m")} contours, {ops.count(b"c")} cubic segments, no text operators')
first_page=f'atlas-{1:0{len(str(len(pdf.pages)))}d}.png'
images=[Image.open(root/f).convert('RGB') for f in ['skia_demo.bmp',first_page,'skia_demo-preview.png']]
assert (root/first_page).stat().st_mtime >= (root/'skia_demo.pdf').stat().st_mtime
assert (root/'skia_demo-preview.png').stat().st_mtime >= (root/'skia_demo.svg').stat().st_mtime
regions={'separate':(44,261,444,320),'kerned':(44,353,444,414),'Arabic':(532,353,710,420),'lam-alef':(792,353,870,420),'combining':(44,600,440,650),'transformed':(44,958,468,1126)}
results={}
for name,rect in regions.items():
 boxes=[]
 for im in images:
  crop=im.crop(rect);mask=Image.new('L',crop.size)
  mask.putdata([255 if max(pixel)<170 else 0 for pixel in crop.getdata()])
  box=mask.getbbox();assert box is not None,(name,'empty text region');boxes.append(box)
 for box in boxes[1:]: assert max(abs(a-b) for a,b in zip(boxes[0],box))<=2,(name,boxes)
 results[name]=boxes
 print(name,'BMP/PDF/SVG bounds:',boxes)
for i in range(3):
 raw=results['separate'][i]; kern=results['kerned'][i]
 assert raw[2]-raw[0]>kern[2]-kern[0],('kerning',i,raw,kern)
assert not ET.parse(root/'skia_demo.svg').findall('.//{http://www.w3.org/2000/svg}text')
print('PASS: real vector text, pair kerning, Arabic/ligature/combining/transform appearance across BMP, PDF and SVG')

# Check the added CJK and cursive examples in every native output format.
if len(pdf.pages) >= 10:
    page_name=f'atlas-{10:0{len(str(len(pdf.pages)))}d}.png'
    unicode_images=[Image.open(root/f).convert('RGB') for f in
                    ['10-unicode-fonts.bmp',page_name,'10-unicode-fonts-preview.png']]
    assert (root/page_name).stat().st_mtime >= (root/'skia_demo.pdf').stat().st_mtime
    assert (root/'10-unicode-fonts-preview.png').stat().st_mtime >= (root/'10-unicode-fonts.svg').stat().st_mtime
    for name,rect in {'matched CJK':(44,348,470,378),'TTC CJK':(532,360,940,410),
                      'Arabic OpenType':(44,970,470,1018),'Persian OpenType':(44,1048,470,1096)}.items():
        boxes=[]
        for image in unicode_images:
            crop=image.crop(rect);mask=Image.new('L',crop.size)
            mask.putdata([255 if max(pixel)<170 else 0 for pixel in crop.getdata()])
            box=mask.getbbox();assert box is not None,(name,'missing outlines');boxes.append(box)
            assert sum(mask.getdata())>255*100,(name,'insufficient glyph coverage')
        assert all(max(abs(a-b) for a,b in zip(boxes[0],box))<=2 for box in boxes[1:]),(name,boxes)
        print(name,'BMP/PDF/SVG bounds:',boxes)
    print('PASS: script-matched CJK, TTC face text and Arabic/Persian OpenType contours agree')
