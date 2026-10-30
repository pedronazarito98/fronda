"""Editable source for the Fronda brand manual. Uses ReportLab, no app changes."""
from pathlib import Path
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.colors import HexColor
from reportlab.lib.utils import ImageReader
from reportlab.platypus import Paragraph
from reportlab.lib.styles import ParagraphStyle
from PIL import Image
import json
R=Path(__file__).resolve().parents[1];OUT=R/'manual/Fronda-Brand-Book.pdf'
pdfmetrics.registerFont(TTFont('Editorial',str(R/'source/DMSerifDisplay-Regular.ttf')))
pdfmetrics.registerFont(TTFont('Inter',str(R/'source/Inter-Variable.ttf')))
W,H=960,600;c=canvas.Canvas(str(OUT),pagesize=(W,H));c.setTitle('Fronda | Manual de identidade');c.setAuthor('Fronda');page=0
IV='#EEE8DA';BG='#F7F3EA';BK='#282620';M='#526048';S='#8D9877';CL='#BD9674';ST='#AEA184';muted='#665F52'
def rect(x,y,w,h,color,r=0):
 c.setFillColor(HexColor(color));c.roundRect(x,H-y-h,w,h,r,stroke=0,fill=1)
def text(t,x,y,size=15,color=BK,font='Inter'):
 c.setFillColor(HexColor(color));c.setFont(font,size);c.drawString(x,H-y-size,t)
def para(t,x,y,w=380,size=15,color=BK):
 p=Paragraph(t,ParagraphStyle('body',fontName='Inter',fontSize=size,leading=size*1.45,textColor=HexColor(color)))
 _,h=p.wrap(w,H);p.drawOn(c,x,H-y-h);return h
def image(rel,x,y,w,h):
 p=R/rel;im=Image.open(p);rw,rh=im.size;scale=min(w/rw,h/rh);dw,dh=rw*scale,rh*scale;c.drawImage(ImageReader(im),x+(w-dw)/2,H-y-dh,width=dw,height=dh,mask='auto')
def line(x1,y1,x2,y2,color=ST):
 c.setStrokeColor(HexColor(color));c.setLineWidth(.7);c.line(x1,H-y1,x2,H-y2)
def start(label,title,dark=False):
 global page;page+=1;rect(0,0,W,H,BK if dark else IV);fg=IV if dark else BK
 text('FRONDA / '+label.upper(),48,28,10,CL if dark else M)
 text(title,48,62,38,fg,'Editorial');line(48,548,912,548,'#5B564C' if dark else ST);text('Identidade digital • 26.09.2026',48,565,10,'#C1B8A7' if dark else muted);text(f'{page:02d}',886,565,10,fg)
def end():c.showPage()
# 1
start('Manual de identidade','As partes encontram seu lugar.')
image('logos/wordmark-primary-light.png',48,181,515,184);image('mascot/exports/master.png',630,146,270,338)
para('Nome, símbolo, personagem e material formam uma só identidade. Este manual reúne os arquivos e as regras para preservar essa relação no produto e na comunicação.',48,417,490,16)
text('KIT DIGITAL / V2',650,495,12,M);end()
# 2
start('01 / Essência','Clareza para o trabalho ganhar forma.')
para('Fronda é um espaço para orientar, acompanhar e revisar trabalho de desenvolvimento. A ramificação representa partes conectadas que pertencem à mesma estrutura.',48,154,400,18)
for y,title,body in [(300,'Atento','Observa o contexto e torna o próximo passo claro.'),(372,'Cuidadoso','Valoriza a revisão, o detalhe e o trabalho bem feito.'),(444,'Próximo','Fala com simplicidade e tem humor discreto.')]:
 text(title,48,y,23,M,'Editorial');para(body,220,y+2,310,14)
