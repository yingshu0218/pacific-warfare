from pathlib import Path
import fitz
from PIL import Image, ImageDraw
import sys
base=Path('docs/references/aircraft/b25j_1944_07')
r=fitz.open(base/'originals/b25j-flight-instructions.pdf')
args=[int(x) for x in sys.argv[1:]]
if args:
 for n in args:
  r[n-1].get_pixmap(matrix=fitz.Matrix(1.5,1.5)).save(base/f'manual-pages/p{n:03d}.png')
else:
 for start in [0,16,32,48,64,80,96,112]:
  page=Image.new('RGB',(1600,1600),'white'); d=ImageDraw.Draw(page)
  for j,i in enumerate(range(start,min(start+16,len(r)))):
   pix=r[i].get_pixmap(matrix=fitz.Matrix(0.43,0.43))
   img=Image.frombytes('RGB',(pix.width,pix.height),pix.samples);img.thumbnail((390,365))
   x=(j%4)*400;y=(j//4)*400
   page.paste(img,(x,y+25));d.text((x+8,y+5),f'PDF page {i+1}',fill='black')
  page.save(base/f'manual-pages/contact-{start+1:03d}.jpg')
print('AV04 original manual pages rendered; no engine/browser')
