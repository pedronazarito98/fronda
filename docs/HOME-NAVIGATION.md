# Home, navegação e estados dos cards

## Escopo

Reorganizei a Visão geral em cinco áreas: decisões que precisam do usuário, trabalho em andamento, tarefas recentes, projetos e preparação de uma tarefa. Mantive os tokens de cor existentes. O guia com o mascote permanece uma etapa posterior à prioridade atual.

## Regras de interação

- A ordem dos cards permanece estável quando os dados das tarefas mudam.
- Organizar revela uma grade de colunas e linhas, além das alças para mover e redimensionar. Os menus oferecem as mesmas operações sem exigir arraste.
- Durante o gesto, uma prévia do card acompanha o cursor sem animação de atraso. O encaixe fica marcado e os demais cards se reorganizam antes de soltar. O redimensionamento mostra dimensões contínuas e o tamanho de encaixe (Compacto, Confortável ou Ampliado).
- Cada gesto registra uma única mudança em Desfazer e persiste somente ao terminar. Esc, perda de foco da cena ou alteração da largura da janela cancelam a interação e recuperam a composição anterior.
- Compacto, Confortável e Ampliado ajustam a densidade e o número de itens. Ampliado ocupa duas colunas quando há espaço. Em janelas estreitas, os cards passam para uma coluna sem rolagem horizontal.
- Cards vazios usam menos altura e explicam o próximo passo. Carregamento, conexão indisponível, tarefas existentes e ausência de tarefas têm tratamentos distintos.
- Ocultar não remove dados. Ao menos um card permanece visível. Desfazer guarda até 30 mudanças da sessão de organização; Restaurar recupera a composição inicial.
- Ordem, visibilidade e tamanho são preferências locais persistidas em `fronda.home.layout.v1`.
- O resumo de atenção continua no cabeçalho mesmo quando o card correspondente está oculto.
- Os detalhes do ambiente ficam em um popover. Preparar tarefa abre o compositor com o objetivo preenchido, sem executar automaticamente.

## Navegação

- Voltar e Avançar estão na barra nativa e no menu Navegar, com `⌘[` e `⌘]`.
- O histórico pertence à janela, guarda até 60 destinos e inclui seções de uma tarefa. Visitar outro destino depois de voltar descarta a sequência de avanço.
- Visitar novamente o destino atual não duplica a entrada.
- Busca, filtros, ordenação, rascunhos e seleções relevantes usam armazenamento por cena. As páginas com listas preservam a posição de rolagem.
- O gesto de dois dedos usa o reconhecimento nativo do AppKit, respeita a preferência de deslizar entre páginas do macOS e navega na fase `.ended` do gesto físico, sem esperar a animação de acomodação terminar. `.cancelled` preserva o histórico.
- A tela principal lê diretamente `WorkspaceNavigation.location`; `AppStore.route` e a seleção lateral encaminham para esse mesmo estado de forma síncrona. O armazenamento por cena apenas guarda o destino para restauração.
- Rolagem vertical, editores de texto, conteúdo horizontal, folhas modais e organização da Home não devem disparar o gesto de navegação.
- A organização suspende os comandos de histórico. As janelas independentes de tarefa mantêm histórico próprio entre suas seções.

## Implementação

Os componentes da Home ficam em `Sources/HarnessUI/Views/CommandCenter/`. O layout usa `SwiftUI.Layout`, sem dependências externas. A integração AppKit fica em `Views/Navigation/WorkspaceSwipeNavigation.swift`; o estado continua em SwiftUI/Observation. `RunWindowView` aplica o mesmo comportamento às janelas de tarefa.

### Arquivos desta etapa

- Novos componentes da Home: `HomeCard.swift`, `HomeCardConfiguration.swift`, `HomeCardGrid.swift`, `HomeLayoutStore.swift`, `HomeWorkContent.swift`, `HomeProjectContent.swift`, `HomeStartContent.swift` e `HomeEnvironmentButton.swift`, em `Views/CommandCenter/`.
- Nova infraestrutura de navegação: `WorkspaceNavigation.swift`, `WorkspaceHistoryControls.swift`, `WorkspaceSwipeNavigation.swift` e `RememberScrollPosition.swift`, em `Views/Navigation/`; `RunWindowView.swift`, em `Views/Workspace/`.
- Integração da Home e do histórico: `Views/CommandCenterView.swift`, `Views/ContentView.swift`, `Views/Navigation/WorkspaceToolbar.swift`, `Views/RunWorkspace.swift`, `App/HarnessApp.swift` e `App/FrondaCommands.swift`.
- Preservação de estado das páginas: `Views/RunsView.swift`, `Views/ProjectsView.swift`, `Views/RunbooksView.swift`, `Views/DiaryView.swift`, `Views/DecisionsView.swift`, `Views/Guide/GuideView.swift` e `Views/Projects/ProjectDetailView.swift`.
- Projeto Xcode regenerado pelo script existente para incluir as novas fontes. Outros arquivos já modificados no checkout não fazem parte desta etapa.

## Verificação da primeira etapa em 27/09/2026

