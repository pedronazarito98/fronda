"""Exact-size editable SVG + PNG layouts using final isolated brand assets."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import base64,json,html
R=Path(__file__).resolve().parents[1]
F={'serif':R/'source/DMSerifDisplay-Regular.ttf','sans':R/'source/Inter-Variable.ttf'}
def b64(p):return 'data:image/png;base64,'+base64.b64encode(Path(p).read_bytes()).decode()
def tight(path):
 im=Image.open(path).convert('RGBA');return im.crop(im.getchannel('A').point(lambda a:255 if a>64 else 0).getbbox())
class Scene:
 def __init__(self,w,h,bg):
  self.w,self.h=w,h;self.im=Image.new('RGBA',(w,h),bg);self.d=ImageDraw.Draw(self.im);self.svg=[f'<rect width="{w}" height="{h}" fill="{bg}"/>']
 def rect(self,x,y,w,h,fill,r=0,stroke=None):
  self.d.rounded_rectangle((x,y,x+w,y+h),radius=r,fill=fill,outline=stroke,width=2)
  self.svg.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}"'+(f' stroke="{stroke}" stroke-width="2"' if stroke else '')+'/>')
 def text(self,text,x,y,size=32,fill='#282620',font='sans'):
  f=ImageFont.truetype(str(F[font]),size);self.d.text((x,y),text,font=f,fill=fill,anchor='lt')
  # SVG baseline is estimated from actual font ascent so export remains editable.
  bbox=f.getbbox(text);baseline=y-bbox[1]+f.getmetrics()[0]
  self.svg.append(f'<text x="{x}" y="{baseline}" font-family="Fronda{font}" font-size="{size}" fill="{fill}">{html.escape(text)}</text>')
 def image(self,path,x,y,w,h,trim=False):
  im=tight(path) if trim else Image.open(path).convert('RGBA');im.thumbnail((w,h),Image.Resampling.LANCZOS);self.im.alpha_composite(im,(round(x),round(y)))
  # Cropped sources are stored once for deterministic reusable positioning.
  if trim:
   p=R/'source'/('crop-'+Path(path).stem+'.png');tight(path).save(p);path=p
  self.svg.append(f'<image x="{x}" y="{y}" width="{im.width}" height="{im.height}" href="{b64(path)}"/>')
  return im.width,im.height
 def export(self,name):
  path=R/name;self.im.convert('RGB').save(path.with_suffix('.png'),optimize=True)
  fonts=''.join('@font-face{font-family:Fronda'+k+';src:url(data:font/ttf;base64,'+base64.b64encode(p.read_bytes()).decode()+') format("truetype");}' for k,p in F.items())
  path.with_suffix('.svg').write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.w}" height="{self.h}" viewBox="0 0 {self.w} {self.h}"><title>Fronda - {path.stem}</title><style>{fonts}</style>'+''.join(self.svg)+'</svg>')

# Social launch square.
s=Scene(1080,1080,'#EEE8DA');s.image(R/'logos/wordmark-primary-light.png',72,60,310,108);s.text('As partes encontram',72,214,76,font='serif');s.text('seu lugar.',72,302,88,font='serif');s.rect(72,453,936,1,'#AEA184');s.image(R/'mascot/exports/master.png',420,492,555,520,trim=True);s.text('Um espaço para orientar,',72,749,27);s.text('acompanhar e revisar',72,789,27);s.text('o trabalho.',72,829,27);s.text('FRONDA',72,980,18,fill='#665F52');s.export('social/01-manifesto-1080')
# Portrait editorial.
s=Scene(1080,1350,'#282620');s.image(R/'logos/wordmark-primary-dark.png',72,60,300,108);s.text('O detalhe',72,225,96,fill='#EEE8DA',font='serif');s.text('faz diferença.',72,337,96,fill='#EEE8DA',font='serif');s.rect(72,490,168,5,'#BD9674');s.image(R/'mascot/exports/focus.png',192,545,710,595,trim=True);s.text('Observar. Organizar. Conferir.',72,1201,33,fill='#EEE8DA');s.text('Uma etapa de cada vez.',72,1252,26,fill='#C1B8A7');s.export('social/02-detalhe-1080x1350')
# Story safe area top and bottom 250px.
s=Scene(1080,1920,'#EEE8DA');s.image(R/'logos/wordmark-primary-light.png',80,256,365,130);s.text('Dê espaço',80,471,104,font='serif');s.text('ao próximo',80,587,104,font='serif');s.text('passo.',80,703,104,font='serif');s.image(R/'mascot/exports/welcome.png',205,950,710,570,trim=True);s.text('As partes encontram seu lugar.',80,1612,32,fill='#526048');s.export('social/03-story-1080x1920')
# Sharing image / cover.
s=Scene(1200,630,'#EEE8DA');s.image(R/'logos/wordmark-primary-light.png',64,53,410,140);s.text('As partes encontram',64,285,57,font='serif');s.text('seu lugar.',64,355,64,font='serif');s.image(R/'mascot/exports/master.png',745,112,392,422,trim=True);s.text('Orientar. Acompanhar. Revisar.',64,533,23,fill='#665F52');s.export('social/04-share-1200x630')
# Avatar PNGs (no tile inside a tile).
for variant,path,bg in [('mascot',R/'mascot/exports/master.png','#526048'),('symbol',R/'brand-masters/exports/symbol-sculpted.png','#EEE8DA')]:
 s=Scene(512,512,bg);im=tight(path);im.thumbnail((380,380),Image.Resampling.LANCZOS);s.im.alpha_composite(im,((512-im.width)//2,(512-im.height)//2));s.im.convert('RGB').save(R/f'social/avatar-{variant}-512.png')
# Product theme applications. These are static design specimens, not screenshots.
tokens=json.loads((R/'system/tokens.json').read_text())
for theme in ['light','dark']:
 t=tokens[theme];s=Scene(1680,1050,t['background']);s.rect(28,28,1624,994,t['surface'],28,t['borderDecorative']);s.rect(28,28,266,994,t['background'],28);s.image(R/f'logos/wordmark-primary-{theme}.png',58,68,205,80)
 for i,label in enumerate(['Caixa de entrada','Tarefas','Decisões','Diário','Projetos','Fluxos','Ajustes']):
  y=205+i*68
  if label=='Tarefas':s.rect(48,y-12,226,54,t['action'],12)
  s.text(label,67,y,20,t['onAction'] if label=='Tarefas' else t['textSecondary'])
 s.text('Projeto Fronda',342,77,19,t['textSecondary']);s.text('Seu trabalho, em perspectiva.',342,138,49,t['text'],font='serif');s.text('Prepare o plano e acompanhe cada etapa.',342,209,22,t['textSecondary']);s.rect(342,282,1254,88,t['background'],18)
 for i,label in enumerate(['01  Plano','02  Execução','03  Revisão']):s.text(label,373+i*402,313,23,t['text'] if i==0 else t['textSecondary'])
 s.text('Plano de trabalho',342,431,30,t['text'],font='serif')
 for i,label in enumerate(['Reunir o contexto do projeto','Definir os critérios de conclusão','Revisar o plano antes de iniciar']):
  y=503+i*66;s.rect(344,y,22,22,t['surface'],5,t['borderControl']);s.text(label,391,y-2,22,t['text'])
 s.rect(342,738,1254,211,t['background'],20);s.image(R/'mascot/exports/rest.png',375,765,156,156,trim=True);s.text('Você decide o próximo passo.',570,781,29,t['text'],font='serif');s.text('O plano fica aqui, pronto para a sua revisão.',570,831,20,t['textSecondary']);s.rect(1305,802,244,58,t['action'],13);s.text('Revisar plano',1337,820,21,t['onAction']);s.text('APLICAÇÃO VISUAL • CONTEÚDO ILUSTRATIVO',342,981,12,t['textSecondary']);s.export(f'preview/product-{theme}')
print('4 editable social templates, 2 avatars and 2 product theme specimens exported.')
