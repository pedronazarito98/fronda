from pathlib import Path
import json
R=Path(__file__).resolve().parents[1]
brand={'ivory':'#EEE8DA','bark':'#282620','stone':'#AEA184','moss':'#8D9877','clay':'#BD9674','deepMoss':'#526048'}
light={'background':'#EEE8DA','surface':'#F7F3EA','text':'#282620','textSecondary':'#665F52','action':'#526048','onAction':'#F7F3EA','borderDecorative':'#CCC4B4','borderControl':'#827865','focus':'#526048','success':'#386443','warning':'#855318','danger':'#A43C35','info':'#3B626A'}
dark={'background':'#211F1B','surface':'#2E2B25','text':'#F1EBDC','textSecondary':'#C1B8A7','action':'#A7B18D','onAction':'#211F1B','borderDecorative':'#5B564C','borderControl':'#A79A84','focus':'#D1B295','success':'#AAD0A3','warning':'#E5BD7D','danger':'#EBA59B','info':'#A5C7D0'}
spacing={'xs':4,'sm':8,'md':12,'lg':16,'xl':24,'2xl':32,'3xl':48,'4xl':64,'5xl':96}
tokens={'brand':brand,'light':light,'dark':dark,'spacing':spacing,'radius':{'control':10,'card':20,'panel':28},'motion':{'feedbackMs':180,'transitionMs':280,'characterMs':420,'easing':'cubic-bezier(.22,1,.36,1)','reducedMotion':'static'},'typography':{'brand':'DM Serif Display Regular','editorial':'DM Serif Display Regular','communication':'Inter','nativeUI':'system','code':'system monospace'},'status':'brand handoff, not integrated into app'}
(R/'system/tokens.json').write_text(json.dumps(tokens,indent=2,ensure_ascii=False))
css='/* Fronda brand tokens. Opt in per container; no global app changes. */\n'
for selector,colors in [('.fronda-theme-light',light),('.fronda-theme-dark',dark)]:
 css+=selector+' {\n'+''.join(f'  --fronda-{k}: {v};\n' for k,v in colors.items())+'}\n'
css+=':root {\n'+''.join(f'  --fronda-space-{k}: {v}px;\n' for k,v in spacing.items())+'}\n'
(R/'system/tokens.css').write_text(css)
(R/'system/motion.css').write_text('''/* Event-triggered entrance. Add class only when relevant, never an endless loop. */
.fronda-enter {animation:fronda-enter 420ms cubic-bezier(.22,1,.36,1) both;transform-origin:50% 90%;}
@keyframes fronda-enter {from{opacity:0;transform:translateY(8px) rotate(-2deg)}to{opacity:1;transform:none}}
@media(prefers-reduced-motion:reduce){.fronda-enter{animation:none;transform:none;opacity:1}}
''')
def lum(h):
 v=[int(h[i:i+2],16)/255 for i in (1,3,5)];v=[x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4 for x in v];return sum(a*b for a,b in zip(v,[.2126,.7152,.0722]))
def contrast(a,b):
 x,y=sorted([lum(a),lum(b)]);return (y+.05)/(x+.05)
rows=[]
for theme,t in [('light',light),('dark',dark)]:
 for fg,bg,target in [('text','surface',4.5),('textSecondary','surface',4.5),('onAction','action',4.5),('text','background',4.5),('borderControl','surface',3),('focus','surface',3)]+[(key,'surface',4.5) for key in ['success','warning','danger','info']]:
  v=contrast(t[fg],t[bg]);rows.append({'theme':theme,'foreground':fg,'background':bg,'hex':[t[fg],t[bg]],'ratio':round(v,2),'target':target,'pass':v>=target})
assert all(x['pass'] for x in rows),[x for x in rows if not x['pass']]
(R/'system/contrast.json').write_text(json.dumps({'method':'WCAG relative luminance, opaque sRGB colors only','source':'https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html','pairs':rows},indent=2))
print('Semantic tokens and',len(rows),'contrast pairs passed.')