- Lint do projeto e `git diff --check` executados sem erros.
- 42 testes existentes do núcleo passaram pelo SwiftPM e pelo Xcode.
- A execução final de `script/validate.sh` terminou com código 0: lint, 42 testes pelo SwiftPM, 48 testes pelo Xcode (42 de núcleo e 6 de interface), build universal e assinatura. Nenhum teste falhou ou foi ignorado.
- Relatório final, incluindo o grupo nativo da barra e a reordenação até a última posição: `.build/qa/run-XK1Fvp/Harness.xcresult`.
- As tentativas anteriores registraram um timeout de inicialização da automação e uma falha ao abrir Ajustes com outra cópia do app aberta. O cenário isolado e a suíte completa passaram após fechar a cópia normal, sem mudar permissões ou testes. Para repetir a validação, mantenha a cópia normal do Fronda fechada durante o XCUITest.
- Build universal, assinatura ad hoc e abertura de `dist/Fronda.app` verificados pelo script existente.
- Conferência direta no app: estado vazio, menu de tamanho, controle acessível de redimensionamento, mover pelo menu, ocultar, desfazer, composição mantida ao trocar de página, botão Avançar, atalhos de histórico e retenção de busca/filtro. Escolher outro destino após voltar desabilitou corretamente Avançar.
- A composição personalizada permaneceu após reiniciar. Restaurar recuperou os tamanhos padrão, e Desfazer recuperou a composição personalizada. A Home foi inspecionada nos temas claro e escuro; a preferência original Sistema foi restaurada. Os nomes acessíveis Voltar e Avançar foram confirmados depois de trocar de página.
- Nenhum teste, mock ou dependência foi acrescentado.

## Revisão de interação e resposta em 27/09/2026

O usuário confirmou o funcionamento físico do swipe e de Voltar/Avançar, relatando atraso após a ação. Também identificou a ausência de grade e de atualização durante o movimento das alças. Esta revisão trata esses pontos.

### Arquivos da revisão

- Criados `Views/CommandCenter/HomeCardBoard.swift`, `HomeCardInteraction.swift` e `HomeEditingGrid.swift`: gesto local, prévia contínua, destino de encaixe, cancelamento e grade desenhada com os tokens existentes.
- Alterados `Views/CommandCenter/HomeCard.swift`, `HomeCardGrid.swift` e `HomeLayoutStore.swift`: alças com `DragGesture.onChanged`, identidade estável durante reordenação, transação única de desfazer e persistência ao terminar.
- Alterado `Views/CommandCenterView.swift`: integração do editor e instruções de uso.
- Alterados `Stores/AppStore.swift` e `Views/ContentView.swift`: remoção da sincronização em três etapas entre rota, seleção e histórico.
- Alterado `Views/Navigation/WorkspaceSwipeNavigation.swift`: confirmação na conclusão física do swipe.
- Atualizados este documento e `Harness.xcodeproj/project.pbxproj`, regenerado pelo script do projeto. Todos os caminhos de fontes acima são relativos a `Sources/HarnessUI/`.

### Evidência e limites da revisão

- Compilação SwiftPM do app executada com sucesso.
- A execução final de `./script/validate.sh` terminou com código 0: lint, 42 testes SwiftPM, 48 testes Xcode (42 de núcleo e 6 de interface), build universal e assinatura ad hoc. O resumo do Xcode registra zero falhas, zero testes ignorados e zero avisos de execução. Relatório: `.build/qa/run-pt4Ra7/Harness.xcresult`.
- A primeira tentativa (`run-9WTCOf`) passou nos 42 testes de núcleo e teve timeout ao inicializar a automação de interface. A repetição completa passou sem alterar testes nem permissões. A compilação emitiu avisos de conversão de inteiros no código existente de `Vendor/CTreeSitter`; esses arquivos não foram modificados.
- No app nativo, a alça moveu Precisa de você para depois de Em andamento; a alça de tamanho alterou Em andamento de Ampliado para Confortável. Cada gesto foi revertido com um único Desfazer. A disposição original foi recuperada ao terminar a conferência.
- Grade de organização inspecionada visualmente. Voltar pelo atalho e Avançar pelo botão preservaram a busca de Projetos; a busca usada na conferência foi limpa ao terminar.
- A captura da automação retorna depois de soltar o cursor; não mede a fluidez quadro a quadro. A prévia está ligada a cada `onChanged`, enquanto a gravação fica no término do gesto. Não foi produzido um benchmark de latência do trackpad.
- Conferência física recomendada: mover devagar e inverter o sentido, redimensionar em ambos os eixos, cancelar com Esc e experimentar swipes curtos/cancelados. A tentativa de estreitar a janela pela automação não mudou suas dimensões; a inspeção visual nesta revisão ocorreu na janela ampla.
- Não foram criados testes, mocks ou dependências.

Referência da mudança do swipe: a [documentação Apple de `trackSwipeEvent`](https://developer.apple.com/documentation/appkit/nsevent/trackswipeevent(options:dampenamountthresholdmin:max:usinghandler:)) distingue o fim físico do gesto do término de sua animação; o cabeçalho `NSEvent.h` do SDK instalado documenta `.ended` e `.cancelled`.
