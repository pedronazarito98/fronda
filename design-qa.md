# Design QA — fluxo de Tarefas do Fronda

**final result: blocked**

## Pendências

- **P2 — Repetição efetiva e animação:** o fluxo local foi configurado com duas ramificações, convergência e ciclo de correção. Com autorização do usuário, a execução começou e o mapa exibiu a investigação em andamento. O executor reportou 55.029 tokens, acima do teto inicial de 32.000. O usuário autorizou um teto de 160.000; após a retomada, o consumo reportado alcançou 168.374 e o ciclo foi interrompido na primeira rodada. A verificação local autorizada `git diff --check` passou em execução manual, mas isso não concluiu automaticamente o ciclo. Não houve repetição efetiva observada para comparar com a referência, conferir seu histórico e validar sua animação.
- **P2 — Comparação de estados equivalentes:** a referência mostra uma execução em andamento e um segundo ciclo após falha. As capturas disponíveis mostram dados reais diferentes e o ciclo configurado, porém não iniciado. A comparação estrutural foi feita; a comparação do mesmo estado permanece pendente.

## Evidências

- Referência do mapa: `/Users/pedronazarito/.codex/generated_images/01a19a14-42da-7700-ab3a-c6df2776c311/exec-b68de395-6715-4b93-9749-54b40df23c9b.png` (1584 × 993 px).
- Referências de quadro, etapa, arquivos e conferência: respectivamente, imagens `exec-879c5a09-5652-4942-afe6-c7b883aa7f5f.png`, `exec-7e00acdc-6e90-4b48-a13d-c4ddd0a0d163.png`, `exec-0e5ae998-ebb9-4041-b657-751d50b1ee61.png` e `exec-92818d1c-06c0-4d8a-8d3d-9273d4a01d80.png`, na mesma pasta da referência do mapa.
- Capturas locais persistidas em `output/fronda-loops-grafos-2026-11-01/design-qa/`: `mapa-final.png`, `etapa.png`, `arquivos-markdown.png`, `arquivos-csv.png`, `tarefas-quadro-final.png`, `conferencia-final.png` e `mapa-escuro.png`. As capturas mostram revisão anterior à última correção da contagem e do tamanho dos nós; o aplicativo atualizado foi conferido novamente na janela nativa e comparado junto à referência.
- Janela nativa: 1470 × 923 pontos, densidade Retina 2×; capturas sem sombra 2940 × 1846 px. Para comparação estrutural, foram produzidas versões normalizadas a 1584 × 993 px. A referência do quadro tem 1672 × 941 px; diferenças de proporção e de quantidade de tarefas foram consideradas.
- O grafo ramificado final, com dois planos que dependem da mesma investigação, convergência na implementação e ciclo entre implementação e validação, foi exibido junto à referência em uma mesma saída visual. A captura final desse estado foi exibida, mas não persistida. A execução real autorizada chegou à primeira rodada do ciclo e foi bloqueada pelo teto de tokens; a verificação local manual passou, sem concluir automaticamente o ciclo.
- Áreas focadas revistas: nós, conexões e retorno do ciclo; resumo lateral e botão de abertura; painel de detalhes; tabela Markdown; pendências e links da conferência. As diferenças de dados e estado são limitações, não equivalência.

## Histórico de correções

1. O mapa abria com nós grandes demais; os espaçamentos e a escala inicial foram ajustados. Outra comparação mostrou texto pequeno demais, então a ampliação mínima e a tipografia foram aumentadas, mantendo rolagem e zoom.
2. Um nome longo de etapa era truncado; agora pode ocupar duas linhas.
3. O resumo de progresso faltava na lista lateral; foram incluídos título, projeto, estado e progresso das etapas apresentadas.
4. O detalhe botânico não era carregado como recurso avulso. Passou a usar o carregador de recursos do aplicativo; o mapa ganhou fundo suave, folhas e esquilo aquarelado. O mapa foi inspecionado em claro e escuro.
5. O ciclo usava uma caixa técnica e uma ligação interrompida. Foi trocado por conexão curva, com cor e rótulo diferentes para ciclo não iniciado e repetição registrada; a ligação de entrada passou a chegar ao nó.
6. O botão de abrir tarefa ficava abaixo da dobra no resumo do quadro. Agora permanece fixo no rodapé; as colunas ganharam superfícies que facilitam a leitura.
7. A conferência não apresentava próximos passos ao lado do conteúdo. Foi incluído um painel com links reais para contexto, verificações, achados e entrega.
8. Uma consulta à árvore de acessibilidade com CSV aberto encerrava a cópia do aplicativo. Após investigação da pilha de acessibilidade, foi removida a seleção de texto das células; o CSV abriu com cabeçalhos acessíveis e o modo Fonte mantém a seleção do conteúdo.
9. O resumo em lista divergia da contagem do mapa; ambos agora usam a projeção das etapas. No fluxo ramificado, planos preparados antes da aprovação do contexto apareciam como aprovados ou concluídos; a apresentação foi corrigida para não comunicá-los como trabalho concluído.

## Superfícies e interações

- **Tipografia e layout:** tipografia nativa do macOS, nós e estados identificados, lista e acompanhamento laterais, zoom e rolagem. Número de etapas e estados observados não coincidem com o mockup.
- **Cores e tokens:** cores adaptativas existentes, badges, ícones e texto; a cor não é o único indicador. Foram observados tema claro e escuro, espera e ciclo configurado. Falha e repetição efetivas permanecem pendentes de observação.
- **Imagens:** folhas e esquilo em PNG transparente, carregados pelo bundle, observados sobre os dois temas. O mascote existente permaneceu independente.
- **Conteúdo:** dados, dependências e ações vêm do coordenador local; avaliações e estados não foram inventados para reproduzir a referência.
- **Fluxos observados:** quadro, resumo e abertura; filtros e estado vazio; lista; etapa; menu Consultar; conferência; Markdown com tabela; JSON indentado; CSV e alternância de cabeçalho; fluxo com duas ramificações e ciclo configurado. A árvore de acessibilidade foi consultada após a correção do CSV.
- **Não executado:** VoiceOver real, Reduzir Movimento do sistema, conclusão da execução real de provedor, repetição efetiva, validação XCUITest e assinatura/notarização para distribuição.

## Checklist restante

1. Conferir em uma execução real autorizada a repetição, o motivo apresentado, o histórico e a animação, inclusive com Reduzir Movimento.
2. Registrar uma captura persistida do estado final ramificado e comparar a execução e as demais visões em estados equivalentes aos das referências.
3. Validar VoiceOver e navegação por teclado ponta a ponta no aplicativo nativo.