image('brand-masters/exports/symbol-sculpted.png',634,168,210,300)
para('A promessa de marca é tornar o trabalho compreensível. Evitar prometer perfeição, autonomia irrestrita ou resultados que o produto não demonstrou.',590,458,310,13);end()
# 3
start('02 / Sistema','Uma forma. Diferentes níveis de detalhe.')
image('logos/wordmark-primary-light.png',48,163,585,195);image('brand-masters/exports/app-icon-master.png',708,165,190,190)
for x,title,body in [(48,'Principal','Volume e textura em apresentações, cabeçalhos e peças sociais. Usar os PNGs ou o SVG híbrido.'),(348,'Reduzida','Contornos vetoriais derivados da mesma silhueta. Para escala pequena, gravação e reprodução simples.'),(648,'Nativa','Camadas no Icon Composer recebem luz e material do sistema. O .icns atende ao fluxo clássico.')]:
 text(title,x,396,23,M,'Editorial');para(body,x,438,260,14)
end()
# 4
start('03 / Assinatura','Proporção, espaço e respiro.')
rect(77,167,806,244,BG,16);image('logos/wordmark-primary-light.png',133,210,692,155)
c.setStrokeColor(HexColor(CL));c.setDash(4,4);c.rect(109,H-387,742,200,stroke=1,fill=0);c.setDash()
text('x',83,276,16,M);text('x = ¼ da altura visível do f',600,431,13,M)
para('Manter a relação entre o f e as letras ronda. O f já é a primeira letra da palavra: não adicionar outro símbolo à esquerda da assinatura.',48,452,420,15)
para('Preservar no mínimo x de espaço livre em todos os lados. Usar o arquivo pronto, sem redigitar o nome ou ajustar letras separadamente.',505,464,385,14);end()
# 5
start('04 / Escala','Detalhe onde ele pode ser visto.')
image('brand-masters/exports/symbol-sculpted.png',63,175,195,270)
for x,sz in [(348,16),(400,24),(470,32),(550,48),(655,64),(770,96)]:
 image('brand-masters/exports/app-icon-master.png',x,235-sz/2,sz,sz);text(str(sz)+' px',x-4,302,11,muted)
