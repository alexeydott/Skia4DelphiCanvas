"""Generate pinned Unicode 17.0.0 script, bidi and default-ignorable tables.
Source: unicode.org/Public/17.0.0/ucd; see src/UNICODE-LICENSE.txt.
"""
from pathlib import Path
import re, urllib.request
ROOT=Path(__file__).resolve().parent.parent
CACHE=ROOT/'.build/unicode17'
CACHE.mkdir(parents=True,exist_ok=True)
def read(name):
 p=CACHE/Path(name).name
 if not p.exists(): urllib.request.urlretrieve('https://www.unicode.org/Public/17.0.0/ucd/'+name,p)
 return p.read_text(encoding='utf-8')
def entries(text):
 for line in text.splitlines():
  line=line.split('#')[0].strip()
  if not line: continue
  code,value,*_=map(str.strip,line.split(';'))
  ends=code.split('..');yield int(ends[0],16),int(ends[-1],16),value
def ranges(values):
 start=0
 for i in range(1,len(values)+1):
  if i==len(values) or values[i]!=values[start]:
   yield start,i-1,values[start];start=i
scripts=['Unknown']*0x110000
for a,b,v in entries(read('Scripts.txt')): scripts[a:b+1]=[v]*(b-a+1)
bidi=['L']*0x110000
text=read('extracted/DerivedBidiClass.txt')
alias={'Left_To_Right':'L','Right_To_Left':'R','Arabic_Letter':'AL','European_Terminator':'ET'}
for a,b,v in re.findall(r'@missing:\s*([0-9A-F]+)\.\.([0-9A-F]+);\s*(\w+)',text):
 a,b=int(a,16),int(b,16);bidi[a:b+1]=[alias.get(v,v)]*(b-a+1)
for a,b,v in entries(text): bidi[a:b+1]=[v]*(b-a+1)
ignorables=['N']*0x110000
for a,b,v in entries(read('DerivedCoreProperties.txt')):
 if v=='Default_Ignorable_Code_Point': ignorables[a:b+1]=['Y']*(b-a+1)
samples={}
for line in read('UnicodeData.txt').splitlines():
 f=line.split(';'); cp=int(f[0],16)
 if bidi[cp] in ('R','AL') and scripts[cp] not in ('Common','Inherited','Unknown') and f[2].startswith('L'):
  samples.setdefault(scripts[cp],cp)
names=sorted(set(scripts)); script_ids={v:i for i,v in enumerate(names)}
bidi_names=['L','R','AL','EN','ES','ET','AN','CS','NSM','BN','B','S','WS','ON','LRE','LRO','RLE','RLO','PDF','LRI','RLI','FSI','PDI']
lines=['{ Generated from Unicode 17.0.0. See UNICODE-LICENSE.txt. }','const',"  SkiaUnicodeVersion = '17.0.0';"]
lines+=['  UnicodeUnknownScript = %d;' % script_ids['Unknown']]
lines+=['  UnicodeScriptNames: array[0..%d] of string = ('%(len(names)-1), ',\n'.join("    '%s'"%n for n in names)+');']
for label,vals,ids,default in [('Script',scripts,script_ids,'Unknown'),('Bidi',bidi,{v:i for i,v in enumerate(bidi_names)},'L'),('Ignorable',ignorables,{'N':0,'Y':1},'N')]:
 rows=[(a,b,ids[v]) for a,b,v in ranges(vals) if v!=default]
 lines+=['  Unicode%sRanges: array[0..%d] of TSkiaUnicodeRange = ('%(label,len(rows)-1), ',\n'.join('    (First:$%X; Last:$%X; Value:%d)'%r for r in rows)+');']
lines+=['  UnicodeRTLSamples: array[0..%d] of Cardinal = ('%(len(samples)-1), ','.join('$%X'%v for k,v in sorted(samples.items()))+');']
(ROOT/'src/SkiaCanvas.UnicodeData.inc').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print('RTL scripts:',len(samples),', '.join(sorted(samples)))



