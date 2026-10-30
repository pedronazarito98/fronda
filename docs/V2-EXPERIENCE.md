# Fronda V2 — experiência de trabalho no Mac

A V2 tem como foco a usabilidade do fluxo: entender onde a tarefa está, observar o resultado de cada etapa e agir quando uma decisão ou evidência for necessária. O workspace reúne a jornada, os resultados registrados e as ações para continuar. A identidade Fronda e o coordenador existente continuam sendo a base do produto.

## O que mudou

- **Visão geral:** entrada contextual para o primeiro projeto; tarefas que pedem atenção; retomada de trabalhos recentes; fluxos e disponibilidade real dos executores.
- **Navegação:** barra lateral com busca, projetos e tarefas recentes; seleção sincronizada com os comandos; confirmação visível de operações concluídas.
- **Busca:** comandos, páginas, tarefas, projetos e fluxos no mesmo lugar; correspondência sem distinção de acentos; seleção por clique ou teclado; criação a partir de um fluxo.
- **Tarefas:** busca por título/projeto/executor, filtros com contagem, ordenação e estados vazios contextuais.
- **Nova tarefa:** objetivo e critérios em destaque; configuração em coluna própria; autonomia, escopo e orçamento em opções avançadas; anexos removíveis e prévia nativa por Quick Look.
- **Jornada da tarefa:** etapas clicáveis, indicação da etapa atual e estados de execução, aprovação, evidência e impedimento; resultados registrados aparecem junto da etapa correspondente.
- **Próximo passo:** o cabeçalho explica o que precisa de você e leva à revisão de contexto, plano, reprodução, conferência ou entrega. Pausa e orientação permanecem acessíveis durante o trabalho.
- **Workspace:** navegação entre etapas, retorno ao acompanhamento atual, acesso direto a cenários, detalhes em inspector nativo e orientação multilinha. Modo foco e atalhos complementam esses controles.
- **Aparência:** superfícies com hierarquia mais clara, paleta adaptativa, cores semânticas e contornos que respeitam contraste aumentado. Os assets aprovados da marca foram preservados.

## Acompanhar e interagir com uma tarefa

Na **Visão geral** do workspace, a jornada mostra as etapas do plano e o estado de cada uma. Em janelas largas, a lista fica ao lado do resultado selecionado; em janelas menores, as etapas aparecem em uma faixa horizontal.

1. **Clique em uma etapa** para conferir seu objetivo, resultado esperado, dependências e conteúdo já registrado. Também é possível usar “Etapa anterior” e “Ver próxima etapa”. Esses controles mudam a visualização; a execução continua seguindo o plano e suas aprovações.
2. **Confira o resultado da etapa.** Contexto mostra os arquivos incluídos; investigação e plano mostram os textos produzidos; implementação mostra alterações; validação mostra os resultados dos comandos; revisão mostra achados; reprodução, conferência e entrega mostram observações, critérios e evidências. Quando não há resultado, a interface informa o que ainda falta ser registrado.
3. **Abra o detalhe quando precisar agir.** Cada etapa oferece uma ação para acessar sua área completa: revisar arquivos e contexto, conferir o plano, examinar o diff, executar validações ou revisar achados. Dependências pendentes também podem ser abertas por clique.
4. **Use a ação indicada no cabeçalho.** “Revisar contexto” e “Revisar plano” levam ao conteúdo que precisa de aprovação. “Registrar reprodução” e “Conferir cenário” abrem diretamente **Cenários**, onde é possível registrar observado, esperado, ambiente, critérios e mídia. “Revisar entrega” abre as evidências para conferência.
5. **Volte à etapa atual** depois de explorar o fluxo. Enquanto a etapa atual está sendo acompanhada, a seleção avança com o estado recebido do coordenador. Selecionar outra etapa mantém a exploração naquele ponto; “Voltar à etapa atual” retoma o acompanhamento.

O resumo permite abrir alterações, validações e evidências. O campo de orientação envia instruções para a tarefa; pausa e cancelamento continuam disponíveis durante a execução, respeitando a conexão com o coordenador. Aprovar contexto, aprovar implementação e confirmar operações externas permanecem ações distintas.

