# Workspace com abas e execução por projeto

## Experiência implementada

A janela principal usa a paleta existente do Fronda, uma navegação lateral recolhível e abas internas na mesma toolbar nativa de voltar, avançar e buscar. A faixa separada de abas foi removida; a toolbar compacta libera altura para o conteúdo. Cada aba mantém a sua página, o histórico, os filtros do quadro e a posição de leitura. O botão de alfinete alterna o resumo da aba. O botão de divisão abre um segundo painel na página de escolha, sem presumir um destino. A divisória nativa pode ser arrastada; seu botão central troca os lados. Em janelas estreitas, os dois painéis permanecem disponíveis por um seletor, sem comprimir o conteúdo até perder os controles.

As abas e a proporção dos painéis são salvas entre aberturas do aplicativo. A restauração é isolada por raiz de dados explícita, para que ambientes locais de QA não substituam o espaço de trabalho principal. A divisão começa em aproximadamente 63% para o painel esquerdo e 37% para o direito, respeitando as larguras mínimas. A troca de lados move as instâncias de navegação, com histórico, estado e foco, e mantém a largura física das colunas. A posição de leitura salva corresponde à rolagem vertical.

A página de tarefas abre no quadro. Cada projeto tem uma raia recolhível, com as colunas Preparar, Investigar, Implementar, Revisar e Concluído. A coluna acompanha a etapa real do plano; apenas uma entrega encerrada entra em Concluído. Estados como pausa, impedimento e cancelamento continuam visíveis no card. Arquivar uma tarefa não significa concluí-la. Busca, ordenação, filtros e comparação de abordagens continuam disponíveis no popover de filtros. A apresentação em lista foi preservada.

Clicar em um card abre a tarefa ao lado. Seu menu oferece abrir na página atual, em uma nova aba ou ao lado. O painel da tarefa reúne objetivo, resultado mais recente, acesso ao plano e às alterações, além de orientação ao executor. Os dados vêm da execução real. Não há respostas simuladas. As áreas de contexto, validação, revisão, evidências, atividade e tokens continuam disponíveis.

Nas abas da janela principal, os detalhes técnicos abrem em popover, inclusive na apresentação compacta. Na janela própria da tarefa, o inspetor lateral existente permanece disponível. O quadro deriva as colunas do plano real: mover visualmente uma tarefa entre etapas não substitui execução, validação ou aprovação.

Modelo e esforço possuem seletores independentes. Escolher uma opção prepara uma edição; Aplicar usa o contrato existente de `plan.save`, com controle de sequência e nova aprovação. As configurações específicas das etapas continuam preservadas. As seleções ficam indisponíveis durante uma execução ativa.

Na Home, redimensionar pela alça altera a altura do card durante o gesto. A largura encaixa nas colunas e a altura final encaixa a cada 16 pontos. Conteúdo excedente ganha rolagem interna. Arraste e redimensionamento geram uma única ação de desfazer; Escape cancela. Os presets e as alternativas acessíveis por teclado continuam disponíveis.

## Nova aba e escolha dos painéis

O botão `+` e `⌘T` abrem a mesma página: busca local, destinos do workspace em duas colunas, projetos e tarefas recentes ordenadas pela última atualização. As opções usam os dados existentes; não há atalhos sem funcionalidade. Escolher um destino abre o conteúdo no próprio painel. O menu contextual também permite abrir em nova aba ou ao lado.

Cada painel dividido oferece “Escolher conteúdo”, inclusive no cabeçalho de uma tarefa. Voltar recupera o destino anterior. A busca da página de escolha é preservada com o estado do painel. O botão central “Trocar painéis” mantém o conteúdo que estava em foco; voltar/avançar e os atalhos continuam direcionados a ele. No modo compacto, a troca permanece disponível ao lado do seletor de painéis.

Os controles de abas, toolbar, divisão, navegação lateral, cards e áreas da tarefa receberam descrições de ajuda nativas (`.help`), exibidas ao manter o cursor sobre o controle.

O botão de nova aba permanece fora da rolagem horizontal, para continuar visível quando há muitas abas. O item principal da toolbar aceita uma largura menor; as ações nativas mantêm seu espaço.