para('Assinatura principal: largura recomendada a partir de 240 px. Abaixo disso, usar assinatura reduzida ou símbolo. Em peças editoriais, dar espaço ao material.',322,372,560,16)
para('Ícones de 16 e 24 px usam a versão técnica micro. Nas demais escalas, usar o ícone orgânico. O mascote completo pede pelo menos 128 px; preferir 256 px ou mais em comunicação.',322,459,560,14);end()
# 6
start('05 / Cor','Terra, vegetação e luz quente.')
colors=[('Marfim',IV),('Casca',BK),('Pedra',ST),('Musgo',S),('Argila',CL),('Musgo profundo',M)]
for i,(name,v) in enumerate(colors):
 x=48+(i%3)*300;y=155+(i//3)*154;rect(x,y,264,90,v,12);text(name,x,y+100,16,M);text(v,x+158,y+102,12,muted)
para('Marfim dá espaço. Casca cria profundidade. Musgo identifica a marca. Argila aquece o conjunto. Pedra faz a transição entre materiais. A cor forte deve orientar o olhar, sem tingir todas as superfícies.',48,488,864,14);end()
# 7
start('06 / Tipografia','Personalidade no título. Clareza na leitura.')
text('DM Serif Display',48,162,44,M,'Editorial');text('As partes encontram seu lugar.',48,228,29,BK,'Editorial');para('Assinatura, títulos editoriais e frases curtas. Usar Regular; o contraste e a escala criam hierarquia. Evitar caixa alta em blocos longos.',48,296,420,15)
text('Inter',565,165,40,M);text('Aa Bb Cc 0123456789',565,228,24,BK);para('Texto de apoio e comunicação. Regular para leitura; peso e cor para hierarquia. Nos SVGs sociais, o texto permanece editável e a fonte está incorporada.',565,296,320,15)
line(48,419,912,419);para('Produto macOS: preservar a fonte do sistema na implementação. Código e valores técnicos usam monoespaçada do sistema. A fonte editorial não deve substituir todos os controles do app.',48,449,864,16);end()
# 8
start('07 / Produto','Claro e escuro pertencem à mesma marca.')
image('preview/product-light.png',48,164,421,280);image('preview/product-dark.png',491,164,421,280)
para('Conteúdo com leitura prolongada usa superfícies estáveis. A marca aparece no cabeçalho e em momentos úteis, sem competir com tarefas, evidências ou decisões.',48,454,405,14)
para('Vidro é uma camada de navegação. Usar materiais nativos e respeitar redução de transparência, aumento de contraste e redução de movimento.',491,454,405,14)
text('Aplicações estáticas ilustrativas; não são capturas de uma implementação.',48,524,10,muted);end()
# 9
start('08 / Acessibilidade','Cor com função e contraste medido.')
rows=json.loads((R/'system/contrast.json').read_text())['pairs'];chosen=[x for x in rows if x['foreground'] in ['text','textSecondary','onAction','borderControl','focus']]
for i,row in enumerate(chosen):
 y=156+i*25;rect(48,y,864,23,BG if i%2==0 else IV,4);text(row['theme'],62,y+5,11,M);text(row['foreground']+' / '+row['background'],150,y+5,11);text(str(row['ratio'])+':1',618,y+5,11,M);text('Meta '+str(row['target'])+':1',761,y+5,11,muted)
para('20 pares opacos verificados no arquivo contrast.json. Texto normal: meta 4,5:1. Controles e foco: meta 3:1. Esses cálculos não certificam contraste sobre vidro ou wallpapers variáveis.',48,475,864,14);end()
# 10
start('09 / Personagem','O Fronda é parte da estrutura.')
image('mascot/exports/master.png',55,156,370,365)
for y,title,body in [(162,'Silhueta','Cinco ramos principais, um broto central e dois pés.'),(260,'Expressão','Dois olhos escuros. O gesto vem da postura e dos ramos.'),(358,'Material','Marfim fosco no topo; caramelo na base; textura sutil.'),(456,'Limites','Sem boca, mãos humanas, roupas ou acessórios permanentes.')]:
 text(title,508,y,23,M,'Editorial');para(body,508,y+37,360,14)
end()
# 11
start('10 / Repertório','Um gesto para cada momento.')
poses=[('master','Presença','Apresentação da marca.'),('welcome','Acolhe','Boas-vindas e convite.'),('focus','Observa','Contexto e revisão.'),('rest','Repousa','Espera e pausa.')]
for i,(name,title,body) in enumerate(poses):
 x=48+i*222;image(f'mascot/exports/{name}.png',x,175,198,260);text(title,x,453,23,M,'Editorial');para(body,x,492,192,13)
end()
# 12
start('11 / Direção de arte','O material aproxima. O excesso afasta.',True)
image('brand-masters/exports/app-icon-master.png',57,167,286,286)
for y,title,body in [(158,'Preservar','Luz superior suave, sombras curtas, textura fina e tons quentes.'),(268,'Compor','Um foco principal por peça. Respiro amplo. Mascote e f com a mesma origem.'),(378,'Evitar','Neon, plástico brilhante, ruído exagerado, floresta decorativa e símbolos de IA.')]:
 text(title,422,y,24,IV,'Editorial');para(body,422,y+40,456,16,'#C1B8A7')
text('Em fundo escuro, conferir sempre a separação da haste e os contornos.',48,507,13,CL);end()
# 13
start('12 / Social','Peças prontas e estrutura editável.')
image('social/01-manifesto-1080.png',48,157,256,256);image('social/02-detalhe-1080x1350.png',347,157,205,256);image('social/03-story-1080x1920.png',631,157,144,256)
for x,title,body in [(48,'Quadrado','1080 × 1080 / manifesto'),(347,'Retrato','1080 × 1350 / editorial'),(631,'Vertical','1080 × 1920 / story')]:
 text(title,x,443,22,M,'Editorial');text(body,x,479,12,muted)
para('PNG para uso imediato; SVG com texto e composição editáveis. Manter 72 px de margem no feed e 250 px livres no topo e rodapé do story. Conferir a interface da rede antes de publicar.',48,511,864,12);end()
# 14
start('13 / Movimento','Pequenos gestos, motivos claros.')
for i,(name,label) in enumerate([('rest','01 / Pausa'),('focus','02 / Atenção'),('welcome','03 / Abertura')]):
 x=60+i*300;image(f'mascot/exports/{name}.png',x,163,232,244);text(label,x,426,16,M)
para('Na interface, uma entrada curta de 420 ms pode apresentar o personagem. O arquivo motion.css contém esse gesto e respeita prefers-reduced-motion. Evitar animação contínua junto de leitura.',48,469,420,14)
para('Para vídeos: antecipação leve, ação única e pausa final. As poses são recortes estáticos prontos para composição; não constituem rig 3D ou animação articulada.',502,469,410,14);end()
# 15
start('14 / Voz','Próximo, preciso e sem exagero.')
examples=[('Revisão','Seu plano está pronto para revisão.'),('Bloqueio','A execução parou neste passo. Veja o motivo.'),('Evidência','As evidências estão reunidas.'),('Decisão','Você decide o próximo passo.')]
for i,(label,phrase) in enumerate(examples):
 y=156+i*82;text(label.upper(),48,y+4,11,M);text(phrase,195,y,24,BK,'Editorial');line(195,y+51,912,y+51)
para('Descrever o estado real e a próxima ação. Não infantilizar erros, parabenizar por qualquer clique ou inventar progresso. O personagem acompanha o texto; não substitui a informação.',48,496,864,14);end()
# 16
start('15 / Entrega','Um pacote para usar e continuar.')
items=[('logos/','Principal em PNG e SVG híbrido; versões reduzidas em vetores puros.'),('icons/','Ícone clássico .icns, catálogo Xcode, favicon e projeto .icon em camadas.'),('mascot/exports/','Quatro poses com transparência, prontas para composição.'),('social/','Quatro formatos de peças, SVGs editáveis e dois avatares.'),('system/','Tokens, contraste e exemplo de movimento com redução de animação.'),('source/ e licenses/','Fontes, scripts, origem das imagens e licenças para continuidade.')]
for i,(label,body) in enumerate(items):
 y=152+i*53;text(label,48,y,14,M);para(body,284,y,600,13)
para('Antes de integrar: validar o ícone no Dock e os temas sobre materiais reais. O kit é digital, em sRGB; impressão demanda prova e conversão de perfil. O mascote é raster, sem modelo 3D. O código do app não foi alterado.',48,485,864,13);end()
# 17 references
start('16 / Referências','Critérios que orientam a entrega.')
refs=[('Apple / App icons','https://developer.apple.com/design/human-interface-guidelines/app-icons','Camadas, consistência de forma e adaptação às aparências do sistema.'),('Apple / Icon Composer','https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer','Arquivo nativo com imagens SVG/PNG em camadas e efeitos aplicados pelo sistema.'),('Apple / Materials','https://developer.apple.com/design/human-interface-guidelines/materials','Separar controles e conteúdo; priorizar legibilidade e materiais nativos.'),('W3C / WCAG 2.2, contraste','https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html','Contraste de texto e limites da medição em superfícies opacas.'),('Fontes / SIL Open Font License','https://github.com/google/fonts','DM Serif Display e Inter. Arquivos originais e licenças incluídos no kit.')]
for i,(title,url,desc) in enumerate(refs):
 y=145+i*73;text(title,48,y,17,M,'Editorial');para(desc,48,y+27,864,12);c.linkURL(url,(48,H-y-20,650,H-y),relative=0)
text('Consulta: 26.09.2026. Regras visuais próprias são decisões do projeto, não prescrições da Apple.',48,523,10,muted);end()
c.save();print('Brand book exported:',page,'pages')
