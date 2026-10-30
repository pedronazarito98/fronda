# Mascote integrado e mini companheiro

Implementação de 28/09/2026. Preserva a arte e os movimentos aprovados em
`output/mascot-animation/fronda-v1`. As sete ideias de personalidade continuam
adiadas em `FRONDA-MASCOTE-IDEIAS-FUTURAS.md`.

## Uso

- O mini companheiro aparece sobre as janelas, sem moldura. Arraste o corpo para
  mudar sua posição; um arraste não abre o popover ao soltar.
- Clique para ver tarefas nativas e sessões externas da central existente.
  Há ações para criar uma tarefa, abrir o Fronda, ver decisões e abrir a central.
- O popover oferece tamanho entre 112 e 240 pontos, animação e restaurar posição.
- O botão de ocultar e o menu de contexto escondem o mini. Para reabrir, use
  **Execução → Mostrar companheiro**, o menu do Fronda na barra superior ou
  **Ajustes → Geral → Mini companheiro Fronda**.
- `⌃⌥⌘M` alterna a visibilidade quando o Fronda recebe o atalho. Não é um atalho global.
- **Execução → Tarefas do companheiro** coloca o mini em foco e abre suas ações.
  Em foco, as setas movem 12 pontos, Enter/Espaço abrem as ações e Esc fecha o popover.
- Visibilidade, tamanho, animação e posição ficam salvos em preferências locais.
  A posição é limitada à área útil da tela e se adapta ao desconectar um monitor.

## Decisões técnicas

`NSPanel` transparente para a janela flutuante, `NSPopover` e SwiftUI para as ações,
`MTKView` para o personagem. A textura, malha, shader e simulação ficam dentro do
bundle. Não há navegador, servidor HTTP, CDN, downloads de assets ou dependência
nova de pacote. O coordenador local já existente continua responsável pelos dados
de tarefas; ele não serve a animação.

JavaScriptCore executa apenas a matemática empacotada da prévia aprovada, sem ponte
de rede ou acesso ao filesystem. Metal executa a mesma deformação da arte, incluindo
as ramificações, crescimento, franjas, olhos e pigmentação das pontas. Os recursos
da GPU são compartilhados entre as instâncias. Ícones menores que 60 pontos usam
o asset estático.

O mini acompanha as tarefas e sessões reais em `AppStore.mascotActivities`.
A prioridade é: decisão pendente, impedimento/erro, resultado parcial, resultado
pronto, execução e repouso. Empates favorecem a atualização mais recente; o ID
estabiliza a ordem. Resultados parciais pedem conferência, sem comemorar conclusão.
Resultados nativos ficam disponíveis até encerramento/arquivamento/cancelamento;
nas sessões externas, conclusão e interrupção destacam apenas a última hora.
Dados desatualizados/desconectados não simulam trabalho acontecendo.

As ações abrem a decisão exata ou a seção relevante da tarefa (contexto, plano,
resultado, alterações). Sessões Codex usam o destino existente da sessão; Claude
usa a central de sessões. `visibleExternalSessions` mantém a deduplicação e
`SessionIslandController.openHarness` mantém a navegação existente. Não há novas
consultas periódicas ao coordenador. A observação pertence ao controlador do
companheiro, independente da janela principal.

Durante a jornada, o mini usa a expressão de ensinar, preservando a prioridade
das decisões e impedimentos. O popover também permite iniciar/retomar o guia.
Veja `FRONDA-GUIDED-JOURNEY.md` para etapas, persistência e validação.

A renderização usa 30 FPS, ou 15 FPS no modo de baixo consumo. Pausa quando oculta,
ocluída, com a tela em repouso ou com movimento desativado. Reduzir Movimento do
macOS substitui a animação por uma pose estática que conserva a informação de estado.
Se a GPU ou os recursos não estiverem disponíveis, usa a imagem estática original.

## Arquivos

- `Sources/HarnessUI/Components/Mascot/MascotResources.swift`: recursos Metal e simulação.
- `Sources/HarnessUI/Components/Mascot/MascotMetalView.swift`: renderização, ciclo de vida e interação.
- `Sources/HarnessUI/Components/Mascot/MascotHitRegions.swift`: regiões dos ramos.
- `Sources/HarnessUI/Components/FrondaMascot.swift`: integração com as telas existentes.
- `Sources/HarnessUI/Stores/MascotCompanionController.swift`: janela, posição, estado e navegação.
- `Sources/HarnessUI/Views/Mascot/MascotCompanionPopover.swift`: tarefas e ações.
- `Sources/HarnessUI/Views/Settings/SettingsMascotCompanion.swift`: controles em Ajustes.
- `HarnessApp.swift`, `FrondaCommands.swift`, `MenuBarView.swift`, `SettingsView.swift`
  e `GeneralSettingsView.swift`: pontos de integração no app existente.
- `Resources/FrondaAnimation/`: recursos offline gerados.
- `script/package_mascot.mjs`: gera esses recursos a partir da prévia aprovada.
- `script/generate_xcode_project.py` e `Harness.xcodeproj/project.pbxproj`: inclusão no bundle.

O build normal usa os recursos já gerados, sem precisar do Node. Para atualizar a
animação após uma mudança aprovada na prévia, rode `node script/package_mascot.mjs`
com Node que ofereça `stripTypeScriptTypes`, e depois `./script/build_and_run.sh --verify`.

## Verificação observada

- Build universal de Debug, assinatura ad hoc e inicialização pelo script oficial.
- Compilação real do shader no Metal e carregamento da textura 1254 × 1254.
- JavaScriptCore retornou 64 valores finitos para os seis estados da prévia.
- `./script/validate.sh --unit-only`: lint e os 42 testes existentes aprovados.
  Nenhum teste ou mock novo foi criado.
- Interface nativa: popover mostrou a sessão real do Codex; Nova tarefa, Decisões e
  Ver sessões abriram os destinos existentes; Esc fechou o popover. O Guia exibiu
  a arte integrada sem fundo retangular.
- Tamanhos 112, 176 e 240; animação ligada/desligada; preferências preservadas após
  relançamento; ocultação e reabertura pelo menu/atalho.
- Capturas consecutivas do mini ficaram idênticas com movimento desativado e
  diferentes com animação ligada. Movimento por seta alterou a posição persistida em 12 pontos.

Validação de uso: conferir conforto do arraste físico, múltiplos monitores, repouso
do sistema, VoiceOver e consumo prolongado em bateria no ambiente real do usuário.
Esses cenários de hardware não foram simulados nem apresentados como verificados.
O XCUITest completo não foi executado nesta etapa; a interface nova foi conferida
pela automação nativa sobre o app compilado.
