# Acompanhar uma tarefa e ler seus arquivos

A pergunta que organiza a tarefa é “o que está acontecendo agora e o que posso conferir?”. O ponto de partida reúne as etapas e a próxima decisão. O mapa explica as dependências e os ciclos. Arquivos reúne o material que a pessoa pode abrir. O usuário pode circular pelos três sem sair da tarefa.

## O que encontramos no Fronda

| Situação observada antes da mudança | Consequência para quem usa | Decisão aplicada |
| --- | --- | --- |
| Havia cinco abas visíveis e seis destinos no menu Mais. Conversa, Visão geral e Plano explicavam partes da mesma execução. | Era preciso conhecer os nomes das telas para reconstruir o andamento. | Uma página de tarefa reúne objetivo, ação pendente, etapas, conferências e resultado. Mapa e Arquivos têm entradas diretas. Consultar agrupa as ferramentas especializadas. |
| Clicar no nó do mapa selecionava a etapa. Um segundo controle abria um detalhe que privilegiava resultado e descrição do plano. | O nome da etapa dizia o que ela deveria fazer. Encontrar o que aconteceu dentro dela exigia interpretar a atividade da tarefa inteira. | Uma ativação deliberada da etapa abre seu detalhe. O coordenador associa eventos novos à etapa e, quando aplicável, à tentativa e ao ciclo. A tela reúne ações observadas, horários e resultados. |
| O conteúdo do pacote era uma cópia preparada. Alguns botões abriam o caminho da pasta no aplicativo padrão. | A pessoa podia perder seu lugar e ler uma revisão diferente daquela usada pelo executor. | A ação identifica a origem. “Ler cópia” mostra o texto do contexto, “Ler atual” abre a pasta de trabalho e a evidência abre sua cópia preservada. |
| Uma cor podia representar seleção, andamento ou resultado, dependendo da tela. | Era difícil distinguir “estou olhando para isso” de “isto está acontecendo”. | Os estados usam texto e símbolo. Azul representa execução, âmbar pede atenção, vermelho indica falha e verde distingue conferências positivas. Cinza marca espera. Violeta identifica material de referência ou ciclo, sem indicar sucesso. |

## Referências e aplicação

- O GitHub Actions liga a escolha de um item do grafo ao detalhe da execução e apresenta a etapa com falha junto do registro correspondente. No Fronda, a ficha de uma etapa pode ser aberta pela lista e pelo mapa. [GitHub Actions](https://docs.github.com/en/actions/how-tos/monitor-workflows/use-workflow-run-logs)
- O relatório de build do Xcode Cloud agrupa as causas de falha e os artefatos por ação. Essa associação orientou a separação entre o registro atribuído à etapa e os resultados que pertencem à tarefa como um todo. [Xcode Cloud](https://developer.apple.com/documentation/xcode/resolving-common-configuration-and-build-issues)
- O VS Code oferece leitura renderizada e fonte para Markdown. O GitHub apresenta CSV e TSV como dados tabulares. O leitor do Fronda reaproveita o renderizador SwiftUI de Markdown e oferece fonte, JSON indentado e tabelas locais. [VS Code](https://code.visualstudio.com/docs/languages/markdown) · [GitHub](https://docs.github.com/en/repositories/working-with-files/using-files/working-with-non-code-files#rendering-csv-and-tsv-data)

As observações da plataforma vieram do código do Fronda. As referências externas vieram da documentação dos produtos. A organização da navegação é uma decisão de design a validar com usuários.

## Onde conferir

1. Abra uma tarefa. “Sua vez” leva à ação pendente. Em “Etapas da tarefa”, selecione uma linha para abrir seu registro. O mapa abre a mesma ficha.
2. Em uma etapa de executor, compare as tentativas e o horário das ações. Em uma etapa humana, confira a solicitação e a decisão registrada. Dados antigos podem preservar a tentativa sem discriminar os eventos daquela etapa.
3. Em Arquivos, use “Ler cópia” para conferir um trecho de contexto. “Ler atual” exibe o estado do arquivo no disco naquele momento.
4. Use “Abrir arquivo…” no menu Arquivo ou pressione ⌘O para ler um documento local, inclusive sem tarefa aberta. No leitor, alterne entre Leitura e Fonte. CSV e TSV permitem escolher se a primeira linha é cabeçalho.
5. Em painel estreito, confira se é possível abrir uma etapa, voltar à tarefa e localizar Arquivos pelo nome. Ative a aparência escura e verifique se ícones e rótulos continuam diferenciando trabalho em andamento de espera e falha.

## Implementação

- Entrada, navegação e próxima decisão em [RunWorkspace](../Sources/HarnessUI/Views/RunWorkspace.swift), [página da tarefa](../Sources/HarnessUI/Views/Workspace/RunTaskHomeView.swift) e [navegação](../Sources/HarnessUI/Views/Workspace/RunWorkspaceNavigation.swift).
- Atribuição e consulta de atividade em [StepEventScope](../Sources/HarnessCore/StepEventScope.swift), [RunCoordinator](../Sources/HarnessCore/RunCoordinator.swift), [EventStore](../Sources/HarnessInfrastructure/EventStore.swift) e [atividade da etapa](../Sources/HarnessUI/Views/Workflow/RunStepActivity.swift).
- Biblioteca da tarefa em [RunFilesView](../Sources/HarnessUI/Views/Files/RunFilesView.swift). Abertura, formatação, paginação e limites em [FileReader](../Sources/HarnessUI/Components/FileReader).
- Aparência nativa em [FrondaBadge](../Sources/HarnessUI/Components/FrondaBadge.swift) e [FrondaTheme](../Sources/HarnessUI/Components/FrondaTheme.swift).

## Conferência local

Na interface do macOS, a linha de contexto abriu os horários de preparação da pasta e do pacote. Um clique no nó de investigação abriu a ficha correspondente, ainda sem atividade. Também foi exercitada uma checagem não aprovada. O nó ficou bloqueado e a ficha registrou a solicitação e o motivo do bloqueio, com um botão para abrir Validação. O contador do percurso considera a aprovação pendente antes de contar a etapa como concluída.

Em um projeto Git temporário, uma verificação local de quatro segundos expôs a etapa Validar como ativa durante o processo, enquanto o contexto continuou aguardando aprovação. A consulta à etapa registrou o início e, depois, o resultado com código zero. Esse percurso verificou o coordenador e a projeção de estado. O percurso com um provedor real continua pendente de conferência.

O leitor exibiu no app uma tabela Markdown, um JSON indentado e um CSV de três colunas com vírgula e quebra de linha dentro de células. A mesma janela permitiu alternar entre leitura e fonte. O menu Arquivo abriu um CSV externo e a biblioteca abriu uma evidência JSON verificada pelo hash. O leitor limita arquivos textuais a 512 KiB. Para conteúdo que excede os limites da apresentação formatada, mas cabe nesse limite de leitura, oferece a fonte.

O lint e os 42 testes existentes do SwiftPM passaram. A compilação universal contém arm64 e x86_64. A tentativa de dois XCUITests de navegação em uma cópia isolada expirou ao habilitar o modo de automação do macOS, antes do início dos casos. A navegação, a ficha e o leitor foram conferidos diretamente no aplicativo. VoiceOver e uma sessão real com Codex ou Claude ainda requerem validação manual.
