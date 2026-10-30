# Fronda — guia editorial e visual

## Ideia de marca

As partes encontram seu lugar. Fronda é um espaço para orientar, acompanhar e revisar trabalho de desenvolvimento. A ramificação conecta nome, letra inicial e personagem. A promessa é tornar o trabalho compreensível, sem prometer perfeição ou decisões autônomas irrestritas.

Personalidade: atenta, cuidadosa, próxima. O humor é discreto e vem da postura do personagem, sem infantilizar erros ou bloquear o trabalho.

## Identidade

O f é uma haste contínua com dois ramos curvos para a direita e terminações pendentes. Ele abre a palavra e funciona como símbolo independente. A versão principal preserva volume, textura fina e luz quente. A versão reduzida conserva o contorno para escalas e meios que não suportam esse detalhe.

Usar a assinatura pronta; não redigitar fronda com a fonte. Manter espaço livre de ¼ da altura visível do f. Não distorcer, girar a assinatura, trocar suas cores por matizes aleatórios, adicionar efeitos de brilho ou combinar outro f antes do nome.

Recomendações de escala: assinatura principal ≥240 px de largura; símbolo micro em 16–24 px; ícone orgânico a partir de 32 px; mascote ≥128 px, preferencialmente ≥256 px nas redes. Estas são recomendações desta entrega; conferir no destino.

## Paleta e contraste

Marfim #EEE8DA; Casca #282620; Pedra #AEA184; Musgo #8D9877; Argila #BD9674; Musgo profundo #526048. Os papéis claro/escuro e as cores semânticas estão em system/tokens.json.

Vinte pares opacos foram calculados: texto normal com meta 4,5:1; contorno de controle e foco com meta 3:1. A medição não se estende automaticamente ao vidro ou ao conteúdo atrás dele. Divisórias decorativas não substituem bordas de controles.

## Tipografia

DM Serif Display Regular em títulos editoriais e na base do lettering. Inter em apoio, corpo e comunicação. Na implementação nativa, preservar as fontes do sistema para leitura e controles e monoespaçada para código. Não transformar toda a interface em uma peça editorial.

## Mascote

Cinco ramos principais marfim, broto central, base caramelo com dois pés e dois olhos escuros. Expressão por inclinação, abertura dos ramos e olhar. Não adicionar boca, mãos humanas, braços, roupas ou acessórios permanentes.

Presença para apresentação; acolhida para convite; atenção para observação/revisão; repouso para espera. O mascote acompanha informação útil e não substitui mensagens de estado. Poses são recortes estáticos; pequenas variações de dentes e curvatura exigem modelagem/rig próprios caso se avance para animação articulada.

## Arte e composição

Luz superior suave, relevo discreto e sombras curtas. Respiro amplo e um foco principal por peça. O material pertence ao símbolo e ao personagem; não texturizar toda a interface. Evitar neon, plástico espelhado, ruído forte, cenários botânicos genéricos e símbolos de IA.

Social: 72 px de margem mínima no feed; 250 px livres no topo e no rodapé do story. São margens editoriais do kit, não garantias de uma plataforma. Conferir cortes e sobreposições de UI antes da postagem. Não inventar funcionalidades, datas de lançamento ou resultados do produto nas peças.

## Voz

Frases curtas, precisas e acolhedoras. Exemplos: “Seu plano está pronto para revisão.”; “A execução parou neste passo. Veja o motivo.”; “As evidências estão reunidas.”; “Você decide o próximo passo.” Só usar quando corresponder ao estado real.

## Movimento

Uma ação por gesto: antecipação breve, movimento principal e pausa. Entrada de personagem em 420 ms, sem loop ao lado de leitura. Com redução de movimento, usar apresentação estática. system/motion.css é um exemplo implementável, não um rig nem vídeo renderizado.

## Fontes de critérios

- Apple App Icons: https://developer.apple.com/design/human-interface-guidelines/app-icons
- Apple Icon Composer: https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer
- Apple Materials: https://developer.apple.com/design/human-interface-guidelines/materials
- WCAG 2.2, contraste: https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html
- Fontes tipográficas e OFL: https://github.com/google/fonts

Consulta em 26/09/2026. As decisões de marca e margens editoriais são próprias do projeto. Não foi feita nova pesquisa de registro de marca nesta etapa.