Os resultados vêm do estado real da tarefa no `AppStore`. A jornada mostra conteúdo registrado pelo coordenador e identifica validações, achados e artefatos de uma revisão anterior como desatualizados. A visualização de uma etapa futura não a marca como executada.

## Integração com macOS

A janela principal é única. Cada tarefa pode abrir em uma janela independente, com título e comandos vinculados à tarefa em foco. O Dock reabre a janela principal. Os menus nativos incluem navegação, atualização, tarefas recentes e acesso à worktree no Finder.

A ação “Nova tarefa” recebe prioridade superior na toolbar no macOS 27 com `ToolbarItemVisibilityPriority(higherThan:)`. A implementação conserva caminhos compatíveis com macOS 15 e 26.1; o deployment target permanece macOS 15.

O inspector é SwiftUI nativo, a seleção de arquivos usa o painel do sistema e as prévias de anexos usam Quick Look. Não foram adicionadas dependências.

### Atalhos de apoio

As ações do fluxo têm controles visíveis. Os atalhos abaixo oferecem acesso adicional para quem prefere o teclado.

| Atalho | Ação |
| --- | --- |
| ⌘N | Nova tarefa |
| ⇧⌘N | Adicionar projeto |
| ⌘K | Buscar e executar comando |
| ⌘1 a ⌘6 | Visão geral, tarefas, projetos, decisões, fluxos, diário |
| ⌘R | Atualizar o workspace |
| ⌥⌘↩ | Abrir a tarefa em janela independente |
| ⇧⌘R | Mostrar a worktree da tarefa em foco no Finder |
| ⌃⌘I | Mostrar/ocultar detalhes da tarefa |
| ⌥⌘F | Entrar/sair do modo foco da tarefa |
| ⌘↩ | Enviar orientação à tarefa |
| ⌥⌘I | Central de sessões |

## Organização do código

As telas continuam em `Sources/HarnessUI/Views`. Os componentes extraídos ficam em `CommandCenter`, `Runs`, `Workspace`, `Workflow`, `CommandPalette`, `Navigation` e `NewRun`. `WorkflowOverview` coordena a etapa selecionada e o acompanhamento da etapa atual; os componentes `RunJourney*` organizam estados, navegação e resultados. A rota `RunWorkspaceSection.scenarios` abre `ScenarioEvidenceView` diretamente. Os comandos do sistema ficam em `App/FrondaCommands.swift`. Cores e superfícies continuam centralizadas em `Components`.

O estado persistido de projetos e execuções, o protocolo IPC, as aprovações e os executores mantêm os contratos existentes. Dados reais do `AppStore` alimentam as telas; nenhum cenário demonstrativo foi incorporado ao produto.

## Arquivos desta implementação

Alterados:

- `Sources/HarnessUI/App/HarnessApp.swift`
- `Sources/HarnessUI/Components/FrondaTheme.swift`
- `Sources/HarnessUI/Components/DesignPrimitives.swift`
- `Sources/HarnessUI/Views/ContentView.swift`
- `Sources/HarnessUI/Views/SidebarView.swift`
- `Sources/HarnessUI/Views/CommandCenterView.swift`
- `Sources/HarnessUI/Views/CommandPaletteView.swift`
- `Sources/HarnessUI/Views/RunsView.swift`
- `Sources/HarnessUI/Views/NewRunView.swift`
- `Sources/HarnessUI/Views/RunWorkspace.swift`
- `Sources/HarnessUI/Views/WorkflowOverview.swift`
- `README.md`
- `Harness.xcodeproj/project.pbxproj` (regenerado pelo script existente)

Criados:

- `Sources/HarnessUI/App/FrondaCommands.swift`
- `Sources/HarnessUI/Views/MenuBarView.swift` (extraído da busca)
- `Sources/HarnessUI/Views/Navigation/{WorkspaceDestination,WorkspaceToolbar}.swift`
- `Sources/HarnessUI/Views/CommandPalette/{PaletteEntry,PaletteResultRow}.swift`
- `Sources/HarnessUI/Views/CommandCenter/{CommandIntentCard,WorkspaceStatusCards}.swift`
- `Sources/HarnessUI/Views/Runs/{RunDisplay,RunRow,CompareRunsView}.swift`
- `Sources/HarnessUI/Views/Workspace/{RunWorkspaceSection,RunWorkspaceNavigation,RunWorkspaceHeader,RunInspector}.swift`
- `Sources/HarnessUI/Views/Workflow/{RunJourneyModel,RunJourneyTimeline,RunJourneySummary,RunJourneyDetail,RunJourneyOutputs}.swift`
- `Sources/HarnessUI/Views/NewRun/{NewRunDraft,NewRunSourceSection,NewRunConfiguration,NewRunAttachments}.swift`
- `docs/V2-EXPERIENCE.md`

As demais diferenças que já existiam no checkout antes desta implementação não são apresentadas como mudanças da V2.

## Verificação

Validação local em 26/09/2026, macOS 27.0 e Xcode 27.0. Nenhum teste ou mock novo foi criado.

| Verificação | Resultado observado |
| --- | --- |
| `./script/validate.sh` | **PASS**: lint estrito, 42 XCTest via SwiftPM, 48 testes via Xcode (42 do núcleo e 6 de interface), build universal e assinatura ad hoc |
| Resultado Xcode | **PASS**: 48 aprovados, nenhuma falha ou teste ignorado; `.build/qa/run-Moe3Ko/Harness.xcresult` |
| Ajustes finais de apresentação | **PASS**: lint, novo build universal, assinatura e `git diff --check` após compactar o resumo, reposicionar a ação e acompanhar a seleção no scroll |
| Inspeção no app | **PASS**: jornada de nove etapas em projeto temporário, seleção de etapa futura, dependência visível, abertura de Cenários, retorno preservando seleção, volta à etapa atual, navegação até a nona etapa com rolagem acompanhando a seleção e inspector |
| Aparência e anexos | **PASS**: jornada clara/escura, formulário de tarefa, seleção local pelo painel nativo, Quick Look e remoção do anexo do rascunho |
| Ciclo completo com executor real | **NOT-RUN** nesta validação da V2 |
| VoiceOver, contraste aumentado e execução em macOS 15/26 | **NOT-RUN** nesta validação da V2 |

Os testes de interface existentes cobrem criação, navegação, Escape, persistência, janelas e estados de validação. A jornada nova foi conferida manualmente. Os últimos ajustes de apresentação receberam build, lint e inspeção; a suíte completa não foi repetida depois desses ajustes. O roteiro abaixo reúne também os cenários que ainda precisam de conferência manual.

### Roteiro manual

1. Abrir a visão geral sem projetos; adicionar um repositório e preparar uma tarefa.
2. Criar uma tarefa com critérios; abrir a jornada e conferir a etapa atual, a autorização do contexto e os resultados disponíveis.
3. Clicar em etapas anteriores e futuras; conferir dependências, estados e resultados; usar “Etapa anterior”, “Ver próxima etapa” e “Voltar à etapa atual”.
4. Revisar diagnóstico e plano; verificar as aprovações e acompanhar o avanço enquanto a tarefa executa. Explorar outra etapa e confirmar que a seleção continua nela.
5. Abrir reprodução e conferência pelos botões do cabeçalho; registrar cenários e verificar as observações na jornada. Conferir alterações, validações, achados e entrega pelos botões de cada etapa.
6. Enviar orientação e pausar durante a execução; conferir bloqueios, pendências e resultados desatualizados sem confundi-los com etapas concluídas.
7. Redimensionar a janela para conferir jornada lateral e faixa horizontal; alternar inspector, modo foco e barra lateral recolhida.
8. Buscar tarefa, projeto e fluxo por clique; filtrar e ordenar tarefas, inclusive arquivadas e buscas sem resultado.
9. Conferir anexos, remoção e Quick Look; ler fonte conectada, atualizar a seleção remota e desvincular a fonte mantendo o texto visível.
10. Abrir duas tarefas em janelas separadas e conferir a worktree correspondente ao foco. Fechar a principal e reabrir pelo Dock ou barra de menus.
11. Alternar Claro/Escuro/Sistema; conferir contraste aumentado, VoiceOver e os atalhos de apoio, incluindo Enter e Escape na busca.

