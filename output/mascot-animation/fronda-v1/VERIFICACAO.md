# Verificação — animação Fronda v1

Data: 28/09/2026. Escopo: somente a prévia animada em `output/mascot-animation/fronda-v1`.

## Revisão orgânica — executado

- Build e checagem TypeScript estrita repetidos após a revisão: concluídos sem erros. A API de remoção de tipos do Node continua emitindo seu aviso experimental.
- Shaders compilados e textura original carregada. Nenhum erro ou aviso no console do navegador durante as verificações da revisão.
- Amostras de quadros confirmaram crescimento, curvatura, volume e atraso das terminações distintos entre os cinco ramos.
- Gesto de expansão/retração observado em capturas sucessivas: crescimento positivo e depois negativo, preservando o apoio dos pés.
- Estado de erro: os cinco ramos com crescimento negativo; chapéus se recolheram e pontas assumiram coral.
- Pausa: snapshot completo permaneceu idêntico entre amostras, incluindo corpo, cor e as novas deformações.
- Movimento reduzido: primeira leitura imediata ocorreu antes da aplicação da pose; repetida após o próximo quadro, a pose permaneceu idêntica em duas amostras separadas por 350 ms. O gesto de expansão ficou desabilitado.
- Clique em alvo de ramo deformado acionou a reação das pontas sem abrir popover. A posição do alvo agora inclui crescimento e curvatura.
- Arraste real com mouse: deslocamento observado de aproximadamente 7% da largura e 4% da altura do canvas; soltar não abriu popover. Enter abriu ações e Escape centralizou.
- Guia: o botão Experimentar acionou conclusão.
- Intensidade de 150% com conclusão e expansão simultâneas: seis amostras de pixels não encontraram corte de conteúdo nas bordas do canvas com o personagem centralizado.
- Aparências clara/escura e largura de 390 px conferidas. Nenhuma rolagem horizontal; canvas de 350 × 350.
- Amostra de 90 quadros em 1.486 ms: aproximadamente 60 FPS neste navegador. Não representa medição do app nativo ou de consumo de bateria.
- Vídeo orgânico atualizado: captura real com download concluído e conversão H.264. `fronda-organico.mp4`: 900 × 1000, 35,975 segundos, 3.179.589 bytes. A primeira sessão do navegador foi encerrada durante o download; a captura foi refeita com sucesso em uma sessão isolada, sem erros de execução da página.

Não foram criados arquivos de teste, mocks ou dependências. Esta revisão usa as interações reais do navegador como conferência pontual.

## Versão anterior — executado

- Build dos módulos TypeScript para JavaScript com `node build.mjs`: concluído. O Node emite o aviso de que a API de remoção de tipos é experimental.
- Checagem TypeScript em modo estrito, incluindo `noUncheckedIndexedAccess`: concluída sem erros, usando o compilador já instalado em `/Users/pedronazarito/Developer/naza-control/node_modules/typescript/lib/tsc.js`. Nenhuma dependência foi instalada ou alterada naquele projeto.
- Carregamento real da textura RGBA e compilação dos shaders no navegador: concluídos. Console sem erros ou avisos durante as verificações finais.
- Movimento contínuo: amostras de quadros mostraram ângulos e pigmentação diferentes entre os cinco ramos.
- Conclusão: a altura do salto começou em zero, subiu, retornou a zero e permaneceu acomodada depois da sequência.
- Pausa: o relógio da animação e os ângulos dos ramos permaneceram iguais entre amostras.
- Movimento reduzido: relógio estacionário e pose fixa, com corpo sem balanço ou salto.
- Arraste por eventos reais do navegador: deslocamento observado; soltar não abriu o popover acidentalmente.
- Teclado: Enter abriu o popover; Escape e controles de foco foram exercitados.
- Ação contextual do guia: o alvo “Experimentar” acionou o estado de conclusão.
- Aparências clara e escura: inspeção visual e conferência das cores calculadas dos controles.
- Largura de 390 px: nenhuma rolagem horizontal; canvas de 350 × 350.
- Escala de 40%: inspeção do personagem pequeno com pontas âmbar e cinco terminações visíveis.
- Amostra de 45 quadros: aproximadamente 60 FPS em 733,5 ms no navegador desta máquina. É uma amostra curta, não um benchmark de dispositivos ou do app nativo.
- Exportação real: download WebM concluído; conversão para MP4 H.264 concluída. O MP4 tem 900 × 1000, aproximadamente 21,58 segundos e 2,59 MB.

## Não executado

- Nenhum teste automatizado, arquivo de teste ou mock foi criado.
- Não há configuração de lint neste artefato; lint não foi executado.
- Build ou testes do aplicativo Swift não foram executados, porque seus arquivos não foram alterados.
- Não foram validados execução dentro do app nativo, VoiceOver, múltiplos monitores ou consumo de bateria de uma janela flutuante persistente.

## Referências técnicas

- Texturas e transparência em WebGL: https://developer.mozilla.org/en-US/docs/Web/API/WebGL_API/Tutorial/Using_textures_in_WebGL
- Captura de quadros do canvas: https://developer.mozilla.org/en-US/docs/Web/API/CanvasCaptureMediaStreamTrack/requestFrame

Os dados de tarefa mostrados na prévia são rótulos de estados de animação. Não representam execuções reais do Fronda.
