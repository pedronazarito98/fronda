# Fronda — prévia animada com movimento orgânico

Revisão da etapa de animação, baseada no storyboard v2 e no pedido de aproximar o movimento de um fungo vivo. O personagem é renderizado a partir de uma única textura orgânica transparente, com malha deformável, cinco ramificações controladas separadamente e 26 terminações com raízes e ritmos próprios. A prévia é independente do aplicativo nativo: os estados são demonstrações acionadas pelo usuário, sem acesso a tarefas, credenciais ou dados do Fronda.

## Abrir

Enquanto o servidor desta sessão estiver ativo: http://127.0.0.1:8796.

Para iniciar novamente, neste diretório:

```sh
node build.mjs
python3 -m http.server 8796 --bind 127.0.0.1
```

O JavaScript compilado já está em `dist/`; recompilar só é necessário após editar o TypeScript. O build usa `stripTypeScriptTypes` do Node, validado com Node 26.8.2, sem instalar dependências.

## O que experimentar

- Usar **Expandir e recolher**: uma onda alonga os ramos, abre os chapéus e recolhe o tecido, com atrasos entre cada parte.
- Os seis estados: tranquilo, trabalhando, atenção, conclusão, erro e orientação.
- Aproximar o cursor para orientar o olhar e o ramo mais próximo.
- Clicar nas terminações para provocar um impulso que percorre os ramos.
- Arrastar o corpo e observar a inércia e acomodação das ramificações.
- Clicar no corpo para abrir o popover de ações demonstrativas.
- Focar o mascote com Tab: setas movem, Enter abre ações e Escape centraliza.
- Ajustar expressão, ritmo e tamanho. O tamanho menor permite avaliar a leitura em escala de pet no desktop.
- Pausar, repetir o gesto, percorrer os estados, alternar aparência e ativar movimento reduzido.
- Salvar um vídeo dos seis estados pelo botão da prévia.

## Arquivos

- `index.html`, `styles.css`: interface de avaliação.
- `assets/fronda-neutral.png`: recorte RGBA, 1254 × 1254, preparado pela ferramenta integrada image_gen a partir da arte aprovada. O prompt integral está em `prompts/recorte-transparente.txt`.
- `src/motion.ts`: estados, prioridades locais de interação, ondas de cor e salto único.
- `src/organic-motion.ts`: crescimento e retração por ramo, abertura dos chapéus, resposta ao toque e atraso das terminações.
- `src/motion-spring.ts`: molas com integração em pequenos passos, compartilhadas pelo corpo e pelo tecido.
- `src/filaments.ts`: 26 raízes e seus pesos de deformação, preservando a ligação dos tentáculos com os chapéus.
- `src/branch-deformation.ts`: posição dos alvos de interação acompanhando a curvatura e o crescimento.
- `src/rig.ts`: pivôs, terminações, olhos e escala de referência.
- `src/shaders.ts`, `src/renderer.ts`: malha, deformação contínua, pigmentação das pontas e renderização WebGL.
- `src/interactions.ts`: cursor, toque, arraste, teclado e distinção entre clique e deslocamento.
- `src/states.ts`, `src/animation.types.ts`: seis situações e seus tipos.
- `src/main.ts`: controles e ciclo de apresentação.
- `src/recorder.ts`: gravação local da demonstração.
- `dist/`: módulos JavaScript gerados pelo build.
- `fronda-organico.webm`, `fronda-organico.mp4`: captura desta revisão, aproximadamente 36 segundos, 900 × 1000. MP4 H.264 para reprodução mais ampla.
- `fronda-movimento.webm`, `fronda-movimento.mp4`: captura anterior, mantida para comparação.
- `organic-*.png`: capturas desta revisão. `preview-*.png` pertencem à versão anterior.
- `VERIFICACAO.md`: verificações executadas e limites.

## Decisões de movimento

O mesmo desenho é deformado de modo contínuo, evitando alternar entre ilustrações com proporções diferentes. A nova malha tem 160 × 160 células. A curvatura é distribuída ao longo dos ramos; o ramo maior responde mais lentamente. Crescimento longitudinal, volume dos chapéus e tentáculos têm tempos de acomodação diferentes. Os ramos permanecem unidos ao tronco; a cor acompanha as coordenadas da própria textura.

A expansão e retração são uma interpretação expressiva de crescimento acelerado e tecido flexível, não uma simulação biológica. No repouso há ciclos lentos e defasados. Trabalho intensifica o crescimento; erro encurta os ramos e curva as terminações; conclusão expande os chapéus. O gesto manual dura 5,4 segundos, com atraso de 140 ms entre ramos.

O trabalho usa uma onda sálvia; atenção usa âmbar; conclusão usa verde; erro usa coral. O modo de orientação destaca a ponta que indica o alvo. As reações de toque preservam a cor do estado atual. Pausa congela o quadro completo, incluindo tentáculos, cor, olhos e corpo. Movimento reduzido oferece poses estáveis, mantém a escolha de estados e desabilita o gesto de expansão.

As deformações de crescimento e abertura têm limites próprios para preservar a silhueta. O salto de conclusão e o aceno de atenção acontecem ao entrar no estado, sem repetição insistente. Os controles permitem repetir esses gestos intencionalmente. Alterações de estado transitam através de molas, sem esperar que o gesto anterior termine.

## Limites desta etapa

Esta é uma animação 2D de textura com deformação, sem modelo 3D ou rotação completa do personagem. As inclinações foram limitadas para preservar o volume aparente do desenho.

Acompanhamento de tarefas reais, notificações nativas, janela flutuante do macOS e guia que navega entre páginas pertencem à integração seguinte. Nenhum código Swift ou asset de produção foi alterado nesta etapa.

Para a decisão visual, avaliar a amplitude dos ramos, a cor das pontas, o conforto do arraste e a legibilidade em tamanho pequeno. A acessibilidade aqui foi conferida por teclado e movimento reduzido; não foi realizada uma sessão de VoiceOver.