### Fontes de plataforma

- [Novidades do SwiftUI](https://developer.apple.com/swiftui/whats-new/)
- [Window](https://developer.apple.com/documentation/swiftui/window)
- [Inspector](https://developer.apple.com/documentation/swiftui/view/inspector(ispresented:content:))
- [Quick Look em SwiftUI](https://developer.apple.com/documentation/quicklook/view/quicklookpreview(_:))

## Refinamento de Geral, Fluxos e Nova tarefa — 27/09/2026

### Experiência

- **Geral:** prévias selecionáveis de Sistema, Claro e Escuro; representação da ilha de sessões; acesso direto à central; preferências do dia a dia separadas de execução e limites. A conexão de sessões abre um guia por executor, com os comandos manuais em uma seção própria.
- **Fluxos:** biblioteca com busca e filtros; seleção abre a finalidade, configuração e etapas do fluxo. Cada etapa mostra o que faz e permite navegar pelas dependências. “Usar este fluxo” prepara a nova tarefa com a seleção correspondente; editar é uma ação separada.
- **Nova tarefa:** objetivo e critérios visíveis; contexto e referências expansíveis; escolha visual de executor; prévia das etapas reais do fluxo. O rodapé informa a pendência que impede a criação e oferece uma ação para resolvê-la.

### Decisões e contratos

A implementação mantém SwiftUI, a cena nativa `Settings`, os tokens Fronda e os contratos do coordenador. Não acrescenta dependências, testes ou mocks. Os componentes ficam em `Views/Settings`, `Views/Runbooks` e `Views/NewRun`.

O orçamento inicial da tarefa vem do fluxo selecionado, seguindo o comportamento da CLI. Uma alteração manual fica explícita e é preservada ao trocar de fluxo; “Usar orçamento do fluxo” restaura a herança. A prévia não executa etapas nem altera aprovações.

O editor de fluxo aguarda a confirmação de salvamento e mantém o rascunho quando há falha. Geral também aguarda confirmação, bloqueia novas gravações e a troca de seção durante essa operação e apresenta erros na própria janela. O estado de abertura com o Mac é consultado após a alteração e quando a janela volta a ficar ativa, incluindo autorização pendente no sistema.

Foram preservados a leitura explícita de fontes conectadas, os bloqueios de fonte desatualizada, a seleção de anexos, Quick Look e os identificadores de acessibilidade utilizados pelos testes existentes. Os controles de aparência também conservam o seletor nativo.

### Arquivos desta rodada

- `Sources/HarnessUI/App/HarnessApp.swift`: tamanho inicial da janela de ajustes.
- `Sources/HarnessUI/Views/SettingsView.swift`: composição e navegação dos ajustes.
- `Sources/HarnessUI/Views/Settings/{GeneralSettingsView,SettingsAppearancePicker,SettingsSessionIsland,SettingsExecutionControls}.swift`: novos componentes de Geral.
- `Sources/HarnessUI/Views/SessionIsland/ExternalSessionSetupView.swift`: guia de conexão por executor, compartilhado com a central.
- `Sources/HarnessUI/Views/RunbooksView.swift`: biblioteca interativa.
- `Sources/HarnessUI/Views/Runbooks/{RunbookDetailView,RunbookStepPreview,RunbookEditorView}.swift`: exploração de etapas e editor extraído.
- `Sources/HarnessUI/Views/NewRunView.swift` e componentes em `Views/NewRun`: formulário, configurações, referências, fonte conectada, executor e prévia do fluxo.
- `Harness.xcodeproj/project.pbxproj`: inclusão dos componentes pelo gerador existente.
- `docs/V2-EXPERIENCE.md`: documentação e roteiro desta rodada.

### Roteiro de conferência

1. Em Geral, comparar as prévias e alternar aparência; sair e voltar para conferir persistência.
2. Abrir “Conectar sessões”, alternar Codex/Claude Code e conferir as instruções. Configurar hooks e permissões reais é uma ação separada de navegar pelo guia.
3. Expandir “Execução e limites” e conferir os limites customizados e os presets de concorrência.
4. Em Fluxos, buscar por nome ou etapa, filtrar só leitura/alterações, selecionar uma etapa e navegar por sua dependência.
5. Usar um fluxo, verificar a seleção no formulário e consultar as etapas. Alterar o orçamento, trocar de fluxo e restaurar o orçamento herdado.
6. Preencher contexto, recolher e reabrir; anexar e remover referências; conferir as mensagens de pendência e criar a tarefa.
7. Conferir temas claro/escuro, janela compacta e VoiceOver. Validar autorizações reais de notificações e início de sessão quando desejar ativar esses recursos.

### Resultado observado desta rodada

| Verificação | Resultado |
| --- | --- |
| `./script/validate.sh` | **PASS**: lint, 42 XCTest via SwiftPM, 48 testes via Xcode, build universal e assinatura ad hoc |
| Resultado Xcode | **PASS**: 48 aprovados, nenhuma falha ou teste ignorado; `.build/qa/run-c0DJxL/Harness.xcresult` |
| Ajustes finais | **PASS**: lint, build universal, assinatura e `git diff --check` após limitar a altura da biblioteca compacta, retirar seleção implícita de ícones decorativos e esclarecer a origem do orçamento |
| Geral | **PASS**: cartões de aparência com seleção e confirmação de salvamento em workspace temporário; claro/escuro; abertura do guia de conexão e troca de executor; expansão dos limites |
| Fluxos | **PASS**: busca, filtro somente leitura, seleção de etapas, navegação por dependência e abertura da nova tarefa com o fluxo correspondente; seleção acessível única na biblioteca |
| Nova tarefa | **PASS**: claro/escuro, pendência de objetivo/projeto, prévia clicável, preservação do contexto recolhido, ajuste do orçamento para 33.000 e restauração para 32.000 tokens |
| Janela compacta | **NOT-RUN**: o ajuste compilou; a tentativa de redimensionar pela automação nativa não produziu a largura necessária para conferir esse estado |
| Hooks, notificações e início de sessão reais | **NOT-RUN**: nenhuma integração ou permissão foi ativada durante a conferência |
| VoiceOver e ciclo com executor real | **NOT-RUN** nesta rodada |

A suíte completa antecede somente os ajustes finais de apresentação e acessibilidade listados acima. Esses ajustes receberam novo build, lint e inspeção; a suíte completa não foi repetida depois deles. O workspace temporário usado na conferência foi encerrado e removido pelo script existente. O pacote atual está em `dist/Fronda.app`.

## Segunda rodada: Visão geral, Fluxos e Nova tarefa — 27/09/2026

### Experiência

- **Visão geral:** objetivo e projeto dividem uma área de preparação. Os fluxos frequentes abrem a tarefa preservando o texto e o projeto escolhido. O percurso Preparar → Executar → Conferir explica cada fase por clique. Quando existem tarefas, decisões e trabalhos em andamento aparecem primeiro. O ambiente fica recolhido; sua atualização consulta novamente os executores.
- **Fluxos:** cabeçalhos compactos mantêm o nome, a revisão, a configuração e as ações visíveis. Uma sequência de etapas conectadas controla um painel com finalidade, condições, dependências navegáveis, critérios e validações. A biblioteca vira uma faixa horizontal em larguras menores.
- **Nova tarefa:** projeto, fluxo e executor ficam no topo. O objetivo ocupa a área principal; a lateral apresenta etapas nomeadas e o percurso completo em um popover. Autonomia, escopo e orçamento têm um popover próprio. Escolhas manuais de executor, autonomia e orçamento são preservadas ao trocar de fluxo, com ações para restaurar o padrão.

### Decisões e arquivos

As telas usam SwiftUI e os tokens adaptativos existentes. A prévia segue `orderedSteps()` e apresenta erros do grafo antes da criação; clicar em uma etapa apenas muda a explicação. Fonte conectada, invalidação por alteração da seleção, envio, anexos e Quick Look mantêm seus contratos. Nenhuma dependência, teste ou mock foi criado.

- `Views/CommandCenterView.swift` e `Views/CommandCenter/{CommandIntentCard,WorkspaceStatusCards}.swift`: composição, preparação e ambiente.
- Novos `Views/CommandCenter/{CommandJourneyGuide,CommandWorkQueue}.swift`: percurso explicativo e lista de trabalho real.
- `Views/RunbooksView.swift` e `Views/Runbooks/{RunbookDetailView,RunbookStepPreview}.swift`: biblioteca e navegação entre etapas.
- Novos `Views/Runbooks/{RunbookStepDescription,RunbookStepDetail}.swift`: apresentação e detalhe da etapa.
- `Views/NewRunView.swift` e componentes de `Views/NewRun`: formulário e prévia; novo `NewRunOptions.swift` para as opções.
- `Harness.xcodeproj/project.pbxproj`: inclusão dos novos componentes pelo gerador existente.

Os caminhos de Views acima são relativos a `Sources/HarnessUI`. As seções anteriores registram rodadas anteriores, com seus próprios resultados de validação.

### Conferência manual desta rodada

- **PASS:** Visão geral vazia e com tarefa aguardando decisão; clique abre o workspace correspondente; percurso explicativo muda por seleção. Identificadores `home.*` continuam acessíveis.
- **PASS:** Fluxos com nove etapas, seleção da última etapa e navegação por dependência. Em aproximadamente 1001 × 733 pontos, a biblioteca fica horizontal e a seleção acompanha a rolagem; cabeçalho e ações permanecem visíveis.
- **PASS:** Nova tarefa em claro/escuro, abertura pelo fluxo escolhido, percurso completo e seleção da última etapa sem perder o formulário.
- **PASS:** seleção de Claude Code, troca de fluxo mantendo o executor e restauração do padrão Codex. Autonomia Planejar e orçamento de 33.000 tokens continuam após a troca de fluxo. A atualização de valor e personalização foi unificada em uma atribuição do rascunho para corrigir a seleção que retornava ao executor anterior.
- **NOT-RUN:** VoiceOver, contraste aumentado, fluxo conectado a GitHub/Jira e ciclo completo com executor real nesta rodada. Quick Look e anexos mantêm o código de comportamento conferido na rodada anterior.

As verificações com tarefa e tema claro usaram os seis workspaces temporários preparados pelo script existente. Nenhuma tarefa real foi enviada a um executor. Os workspaces temporários foram encerrados e removidos pelo mesmo script.

### Validação final

| Verificação | Resultado |
| --- | --- |
| `./script/validate.sh` após as correções finais | **PASS:** lint estrito, 42 testes SwiftPM, 48 testes Xcode, build universal e assinatura ad hoc |
| `.build/qa/run-f5pvAG/Harness.xcresult` | **PASS:** 48 aprovados, zero falhas, zero ignorados |
| `git diff --check` | **PASS** |
| Pacote entregue | `dist/Fronda.app`, reaberto no workspace normal, sem dados de QA |
| Preservação da etapa ao alternar largura | Estado movido para o pai das duas composições. Build e suíte **PASS**; reconferência visual da transição **NOT-RUN** após esse último ajuste, pois os itens de redimensionamento do menu nativo retornaram identificadores inválidos na automação |

Para a conferência manual restante: selecionar a etapa 9 em Fluxos, reduzir e restaurar a largura e confirmar que a mesma etapa permanece selecionada. Conferir também VoiceOver, contraste aumentado e uma tarefa real com fonte conectada e executor autenticado.

## Terceira rodada: Projetos, ajustes e editor de fluxos — 27/09/2026

### Experiência

- **Projetos:** busca por nome, caminho e branch; filtros por índice pendente e existência de tarefas; contagens reais e estados vazios com ações. O estado READY do índice aparece como “Índice disponível”.
- **Detalhe do projeto:** resumos clicáveis de Índice, Validações e Tarefas substituem a página longa. O cabeçalho oferece nova tarefa com projeto selecionado, ajustes e Finder. A busca apresenta carregamento, erro e resultados; as tarefas abrem o workspace correspondente. “Revisar comandos” abre diretamente a seção correta dos ajustes.
- **Ajustes do projeto:** navegação por Acesso, Permissões, Contexto e Comandos; rascunho com Cancelar e Salvar alterações; status fixo de operação e erros. Os pesos do contexto têm nomes em português e os campos explicam seu efeito.
- **Editor de fluxos:** Configuração, Etapas e Validações têm áreas próprias. Uma lista mantém o caminho visível enquanto o painel edita uma etapa. Dependências são escolhidas pelo nome; conexões que criariam ciclos ficam indisponíveis. Critérios, caminhos, executor e condições continuam editáveis. Ao salvar, a biblioteca seleciona o fluxo e apresenta sua nova revisão.
- **Comandos:** projetos e fluxos compartilham o editor com lista compacta, um comando selecionado, prévia literal e aprovação explícita. Alterações de executável, argumentos, timeout ou modo de leitura retiram a aprovação anterior.

### Decisões técnicas

SwiftUI, os tokens adaptativos Fronda e os contratos existentes do coordenador foram preservados. Nenhuma dependência, teste ou mock foi criado. Os componentes foram extraídos conforme as pastas de funcionalidades já adotadas.

Os ajustes armazenam apenas os campos editáveis no rascunho. Antes de salvar, consultam o projeto atual e aplicam o rascunho sobre ele, preservando metadados atualizados pelo coordenador. Uma falha mantém o painel e os dados preenchidos. Renovar acesso usa o painel nativo e preserva o rascunho. A comparação de executores permitidos usa conjunto, evitando alterações aparentes causadas por ordem ou representação opcional.

O editor de etapas usa a validação real de `orderedSteps()`. Uma etapa referenciada não pode ser removida até que suas dependências sejam ajustadas. A prévia de ordem não executa trabalho. O comando selecionado usa binding pelo ID, inclusive durante remoção e troca de seleção, e a invalidação de aprovação ocorre na mesma atribuição que altera o comando.

Resultados de busca antigos são descartados quando mudam projeto, consulta ou data da indexação. “Última indexação” informa a data disponível sem prometer que os arquivos continuam iguais ao índice.

### Arquivos desta rodada

Caminhos abaixo relativos a `Sources/HarnessUI`:

- `Views/ProjectsView.swift`: biblioteca de projetos.
- Novos `Views/Projects/{ProjectPresentation,ProjectLibraryRow,ProjectDetailView,ProjectIndexView,ProjectWorkSections}.swift`: estados, linhas, detalhe, busca e trabalho do projeto.
- `Views/ProjectSettingsView.swift`: navegação, rascunho e operações confirmadas.
- Novos `Views/ProjectSettings/{ProjectSettingsSection,ProjectSettingsDraft,ProjectSettingsAccess,ProjectSettingsPermissions,ProjectSettingsContext}.swift`: seções e campos dos ajustes.
- `Views/RunbooksView.swift` e `Views/Runbooks/RunbookEditorView.swift`: integração e composição do editor.
- Novos `Views/Runbooks/Editor/{RunbookEditorModel,RunbookConfigurationEditor,RunbookStepsEditor,RunbookStepEditor}.swift`: configuração, seleção e edição de etapas.
- Novos `Components/{ValidationCommandsEditor,ValidationCommandFields}.swift`: editor compartilhado de comandos.
- Removido `Components/RunbookValidatorsEditor.swift`, substituído pelo editor compartilhado.
- `Harness.xcodeproj/project.pbxproj`: regenerado para incluir os componentes.
- `docs/V2-EXPERIENCE.md`: registro desta rodada.

### Conferência manual observada

As verificações usaram um projeto descartável criado pelo script de fixtures existente, sem modificar os ajustes de `naza-control` ou executar um provider real.

| Cenário | Resultado |
| --- | --- |
| Biblioteca e detalhe em claro/escuro e janela compacta de aproximadamente 1001 × 733 pontos | **PASS** |
| Busca sem resultado, limpar busca e filtro de índice pendente | **PASS** |
| Busca por conteúdo no projeto temporário | **PASS:** dois arquivos retornados |
| Nova tarefa pelo projeto e abertura de tarefa existente | **PASS:** projeto preselecionado e workspace correto |
| Validações → Revisar comandos | **PASS:** abertura direta de Comandos com seleção acessível exclusiva |
| Aprovar no rascunho e alterar executável | **PASS:** aprovação retirada; cancelamento preserva o comando salvo |
| Campo Jira inválido ao salvar | **PASS:** erro visível e rascunho mantido; cancelamento sem persistir o valor inválido |
| Desativar e reativar o mesmo executor no rascunho | **PASS:** volta ao estado sem alterações |
| Alterar nome de comando e salvar projeto | **PASS:** confirmação, fechamento e detalhe atualizado |
| Dependência que criaria ciclo e remoção de etapa referenciada | **PASS:** conexão indisponível e remoção bloqueada com explicação |
| Remover dependência obrigatória e restaurá-la | **PASS:** erro da estrutura desabilita salvar; restauração recupera validade |
| Criar fluxo, adicionar etapa, critérios, caminhos e comando | **PASS:** salvamento e reabertura preservam dados e dependências |
| Adicionar e remover comando durante edição | **PASS:** seleção continua válida |
| Salvar nova revisão com busca ativa | **PASS:** busca limpa, fluxo salvo selecionado e revisão 2 exibida |
| Editor em tema claro e janela compacta | **PASS:** seleção, campos e ações acessíveis |
| Renovação real de acesso, falha de rede, VoiceOver e contraste aumentado | **NOT-RUN** nesta rodada |
| Ciclo completo com executor real e execução em macOS 15/26 | **NOT-RUN** nesta rodada |

### Validação final desta rodada

A primeira execução de `./script/validate.sh` passou no lint e nos 42 testes SwiftPM. No Xcode, 47 de 48 testes passaram; `testGateStatesAndStaleEvidenceAreVisible` não encontrou o badge STALE depois de rolar até o último comando, com janela de aproximadamente 1000 × 732 pontos. Resultado: `.build/qa/run-EZDI6a/Harness.xcresult`.

O cenário foi reproduzido manualmente na mesma janela: PASS, FAIL e BLOCKED vieram dos comandos reais da fixture; após copiar `Next.swift` para `Greeting.swift`, os resultados mudaram para STALE. O badge estava visível ao retornar ao topo. Isso indica fragilidade da consulta de acessibilidade fora do viewport no teste existente. Nenhum teste foi alterado. A janela foi ampliada pelo menu nativo para repetir a suíte.

A repetição com janela ampla passou sem alterações adicionais no código ou nos testes:

| Verificação | Resultado final |
| --- | --- |
| `./script/validate.sh` | **PASS:** lint estrito, 42 testes SwiftPM, 48 testes Xcode, build universal e assinatura ad hoc |
| `.build/qa/run-8L9wjx/Harness.xcresult` | **PASS:** 48 aprovados, zero falhas e zero ignorados |
| `git diff --check` | **PASS** |
| Conferência manual das telas solicitadas | **PASS:** claro/escuro, janela compacta, navegação, edição, cancelamento e persistência |
| Pacote | `dist/Fronda.app`, reaberto no workspace normal com o painel de `naza-control` |

Os workspaces temporários foram encerrados e removidos pelo script existente. A fragilidade de rolagem do teste em janela compacta permanece documentada; não foi modificada a suíte. Permanecem para conferência manual VoiceOver, contraste aumentado, renovação de acesso, falhas de conexão e uma tarefa completa com executor real. Não houve commit ou push nesta rodada.
