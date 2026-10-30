"""Deterministic brand exports from the approved sculpted PNG; no app dependencies."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import numpy as np
import json, base64, xml.etree.ElementTree as ET
R=Path(__file__).resolve().parents[1]
FONT=R/'source/DMSerifDisplay-Regular.ttf'
COLORS={'ivory':'#EEE8DA','bark':'#282620','moss':'#526048','sage':'#8D9877','clay':'#BD9674','stone':'#AEA184'}

def tight(path):
    im=Image.open(path).convert('RGBA');mask=im.getchannel('A').point(lambda a:255 if a>=64 else 0)
    return im.crop(mask.getbbox())

def embed(path):return 'data:image/png;base64,'+base64.b64encode(Path(path).read_bytes()).decode()
def savepng(im,path):im.save(path,optimize=True)
def fit(im,w,h):
    im=im.copy();im.thumbnail((w,h),Image.Resampling.LANCZOS);return im

def boundary(mask):
    m=np.pad(mask,1);ys,xs=np.where(mask);edges={}
    def add(a,b):edges.setdefault(a,[]).append(b)
    for y,x in zip(ys.tolist(),xs.tolist()):
        if not m[y,x+1]:add((x,y),(x+1,y))
        if not m[y+1,x+2]:add((x+1,y),(x+1,y+1))
        if not m[y+2,x+1]:add((x+1,y+1),(x,y+1))
        if not m[y+1,x]:add((x,y+1),(x,y))
    dirs={(1,0):0,(0,1):1,(-1,0):2,(0,-1):3};loops=[]
    while edges:
        start=next(iter(edges));p=start;loop=[];direction=None
        while p in edges:
            loop.append(p);choices=edges[p]
            if direction is None:q=choices[0]
            else:
                # Keep foreground on the right at diagonal boundary junctions.
                priority={1:0,0:1,3:2,2:3}
                q=min(choices,key=lambda q:priority[(dirs[(q[0]-p[0],q[1]-p[1])]-direction)%4])
            direction=dirs[(q[0]-p[0],q[1]-p[1])];choices.remove(q)
            if not choices:del edges[p]
            p=q
            if p==start:
                if len(loop)>30:loops.append(loop)
                break
    return max(loops,key=lambda p:abs(sum(p[i][0]*p[(i+1)%len(p)][1]-p[(i+1)%len(p)][0]*p[i][1] for i in range(len(p)))))

def simplify(points,eps=3):
    p=np.asarray(points,dtype=float);a,b=p[0],p[-1];v=b-a
    ds=np.linalg.norm(p-a,axis=1) if np.linalg.norm(v)==0 else np.abs(v[0]*(a[1]-p[:,1])-(a[0]-p[:,0])*v[1])/np.linalg.norm(v)
    i=int(ds.argmax())
    if ds[i]>eps:return simplify(points[:i+1],eps)[:-1]+simplify(points[i:],eps)
    return [points[0],points[-1]]

def smooth_path(points):
    pts=simplify(points+[points[0]],3.2)[:-1]
    mid=lambda a,b:((a[0]+b[0])/2,(a[1]+b[1])/2)
    start=mid(pts[-1],pts[0]); d=f'M{start[0]:.1f},{start[1]:.1f}'
    for i,p in enumerate(pts):
        q=mid(p,pts[(i+1)%len(pts)]);d+=f' Q{p[0]:.1f},{p[1]:.1f} {q[0]:.1f},{q[1]:.1f}'
    return d+' Z'

symbol=tight(R/'brand-masters/exports/symbol-sculpted.png');savepng(symbol,R/'logos/symbol-primary.png')
W,H=symbol.size;a=np.array(symbol);mask=a[:,:,3]>128
Y=np.indices(mask.shape)[0];red=a[:,:,0].astype(float);green=a[:,:,1].astype(float);blue=a[:,:,2].astype(float)
ivory=mask&(red>135)&(green>115)&(red/np.maximum(green,1)<1.28)&(Y<H*.49)
clay=mask&(red>100)&(red/np.maximum(green,1)>1.19)&(Y>H*.34)&(Y<H*.75)
paths=[smooth_path(boundary(m)) for m in [mask,ivory,clay]]
(R/'source/symbol-paths.json').write_text(json.dumps({'width':W,'height':H,'paths':paths},indent=2))
# Letter contours preserve exact typography without external font dependencies.
letterpaths=json.loads((R/'source/letter-outlines.json').read_text())
wordscale=1.9; wordheight=760; symheight=680;sym=fit(symbol,10000,symheight);sx=24;sy=30
lettersx=sx+sym.width+30;letterwidth=(1177-244)*wordscale
wordwidth=round(lettersx+letterwidth+20)
for theme in ['light','dark']:
    fg=COLORS['moss'] if theme=='light' else COLORS['ivory']
    out=Image.new('RGBA',(wordwidth,wordheight));out.alpha_composite(sym,(sx,sy))
    draw=ImageDraw.Draw(out);font=ImageFont.truetype(str(FONT),round(350*wordscale))
    # Baseline anchored; f ends on same optical baseline as the serif letters.
    baseline=sy+sym.height-10
    draw.text((lettersx,baseline),'ronda',font=font,fill=fg,anchor='ls',stroke_width=0)
    savepng(out,R/f'logos/wordmark-primary-{theme}.png')
    outlines=''.join(f'<path fill="{fg}" d="{d}"/>' for d in letterpaths)
    # SVG is deliberately hybrid: embedded sculpted f + true vector letter outlines.
    svg=f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {wordwidth} {wordheight}"><title>Fronda - assinatura principal {theme}</title><image href="{embed(R/"logos/symbol-primary.png")}" x="{sx}" y="{sy}" width="{sym.width}" height="{sym.height}"/><g transform="translate({lettersx-244*wordscale} {baseline-368*wordscale}) scale({wordscale})">{outlines}</g></svg>'
    (R/f'logos/wordmark-primary-{theme}.svg').write_text(svg)
    fills=[COLORS['moss'],COLORS['stone'],COLORS['clay']] if theme=='light' else [COLORS['clay'],COLORS['ivory'],COLORS['ivory']]
    flat=''.join(f'<path fill="{c}" d="{d}"/>' for c,d in zip(fills,paths))
    (R/f'logos/symbol-reduced-{theme}.svg').write_text(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}"><title>Fronda - símbolo reduzido</title>{flat}</svg>')
    body=f'<g transform="translate({sx} {sy}) scale({symheight/H})">{flat}</g>'
    (R/f'logos/wordmark-reduced-{theme}.svg').write_text(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {wordwidth} {wordheight}"><title>Fronda - assinatura reduzida {theme}</title>{body}<g transform="translate({lettersx-244*wordscale} {baseline-368*wordscale}) scale({wordscale})">{outlines}</g></svg>')
    mono=COLORS['moss'] if theme=='light' else COLORS['ivory']
    (R/f'logos/symbol-single-color-{theme}.svg').write_text(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}"><title>Fronda - uso técnico em uma cor</title><path fill="{mono}" d="{paths[0]}"/></svg>')
# Export a native liquid-glass layer set; system supplies highlights and mask.
layerdir=R/'icons/liquid-glass-layers';layerdir.mkdir(exist_ok=True)
(layerdir/'background.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024"><rect width="1024" height="1024" fill="#526048"/></svg>')
for name,d,c in zip(['01-stem','02-crown','03-branch'],paths,['#BD9674','#EEE8DA','#BD9674']):
    scale=720/H;x=(1024-W*scale)/2;y=152
    (layerdir/f'{name}.svg').write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024"><g transform="translate({x:.2f} {y}) scale({scale:.6f})"><path d="{d}" fill="{c}"/></g></svg>')
(R/'source/wordmark-layout.json').write_text(json.dumps({'width':wordwidth,'height':wordheight,'symbol':[sx,sy,sym.width,sym.height],'lettersX':lettersx,'baseline':baseline,'wordscale':wordscale,'letterpaths':letterpaths},indent=2))
print('Exported primary hybrid logos, reduced pure-vector logos and four native icon layers.')
