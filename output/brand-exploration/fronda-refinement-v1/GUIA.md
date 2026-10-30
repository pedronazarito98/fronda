# Fronda — refinamento da identidade, rodada 1

## Decisão registrada
O usuário escolheu Fronda e confirmou que gostou do conjunto de nome, mascote e cores. Esta rodada preserva esse conjunto. As novas regras e pranchas são propostas de refinamento; ainda não são a arte-final aprovada. A escolha visual não implica implantação no aplicativo.

## Ideia central
**As partes encontram seu lugar.**

Fronda transforma um trabalho espalhado em um percurso que pode ser entendido e acompanhado. A ramificação é o vínculo entre nome, símbolo e personagem: vários elementos pertencem à mesma estrutura. Para o app, isso conversa com contexto, execução e evidências sem precisar de robôs, cérebros ou referências visuais a IA.

O nome Fronda é uma metáfora de ramagem, não o nome científico do fungo. A inspiração morfológica continua sendo *Hericium coralloides*. Não atribuímos a essa espécie uma tradição simbólica inventada.

**Descrição direta do produto:** um espaço para orientar, acompanhar e revisar trabalho de desenvolvimento.
**Personalidade:** atenta, metódica, acolhedora, com humor discreto.
**Promessa de marca:** tornar o trabalho compreensível. A marca não promete resultados perfeitos ou automáticos.

## 01 — Assinatura
Preservar o nome em caixa baixa e a personalidade serifada escolhida. O símbolo é uma letra f orgânica de três terminais, relacionada aos ramos do personagem, com uma só massa e vãos abertos.

Refinar na arte-final:
- Compensação óptica entre símbolo e letras; evitar que o símbolo pareça maior por peso.
- Mesma geometria nas versões clara, escura, horizontal e vertical.
- Serifas resistentes em escalas pequenas; ajuste específico de espaçamento em “fr”, “on” e “da”.
- Área de proteção proposta: no mínimo a largura do terminal arredondado principal ao redor da assinatura.
- Sem slogan no Dock, menu bar, títulos de janela ou ícones pequenos.

A prancha mostra tamanhos de referência, mas não comprova legibilidade real de um ícone de 16 px. O desenho final deve ser vetorizado e validado no tamanho real. Não há fonte comercial escolhida ou licenciada nesta rodada; o lettering das imagens é um estudo.

## 02 — Mascote
O próprio personagem pode ser chamado de **Fronda**. Não precisamos introduzir outro nome nesta etapa.

### Elementos que preservamos
- Cinco ramos principais em marfim, com terminações pendentes em forma de pequenos pentes.
- Pequeno broto/curva central já presente na imagem escolhida.
- Corpo central e base única em tom de argila/caramelo, terminando em dois pés.
- Dois olhos pequenos e escuros; a expressão vem dos olhos, inclinação e postura.
- Material fosco e tátil. Textura discreta, sem transformar o personagem em pelúcia.
- Assimetria controlada, espaços vazios entre os ramos e uma silhueta legível.

### Limites de desenho
Não adicionar boca, mãos humanas, roupas, chapéu, sobrancelhas, objetos permanentes ou novos membros. Os ramos inferiores podem tocar e organizar objetos. Nas gerações, detalhes como quantidade de dentes e curvatura ainda variam; a prancha é referência de intenção, não um modelo de produção fechado.

### Três níveis de detalhe
| Uso | Representação proposta |
|---|---|
| Menu bar e ícones 16–24 px | Símbolo da marca, uma cor |
| Avatar 32–64 px | Personagem em duas cores, sem textura e sem dentes individuais |
| Interface 128 px+, posts e vídeos | Personagem completo, textura e dentes legíveis |

A versão pequena da prancha ainda tem detalhes a reduzir. A arte-final deverá separar esses três desenhos, em vez de apenas reduzir a mesma imagem.

### Repertório de atuação
| Estado | Gesto | Uso |
|---|---|---|
| Observa | Inclinação pequena, olhos dirigidos ao objeto | Entender contexto e inspecionar |
| Organiza | Ramos inferiores aproximam ou alinham peças | Preparar, relacionar e explicar |
| Aguarda | Corpo assentado, olhos relaxados, quase imóvel | Decisão humana pendente |
| Conclui | Corpo levemente ereto, abertura sutil dos ramos | Entrega concluída com evidência |

O mascote não substitui texto de status. Uma tarefa bloqueada precisa explicar o motivo e a próxima ação; não basta mostrar um rosto triste.

## 03 — Cor e material
As cinco cores escolhidas continuam como base:
- Marfim **#EEE8DA**: fundo quente e espaço visual.
- Casca **#282620**: assinatura, texto e profundidade.
- Pedra **#AEA184**: apoio, superfícies secundárias e objetos.
- Musgo **#8D9877**: identificação e destaques discretos.
- Argila **#BD9674**: calor e materialidade, com uso contido.

A pedra e o musgo originais são tons médios. Para botões e links, proponho derivações funcionais: **#526048** no tema claro e **#A7B18D** no escuro. São extensões para legibilidade, não uma substituição da paleta escolhida.

### Papéis por tema
| Papel | Claro | Escuro |
|---|---|---|
| Fundo | #EEE8DA | #211F1B |
| Superfície de leitura | #F7F3EA | #2E2B25 |
| Texto principal | #282620 | #F1EBDC |
| Texto secundário | #665F52 | #C1B8A7 |
| Ação | #526048 | #A7B18D |
| Texto sobre ação | #F7F3EA | #211F1B |
| Divisória decorativa | #CCC4B4 | #5B564C |

