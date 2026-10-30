"""Lossless RGB preservation; only matte, framing and delivery-size resampling."""
from pathlib import Path
from PIL import Image, ImageFilter, ImageDraw, ImageFont
import hashlib, json, subprocess
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
original = Image.open(ROOT / 'source/approved-icon.png').convert('RGB')
mask = Image.open(ROOT / 'source/foreground-matte.png').convert('L')
# Keep the warm bevel at the silhouette. Smooth only the segmentation boundary.
mask = mask.filter(ImageFilter.GaussianBlur(4.5)).point(lambda value: 255 if value >= 128 else 0).filter(ImageFilter.GaussianBlur(0.6))
mask = mask.point(lambda value: 0 if value < 3 else 255 if value > 250 else value)
master = original.convert('RGBA')
master.putalpha(mask)
master.save(ROOT / 'master/Fronda-original-rgba.png')
mask.save(ROOT / 'source/final-matte.png')
rgb_delta = np.abs(np.array(master)[:, :, :3].astype(int) - np.array(original).astype(int))
assert int(rgb_delta.max()) == 0
box = mask.point(lambda value: 255 if value >= 128 else 0).getbbox()
cropped = master.crop(box)
cropped.thumbnail((824, 824), Image.Resampling.LANCZOS)
icon = Image.new('RGBA', (1024, 1024))
icon.alpha_composite(cropped, ((1024-cropped.width)//2, (1024-cropped.height)//2))
icon.save(ROOT / 'master/Fronda-1024.png')
for size in [16,24,32,48,64,128,256,512,1024]:
    icon.resize((size,size),Image.Resampling.LANCZOS).save(ROOT/f'web/fronda-{size}.png')
icon.save(ROOT/'web/favicon.ico',sizes=[(16,16),(32,32),(48,48),(64,64),(128,128),(256,256)])
iconset=ROOT/'macos/Fronda.iconset';iconset.mkdir(exist_ok=True)
catalog=ROOT/'macos/AppIcon.appiconset';catalog.mkdir(exist_ok=True)
images=[]
for points in [16,32,128,256,512]:
    for scale in [1,2]:
        name=f'icon_{points}x{points}'+('@2x' if scale==2 else '')+'.png'
        resized=icon.resize((points*scale,points*scale),Image.Resampling.LANCZOS)
        resized.save(iconset/name);resized.save(catalog/name)
        images.append(dict(filename=name,idiom='mac',scale=f'{scale}x',size=f'{points}x{points}'))
(catalog/'Contents.json').write_text(json.dumps(dict(images=images,info=dict(author='xcode',version=1)),indent=2))
subprocess.run(['iconutil','-c','icns',str(iconset),'-o',str(ROOT/'macos/Fronda.icns')],check=True)
for name,bg in [('light','#EEE8DA'),('dark','#211F1B')]:
    proof=Image.new('RGBA',(1254,1254),bg);proof.alpha_composite(master)
    proof.convert('RGB').save(ROOT/f'preview/icon-{name}.png')
sheet=Image.new('RGB',(1200,650),'#211F1B');draw=ImageDraw.Draw(sheet)
font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',20)
for x,size in [(48,16),(140,32),(245,64),(390,128),(610,256)]:
    small=icon.resize((size,size),Image.Resampling.LANCZOS)
    sheet.paste(small,(x,180),small);draw.text((x,470),f'{size} px',font=font,fill='#EEE8DA')
draw.text((48,52),'Fronda — tamanhos reais de exportação',font=font,fill='#EEE8DA')
sheet.save(ROOT/'preview/sizes.png')
report=dict(originalSHA256=hashlib.sha256((ROOT/'source/approved-icon.png').read_bytes()).hexdigest(),sourceSize=list(original.size),matteBBox=box,masterRGBMaxDifference=int(rgb_delta.max()),changedRGBPixels=int((rgb_delta.max(axis=2)>0).sum()),alphaOnly=True,resampling='Lanczos only at output sizes; no sharpen or color correction',contentSize1024=list(cropped.size))
(ROOT/'qa/pixel-fidelity.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
