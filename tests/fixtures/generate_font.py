"""Generate an original minimal font fixture; no third-party glyph artwork."""
from pathlib import Path
import sys
# Optional local dependency directory; otherwise use the installed fontTools.
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'.build/fonttools'))
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import newTable
from fontTools.ttLib.tables._k_e_r_n import KernTable_format_0
names=['.notdef','space','A','V','i']
fb=FontBuilder(1000,isTTF=True);fb.setupGlyphOrder(names)
fb.setupCharacterMap({32:'space',65:'A',86:'V',105:'i'})
glyphs={}
for name in names:
 p=TTGlyphPen(None)
 if name!='space':
  points=[(0,0),(300,700),(600,0)] if name=='A' else [(0,700),(300,0),(600,700)] if name=='V' else [(0,0),(0,500),(120,500),(120,0)]
  p.moveTo(points[0])
  for pt in points[1:]:p.lineTo(pt)
  p.closePath()
 glyphs[name]=p.glyph()
fb.setupGlyf(glyphs)
fb.setupHorizontalMetrics({n:((150 if n=='i' else 300 if n=='space' else 600),0) for n in names})
fb.setupHorizontalHeader(ascent=800,descent=-200)
fb.setupNameTable({'familyName':'SkiaCanvas Fixture','styleName':'Regular',
 'uniqueFontIdentifier':'SkiaCanvasFixture-Regular-1','fullName':'SkiaCanvas Fixture Regular',
 'psName':'SkiaCanvasFixture-Regular','version':'Version 1.0'})
fb.setupOS2(sTypoAscender=800,sTypoDescender=-200,usWinAscent=800,usWinDescent=200)
fb.setupPost();fb.setupMaxp()
k=newTable('kern');k.version=0;t=KernTable_format_0();t.version=0;t.coverage=1;t.kernTable={('A','V'):-150,('V','A'):-120};k.kernTables=[t];fb.font['kern']=k
out=Path(__file__).with_name('SkiaFixture.ttf');out.parent.mkdir(exist_ok=True);fb.save(out)
print(out,out.stat().st_size)

from fontTools.ttLib import TTFont,TTCollection
from pathlib import Path
p=out
a,b=TTFont(p),TTFont(p)
for table in b['cmap'].tables:
 if table.isUnicode(): table.cmap={0x20:'space',0x4e2d:'A',0x6587:'V'}
for record in b['name'].names:
 if record.nameID in (1,4,6,16):
  name='SkiaCanvas CJK Fixture' if record.nameID!=6 else 'SkiaCanvasCJKFixture'
  record.string=name.encode(record.getEncoding())
c=TTCollection();c.fonts=[a,b];c.save(out.with_name('SkiaCjkFixture.ttc'))