Divisória decorativa não é contorno suficiente para um controle interativo. Estados de erro, alerta, sucesso, foco e seleção devem preservar a semântica e os recursos do sistema ao serem implementados; a cor da marca não deve confundir o resultado de validações.

### Contraste calculado
| Tema | Par sólido | Razão |
|---|---|---|
| light | Texto / superfície | 13.66:1 |
| light | Texto secundário / superfície | 5.71:1 |
| light | Texto / botão | 6.07:1 |
| light | Texto / fundo | 12.38:1 |
| dark | Texto / superfície | 11.86:1 |
| dark | Texto secundário / superfície | 7.18:1 |
| dark | Texto / botão | 7.3:1 |
| dark | Texto / fundo | 13.83:1 |

Calculei luminância relativa a partir dos HEX. Todos os oito pares acima superam 4,5:1. Isso vale apenas para cores sólidas especificadas, não para os pixels das imagens, para cada estado do app ou para vidro sobre um wallpaper.

### Liquid glass
Usar vidro na navegação, toolbar e Session Island. Manter diff, evidências, texto e listas de leitura em superfícies estáveis. A cor aparece atrás e nas bordas; evitar tonalizar todas as camadas de verde ou fazer o texto depender do fundo.

Na implementação futura, preservar Reduce Transparency, Reduce Motion e o fallback já existente para versões anteriores do macOS. A inspeção do código confirmou uso de glassEffect na Session Island; esta rodada não o modificou.

### Tipografia
- Assinatura e peças editoriais: direção serifada escolhida.
- Conteúdo e controles do app: tipografia nativa sem serifa, com a hierarquia existente.
- Código e valores técnicos: monoespaçada do sistema.
- Não espalhar a fonte da marca por toda a interface.

## 04 — Comportamento e voz
Fronda fala de forma curta, precisa e acolhedora. Descreve o que aconteceu e o que a pessoa pode fazer. Não parabeniza por qualquer clique nem infantiliza falhas.

Exemplos de voz, sujeitos à verdade do estado:
- “Seu plano está pronto para revisão.”
- “Encontrei três pontos para conferir.”
- “A execução parou neste passo. Veja o motivo.”
- “As evidências estão reunidas.”
- “Você decide o próximo passo.”

O mascote pode aparecer junto dessas mensagens; não precisa ser o narrador permanente. Em vídeos, voz em off ou legendas permitem mantê-lo sem boca.

## 05 — Conteúdo e movimento
Três séries possíveis:
1. **As partes encontram seu lugar:** explicar um processo com objetos e composição.
2. **O detalhe faz diferença:** mostrar pequenas decisões de projeto e revisão.
3. **Por dentro do trabalho:** apresentar bastidores e progresso real.

Storyboard-base proposto, 8 segundos:
- 0–2 s: Fronda observa três peças desalinhadas.
- 2–5 s: os ramos inferiores alinham as peças, com antecipação curta.
- 5–7 s: confere o conjunto e relaxa.
- 7–8 s: assinatura da marca, imóvel e legível.

As pranchas contêm quadros estáticos; nenhum vídeo ou rig foi produzido. Para a interface, gestos propostos de 180–320 ms em eventos relevantes, sem balanço contínuo ao lado de conteúdo. Com movimento reduzido, usar mudança de estado estática ou transição de opacidade discreta.

## 06 — Aplicação no produto
A aplicação conceitual usa a navegação lida no projeto: Caixa de entrada, Tarefas, Decisões, Projetos, Fluxos e Ajustes. É um recorte para visualizar a marca; itens omitidos, como Diário, não estão sendo removidos.

Plano, Execução e Revisão mantêm o foco no trabalho. O personagem ocupa uma pequena área de sessão e aparece quando contribui para comunicar um estado. Renders de “Validação concluída” são conteúdo fictício de apresentação, não resultados de execução do app.

## 07 — Nome e originalidade
A escolha do nome foi preservada. Uma consulta preliminar encontrou uma [empresa de jardinagem chamada Fronda](https://www.fronda.com/nuestra-marca), com presença em fronda.com. Isso demonstra uso existente; não determina disponibilidade para software no Brasil ou em outros territórios.

Não realizei pesquisa de registro de marca, domínio alternativo ou identificadores de redes. Não apresento exclusividade jurídica ou disponibilidade comercial como confirmadas.

## Entrega e decisões pendentes
- Três pranchas finais da rodada: assinatura, personagem e produto/conteúdo.
- Quatro prompts usados, com revisão da aplicação para corrigir membros extras e estado da revisão.
- Paleta e papéis exatos em paleta.json; cálculos em contraste.json.
- Galeria local, manifesto de origem e este guia.
- Nenhum código Swift, nome instalado, bundle identifier, dependência ou configuração do app alterado.

Para a próxima avaliação, observar: peso e forma do símbolo, textura e silhueta do personagem, conforto dos dois temas e tom das aplicações. O conjunto Fronda já está escolhido; falta consolidar esses detalhes e produzir os arquivos mestres antes de implementar.

**Ainda não produzido:** SVG final, lettering em curvas, app icon em todas as escalas, personagem com rig, vídeo, campanha publicada ou aplicação funcional no app.
**Não executado:** testes, lint ou build do app.

