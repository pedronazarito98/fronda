from pathlib import Path
from PIL import Image,ImageDraw
import json,shutil
R=Path(__file__).resolve().parents[1]
source=Image.open(R/'brand-masters/exports/app-icon-master.png').convert('RGBA')
source=source.crop(source.getchannel('A').point(lambda a:255 if a>64 else 0).getbbox());source.thumbnail((896,896),Image.Resampling.LANCZOS)
master=Image.new('RGBA',(1024,1024));master.alpha_composite(source,((1024-source.width)//2,(1024-source.height)//2));master.save(R/'icons/app-icon-1024.png')
f=Image.open(R/'logos/symbol-primary.png').convert('RGBA');f.thumbnail((600,754),Image.Resampling.LANCZOS)
micro=Image.new('RGBA',(1024,1024));ImageDraw.Draw(micro).rounded_rectangle((64,64,960,960),radius=204,fill='#526048')
flat=Image.new('RGBA',f.size,'#EEE8DA');flat.putalpha(f.getchannel('A'));micro.alpha_composite(flat,((1024-f.width)//2,135))
iconset=R/'icons/macos/Fronda.iconset';catalog=R/'icons/macos/AppIcon.appiconset'
iconset.mkdir(exist_ok=True);catalog.mkdir(exist_ok=True);entries=[]
for base in [16,32,128,256,512]:
 for scale in [1,2]:
  size=base*scale;name=f'icon_{base}x{base}'+('@2x' if scale==2 else '')+'.png';im=(micro if base==16 else master).resize((size,size),Image.Resampling.LANCZOS);im.save(iconset/name);shutil.copy(iconset/name,catalog/name);entries.append({'filename':name,'idiom':'mac','scale':f'{scale}x','size':f'{base}x{base}'})
(catalog/'Contents.json').write_text(json.dumps({'images':entries,'info':{'author':'Fronda','version':1}},indent=2))
for size in [16,24,32,48,64,128,256,512,1024]:
 (micro if size<=24 else master).resize((size,size),Image.Resampling.LANCZOS).save(R/f'icons/web/fronda-{size}.png')
micro.save(R/'icons/web/favicon.ico',sizes=[(16,16),(32,32),(48,48)])
# Touch icon uses a full, square background; the platform applies its mask.
touch=Image.new('RGBA',(180,180),'#526048');cut=Image.open(R/'brand-masters/exports/symbol-sculpted.png').convert('RGBA');cut=cut.crop(cut.getchannel('A').point(lambda a:255 if a>64 else 0).getbbox());cut.thumbnail((116,142),Image.Resampling.LANCZOS);touch.alpha_composite(cut,((180-cut.width)//2,(180-cut.height)//2));touch.convert('RGB').save(R/'icons/web/apple-touch-icon.png')
paths=json.loads((R/'source/symbol-paths.json').read_text());scale=754/paths['height'];x=(1024-paths['width']*scale)/2
(R/'icons/web/favicon.svg').write_text(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024"><rect x="64" y="64" width="896" height="896" rx="204" fill="#526048"/><path transform="translate({x} 135) scale({scale})" fill="#EEE8DA" d="{paths["paths"][0]}"/></svg>')
print('Classic macOS slots, web icons, ICO and touch icon exported.')