### Arquivos da revisão da toolbar e dos painéis

- Criado `Views/Navigation/WorkspaceStartPage.swift` para a escolha de conteúdo.
- Alterados `WorkspaceToolbar.swift` e `WorkspaceTabBar.swift` para integrar as abas na toolbar e manter o `+` acessível.
- Alterados `WorkspaceSession.swift`, `WorkspaceNavigation.swift`, `WorkspacePane.swift` e `WorkspaceSplitHandle.swift` para a nova rota, escolha e troca dos painéis.
- Alterados `Views/ContentView.swift` e `App/HarnessApp.swift` para composição, identidade dos painéis e toolbar compacta.
- Alterados `Views/Workspace/RunWorkspaceHeader.swift`, `RunWorkspaceNavigation.swift`, `Views/Navigation/WorkspaceRail.swift`, `Views/SidebarView.swift`, `Views/CommandCenterView.swift`, `Views/CommandCenter/HomeCard.swift` e `Views/Runs/RunBoardCard.swift` para acesso à escolha e descrições de ajuda.
- Atualizados o projeto Xcode gerado e `design-qa.md`. Os caminhos de código acima são relativos a `Sources/HarnessUI/`.

## Navegação

- `⌘T` ou `+`: nova aba com escolha de página, projeto ou tarefa.
- `⇧⌘W`: fechar a aba. `⌘W` mantém a função nativa de fechar a janela.
- `⇧⌘T`: reabrir a última aba fechada.
- `⌃Tab` e `⇧⌃Tab`: próxima aba e aba anterior.
- `⌃⌥\``: alternar o painel em foco.
- `⌘[` e `⌘]`: voltar e avançar no painel em foco.
- O swipe mantém a proteção dos conteúdos com rolagem horizontal, como o quadro e o diff.
- Fechar aba ou painel não pausa, cancela nem arquiva uma execução.

## Arquivos desta implementação

- `Sources/HarnessUI/Views/Navigation/WorkspaceSession.swift`: abas, painéis, foco e restauração.
- `WorkspaceNavigation.swift`, `RememberScrollPosition.swift`: histórico e leitura por painel.
- `WorkspaceTabBar.swift`, `WorkspaceToolbar.swift`, `WorkspaceRail.swift`, `WorkspacePane.swift`: composição, toolbar nativa e controles.
- `WorkspaceStartPage.swift`: página de escolha reutilizada por novas abas e painéis.
- `WorkspaceSplitPosition.swift`, `WorkspaceSplitHandle.swift`: sincronização do divisor AppKit, alça com área de interação ampliada e ajuste por acessibilidade.
- `Sources/HarnessUI/Views/ContentView.swift`, `Stores/AppStore.swift`, `App/FrondaCommands.swift`: integração com a janela e os comandos existentes.
- `Views/RunsView.swift` e `Views/Runs/RunBoard*.swift`: quadro, raias, cartões e classificação de etapas.
- `Views/RunWorkspace.swift`, `Views/Workspace/RunWorkspaceHeader.swift`, `RunWorkspaceNavigation.swift`, `RunWorkspaceSection.swift`, `RunConversationView.swift`: tarefa e navegação interna.
- `Views/Execution/RunExecutionPickers.swift`: popovers de modelo e esforço.
- `Views/RunPlanView.swift`, `Views/ContextView.swift`: adaptação do conteúdo ao painel lateral.
- `Views/CommandCenterView.swift` e `Views/CommandCenter/HomeCard*.swift`, `HomeLayoutStore.swift`: hierarquia e organização da Home.
- `Components/FrondaAssets.swift`, `Resources/FrondaSymbolLight.png`, `Resources/FrondaSymbolDark.png`: reaproveitamento dos símbolos aprovados.
- `script/generate_xcode_project.py` e projeto Xcode gerado: inclusão dos arquivos e recursos.

## Validação

Os resultados observados, capturas e comparação com a referência aprovada são registrados em `design-qa.md`. Não foram criados testes, mocks ou dependências. Foram executadas as verificações já existentes no projeto.
