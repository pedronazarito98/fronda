"""Export alpha normalization only: preserve original art and remove stray matte pixels."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFilter,ImageChops
import numpy as np,json
R=Path(__file__).resolve().parents[1]

def contour(mask):
 m=np.pad(mask,1);ys,xs=np.where(mask);edges={}
 for y,x in zip(ys.tolist(),xs.tolist()):
  if not m[y,x+1]:edges[(x,y)]=(x+1,y)
  if not m[y+1,x+2]:edges[(x+1,y)]=(x+1,y+1)
  if not m[y+2,x+1]:edges[(x+1,y+1)]=(x,y+1)
  if not m[y+1,x]:edges[(x,y+1)]=(x,y)
 loops=[]
 while edges:
  start=next(iter(edges));p=start;loop=[]
  while p in edges:
   loop.append(p);p=edges.pop(p)
   if p==start:break
  if len(loop)>50:loops.append(loop)
 return max(loops,key=len)
reports=[]
for folder,files in [('brand-masters',['symbol-sculpted','app-icon-master']),('mascot',['master','welcome','focus','rest'])]:
 dest=R/folder/'exports';dest.mkdir(exist_ok=True)
 for name in files:
  src=R/folder/f'{name}.png'
  if not src.exists():continue
  im=Image.open(src).convert('RGBA');a=im.getchannel('A');solid=np.asarray(a)>160
  boundary=contour(solid)
  clip=Image.new('L',im.size);ImageDraw.Draw(clip).polygon(boundary,fill=255)
  # One source-pixel inward mask guards against mixed matte color at the edge.
  clip=clip.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(.45))
  im.putalpha(ImageChops.multiply(a,clip))
  im.save(dest/f'{name}.png',optimize=True)
  reports.append({'source':str(src.relative_to(R)),'output':str((dest/f'{name}.png').relative_to(R)),'operation':'export silhouette clip; one source pixel inset and 0.45px antialias; no change to interior RGB','size':im.size})
(R/'qa/alpha-export.json').write_text(json.dumps(reports,indent=2))
print('Normalized exports:',len(reports))
