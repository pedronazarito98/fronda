# Fronda — loops, grafos e acompanhamento da execução

A navegação atual e a leitura de arquivos estão em [Etapas e arquivos](FRONDA-UX-ETAPAS-E-ARQUIVOS.md). A página Tarefa reúne a antiga Conversa e a visão geral. O mapa e a proposta têm destinos próprios.

Criado em 01/11/2026; atualizado em 02/11/2026. Estado: **implementação nativa concluída; validação com provider real pendente**.

Esta análise cruza conversas anteriores, pesquisas e o código do Fronda. Os estudos visuais são referências de composição, não capturas do app. Após aprovação da sidebar direita e das cores, a implementação foi autorizada e está descrita ao final deste documento.

## Direção recomendada

O Fronda continua sendo o ambiente que organiza uma tarefa, seu contexto, ferramentas, permissões, execução e evidências. O grafo descreve o percurso dessa tarefa. Um loop descreve um trecho que pode se repetir conforme o resultado obtido.

Portanto, uma mesma tarefa pode ter grafo e loop. Não proponho escolher entre “Harness”, “Loop” e “Graph” ao criar trabalho. A pessoa escolhe o objetivo e o fluxo; o Fronda mostra as relações, as repetições e as decisões quando elas importam.

O resultado desejado é conseguir responder, sem acompanhar uma conversa inteira:

- O que está acontecendo agora?
- Quem está fazendo isso: modelo, código ou pessoa?
- Por que esta etapa começou, repetiu ou ficou esperando?
- O que já foi comprovado e o que ainda falta?
- Quando o trabalho vai parar e o que precisa de mim?

## O que recuperamos das conversas

| Conversa | Evidência útil para a decisão |
| --- | --- |
| [Como criar um harness](https://chatgpt.com/c/6ab326ae-1168-83e9-9bdf-fd12fc87a57a) | Você pediu uma UI, depois corrigiu a direção para um app nativo macOS. Também pediu um produto completo e economia de tokens sem perder qualidade e rastreabilidade. |
| [Diferenças entre Harness Loop e Graph Engineering](https://chatgpt.com/c/6ae141d7-cfe4-83e8-990c-70d1afe9140e) | Você pediu uma explicação visual e simples, especialmente sobre o que usa modelo e o que pode ser script. |
| [Branch · Diferenças entre Harness Loop e Graph Engineering](https://chatgpt.com/c/6ae2001c-9404-83e9-9c35-e66ccea9d1cd) | Você relacionou loops com o escritório de agentes e relatou que um diagrama Mermaid não foi visualizado. |
| [Orquestração de agentes](https://chatgpt.com/c/6ae55e09-ccd8-83e9-bd87-07b5188459a9) | Discussão sobre delegação, transferência de contexto, fluxo e diferenças entre controle por código e decisões por modelo. |
| [Agentes E Harness](https://chatgpt.com/c/6ae7cbaf-920c-83e9-a214-b49715d79384) | Artigo anexado “Harness Engineering, Part 4: Architecture and Patterns”, útil para discutir ambiente, estado e padrões de execução. |

Também consultei os chats Codex **Especificar arquitetura do Harness** (`01a0cbec-a6ac-78c2-813f-e4425687acd1`), **Implementar Harness macOS completo** (`01a0cbf7-8af6-7f51-a4aa-80b5ab80437c`) e turnos de **Pesquisar referências de UX para mac** (`01a0e395-962f-7b82-9325-66ff7e8f3ee3`). A continuidade documentada é preservar a experiência nativa, a navegação compartilhada, o split view escolhido pela pessoa e os estados do mascote vinculados ao trabalho real.

As sugestões anteriores de “escritório”, agentes especializados e avaliadores não equivalem a uma arquitetura de Fronda já aprovada. A proposta deste documento é uma síntese nova.

### Direção escolhida nesta conversa

Você escolheu o estudo 2, combinando seu mapa com o acompanhamento de loops do estudo 1 e preservando a experiência nativa. O aprofundamento passa a usar **um mapa principal com acompanhamento contextual do ciclo**. Essa escolha substitui a proposta inicial de alternar entre telas separadas de Acompanhamento e Mapa; não autoriza inferir que o motor de loops já existe.

A [primeira composição combinada](../output/fronda-loops-grafos-2026-11-01/mapa-com-ciclos.png) reuniu mapa e acompanhamento, mas você apontou que ainda não permitia entender imediatamente onde o trabalho estava, por que repetiu e o que faltava. Essa composição não passou pelo critério de clareza.

A [revisão com resumo direto antes do mapa](../output/fronda-loops-grafos-2026-11-01/mapa-resumo-direto.png) tornou as três respostas explícitas. Você gostou do informativo e pediu colocá-lo numa sidebar à direita, usando mais cores para determinar os estados. O alvo visual atual é a [sidebar de acompanhamento com cores semânticas](../output/fronda-loops-grafos-2026-11-01/mapa-sidebar-estados.png). Essa direção foi aprovada; a implementação mantém a sidebar vinculada à execução atual, independente da seleção no mapa.

### Correção de hierarquia após seu feedback

O problema anterior não era falta de informação: atividade, motivo e pendência estavam espalhados entre mapa e inspetor, com “validando”, “ciclo” e contadores genéricos repetidos. Era necessário interpretar o diagrama para reconstruir o estado da tarefa.

A correção mantém três respostas juntas e independentes da seleção de um nó. Inicialmente elas ficaram antes do mapa; após seu novo pedido, passam para a sidebar direita, visíveis sem expandir seções:

| Pergunta | Texto ilustrativo da revisão | Fonte necessária no produto |
| --- | --- | --- |
| Onde está o trabalho? | “Conferindo se o filtro continua selecionado.” | Atividade efetivamente em execução, vinculada à etapa e à tentativa. |
| Por que repetiu? | “Antes, o filtro voltava para ‘Todos’ ao reabrir a página.” | Evidência da verificação anterior e decisão registrada de repetir. |
| O que falta? | “Confirmar que a seleção foi mantida. Depois, você revisa a entrega.” | Critérios ainda não comprovados, demais dependências obrigatórias e próxima decisão humana. |

O mapa explica esse resumo e permite explorar relações. A sidebar de acompanhamento começa aberta em largura suficiente; o histórico permanece sob demanda. Modelo/código/pessoa e limite de ciclos continuam acessíveis como informação secundária, sem competir com o comportamento que está sendo verificado.

O cenário da nova imagem foi simplificado para uma correção com uma checagem pendente e revisão humana. Não representa uma projeção parcial da tarefa anterior com o ramo de acessibilidade omitido. Na execução real, o resumo precisa incluir também pendências obrigatórias fora do trecho visível; só pode afirmar “depois, você revisa” quando as outras dependências estiverem satisfeitas.

“A página foi reaberta” e “voltou para Todos” são dados ilustrativos desta imagem. O app só deve afirmar esses fatos se houver observação registrada. Quando a ferramenta não detalhar sua atividade, usar “Executando a validação do filtro” e indicar que o detalhe não está disponível. Quando não houver motivo registrado, dizer isso em vez de inventar uma explicação. O resumo descreve eventos e evidências, não raciocínio privado do modelo.

### Sidebar direita e cores — revisão de 02/11

A sidebar mantém, nesta ordem: **Agora**, **Por que repetiu** e **O que falta**. “Agora” descreve a ação concreta com maior peso tipográfico. O motivo cita a evidência anterior; o trabalho restante descreve a comprovação necessária e a próxima decisão humana. Histórico e limites ficam recolhidos abaixo dessas respostas.

O centro volta a dar espaço ao mapa. O nó azul em execução se relaciona visualmente ao indicador azul de “Agora” na sidebar. Não é necessário ler as setas para descobrir a atividade atual, nem selecionar um nó para descobrir o motivo da repetição.

| Cor semântica proposta | Ícone e estado | Regra |
| --- | --- | --- |
| Azul | Indicador de atividade + “Em execução” | Só atividade confirmada pelo motor; não significa item selecionado. |
| Verde | Check + resultado comprovado | Evidência aprovada daquela etapa. Uma reprodução comprovada não significa correção validada ou entrega concluída. |
| Âmbar | Exclamação/mão + pendência ou necessidade de atenção | Critério ainda não atendido, decisão solicitada, limite ou estagnação. Na sidebar, o texto identifica quando se trata de falha passada. |
| Cinza | Relógio + motivo da espera | Dependência, fila ou revisão ainda não iniciada. Não usar o mesmo texto para espera e execução pausada. |
| Vermelho | X + falha que interrompeu o trabalho | Falha operacional impeditiva, sem confundir com retorno esperado de um ciclo de correção. |

Cor aparece no indicador, contorno e fundo suavemente tonalizado do nó, sempre acompanhada por texto e forma. A marca e os controles gerais preservam o verde Fronda. Seleção recebe contorno neutro e identificação acessível próprios, para não fazer um nó concluído parecer em execução.

“Alteração aplicada” permanece neutra até a verificação comprovar o comportamento. Cancelado, pulado, histórico e estado antigo também usam rótulos explícitos; não são comprimidos artificialmente nos cinco estados da legenda.

As cores verde/âmbar/vermelho podem reaproveitar os tokens semânticos existentes. O azul de execução precisará de uma variante adaptativa coerente com o tema, distinta da seleção; não há esse token dedicado hoje em `FrondaTheme`. Esta proposta não introduziu cores no código. Contraste, diferenciação sem cor e aparência escura permanecem por validar.

O resumo da sidebar continua descrevendo a execução atual ao explorar outro nó ou ciclo histórico. O detalhe selecionado abre sob demanda, com título e revisão próprios, preservando as respostas atuais e sem criar uma segunda sidebar permanente. Em largura ampla, propor uma divisória nativa ajustável e controle de mostrar/ocultar; preservar a escolha da pessoa.

Esta escolha substitui a proposta anterior de manter o acompanhamento fechado por padrão. Dentro de um workspace já dividido, a implementação deve verificar espaço disponível e oferecer a mesma informação como painel temporário quando outra coluna tornaria o mapa ilegível. Não esconder silenciosamente o acesso ao acompanhamento; manter o controle nomeado e a seleção ao voltar.

### Alcance da pesquisa

Usei as ferramentas de listagem e leitura de conversas, com conteúdo dos turnos relevantes, e buscas nas Pages acessíveis. Consultei históricos ativos e arquivados; a busca em Pages não trouxe uma pesquisa pertinente adicional. Não foi uma varredura exaustiva de todo o acervo Codex/ChatGPT/Work, nem uma leitura dos históricos brutos na pasta raiz. Os resultados não distinguem toda a origem visual Chat/Work, então não atribuo cobertura integral separada a cada superfície.

As capturas visuais utilizadas são arquivos históricos do repositório. O app não foi aberto nesta análise. Credenciais, arquivos de autenticação, sessões, logs, bancos locais e caches de conversas não foram consultados.

## Conceitos aplicados ao produto

| Conceito | Responsabilidade no Fronda | Apresentação ao usuário |
| --- | --- | --- |
| Harness | Controlar contexto, ferramentas, políticas, execução, estado e evidências | O próprio ambiente Fronda |
| Grafo de execução | Explicitar dependências, caminhos condicionais e junções | Mapa do fluxo |
| Loop de melhoria | Corrigir, verificar e decidir se outra iteração é justificável | Ciclo de correção |
| Orquestração | Escolher trabalho elegível, aplicar limites e registrar transições | Atividade e motivo da próxima etapa |
| Relações de contexto | Relacionar arquivos, símbolos e referências | Relações do contexto |
| Rastreabilidade | Ligar critérios, alterações, verificações e decisões | Evidências da entrega |

Essa distinção é coerente com a separação entre progressão, recuperação limitada e ambiente de execução proposta em [Towards Agentic Cloud Engineering](https://arxiv.org/abs/2609.00050). É um preprint e uma referência conceitual; não demonstra que sua implementação específica seja a melhor para o Fronda.

O [guia de loops da Anthropic](https://claude.com/resources/articles/getting-started-with-loops) diferencia ciclos por turno, objetivo, tempo e eventos, considerando gatilhos e condições de parada. Para o Fronda, proponho priorizar o ciclo por objetivo verificável. Rotinas recorrentes merecem identidade própria: “monitoramento ativo, aguardando evento” não significa modelo trabalhando continuamente.

A [documentação de grafos do LangGraph](https://docs.langchain.com/oss/python/langgraph/graph-api) ajuda a separar estado, nós e transições. Usar esse vocabulário não exige adicionar LangGraph, Python, Node ou outro runtime ao app Swift.

## O que o Fronda já faz

| Capacidade observada no código | Consequência |
| --- | --- |
| `RunbookStep` possui `dependencies`, `condition`, critérios e configuração de provider/modelo | Já há um grafo de dependências no domínio. |
| `orderedSteps()` ordena topologicamente e rejeita ciclos | O modelo atual é um DAG: não aceita retornos arbitrários entre etapas. |
| Executor percorre as etapas com `for` e `await executeStep` | Etapas de uma mesma run rodam sequencialmente, mesmo que haja ramos independentes. |
| Concorrência e limites existem entre runs | Não equivale a paralelismo de nós dentro da mesma tarefa. |
| `retryStep` invalida a etapa e seus descendentes | Há base para repetir trabalho com rastreabilidade. |
| `retries` limita tentativas de implementação com falha/interrupção | Não é um loop de melhoria após uma avaliação negativa. |
| Revisão e finalização consultam evidências da revisão vigente | Já existe um contrato importante para evitar conclusão sem comprovação. |
| UI transforma etapas e dependências em jornada | Boa base para o mapa, embora a apresentação ainda assuma uma etapa atual. |

Referências principais: [Runbook.swift](../Sources/HarnessDomain/Runbook.swift), [RunExecution.swift](../Sources/HarnessCore/RunExecution.swift), [StepExecution.swift](../Sources/HarnessCore/StepExecution.swift), [ValidationReview.swift](../Sources/HarnessCore/ValidationReview.swift) e [RunJourneyModel.swift](../Sources/HarnessUI/Views/Workflow/RunJourneyModel.swift).

A SPEC já descreve auto-reparo limitado e parada por repetição de falha, mas não encontrei essa política completa no executor examinado. A promessa documental não deve ser apresentada como recurso operacional existente.

## Proposta de experiência

### Mapa e acompanhamento no mesmo lugar

Dentro de **Plano**, reunir acompanhamento e mapa. A sidebar direita explica atividade atual, motivo da repetição e trabalho ainda necessário. O mapa central apresenta as relações; o detalhe contextual, aberto por seleção, aprofunda o item escolhido. Remover o seletor Acompanhamento/Mapa e os títulos repetidos “Mapa do trabalho” e “Mapa do fluxo”. Uma apresentação em lista continua disponível como alternativa acessível do mesmo conteúdo.

Hoje parte da jornada fica em Mais → Visão geral, separada da lista técnica do plano. Essa evolução aproxima os dois conteúdos sem criar uma nova área principal de navegação. Conversa, Alterações, Contexto, Validação e Evidências continuam sendo destinos da tarefa.

O mapa é gerado pelo plano. Selecionar um nó abre seu detalhe; a ação correspondente abre a validação, alteração ou evidência existente. Não é necessário desenhar conexões manualmente para iniciar uma tarefa.

O agrupamento do loop também é selecionável. Ao selecioná-lo, o mesmo inspetor aprofunda as evidências do ciclo, seus critérios, limites e histórico; não é necessário abri-lo para entender a situação atual. Ao selecionar uma etapa interna, o inspetor mostra o responsável, o resultado e sua evidência. Não abrir simultaneamente um painel de etapa e outro de loop.

### Composição aprofundada

| Área | Conteúdo e comportamento |
| --- | --- |
| Toolbar da janela | Navegação, abas e busca existentes, com o controle de detalhes. Preservar foco e comportamento dos painéis. |
| Cabeçalho da tarefa | Título e ações gerais. Pausa aparece uma única vez e tem efeito sobre a tarefa inteira. |
| Sidebar de acompanhamento | Atividade concreta em destaque; “Por que repetiu” e “O que falta” logo abaixo. Aberta à direita em largura suficiente, continua mostrando o presente quando se examina o passado. |
| Mapa | Percurso central; nós com título, responsável e estado; conexões reais; organização estável. Azul identifica execução, sem repetir todos os textos do resumo. |
| Grupo repetível | Título “Corrigir e verificar”, ciclo atual, nós internos e condição de saída. O grupo não ganha um novo conjunto de nós a cada passagem. |
| Detalhe do ciclo | Evidências, revisões, critérios e decisões completas, aberto sob demanda. Sem outra cópia do fluxograma. |
| Critérios e limites | Disclosure secundário com regra de saída, teto vigente e alcance permitido; edição separada da visualização. |

A primeira captura combinada mostrava o histórico aberto. Na revisão atual, o acompanhamento começa aberto e o histórico recolhido. A escolha posterior da pessoa pode ser preservada sem tornar as três respostas dependentes de uma seleção no mapa.

### Seleção, histórico e atualização

| Interação | Resultado esperado |
| --- | --- |
| Clicar no título ou contorno do grupo | Selecionar o ciclo e abrir seu acompanhamento no único detalhe contextual. |
| Clicar em “Validar” | Trocar o detalhe para a etapa; mostrar resultado disponível e “Abrir validação”. |
| Abrir “Ciclo 1” no histórico | Mostrar resultado, revisão e evidências daquele ciclo, identificados como históricos; o mapa permanece na execução atual. |
| Uma nova iteração começar durante a leitura do histórico | Preservar seleção, foco e rolagem; atualizar a linha de atividade e oferecer “Voltar ao ciclo atual”. |
| Usar “Ir para atividade atual” | Selecionar a atividade atual e enquadrá-la somente se estiver fora da área visível. |
| Abrir validação ou alterações | Navegar para a seção existente e guardar seleção/enquadramento para a volta ao Plano. |
| Fechar o detalhe ou mudar de aba | Alterar somente apresentação; não pausar nem cancelar a execução. |

A seleção é estado da interface; atividade e resultado são estados da execução. Selecionar um ciclo antigo não reexecuta o fluxo e não troca silenciosamente o mapa para o passado. Um replay completo do grafo exigiria uma ação e identificação próprias, fora deste aprofundamento.

O inspetor não deve roubar o foco ao receber resultados. O mapa mantém as posições durante um ciclo; alterações de estrutura acontecem apenas quando muda o plano. Ao mudar de ciclo, as mesmas etapas passam a representar a nova iteração e os resultados anteriores ficam acessíveis no histórico.

### Estados que a composição precisa explicar

| Situação | Mapa | Acompanhamento e ação |
| --- | --- | --- |
| Validação em andamento | Somente o nó ativo indica execução | Critério em conferência e “Abrir validação”. |
| Validação termina com pendências | Resultado pendente, distinto de aprovação | Explicar a evidência que faltou; ainda não animar retorno. |
| Decisão de repetir registrada | Breve destaque no retorno e atualização do número do ciclo | “Repetindo porque o filtro ainda não foi preservado”. |
| Critérios do loop comprovados | Saída do grupo habilitada | “Critérios atendidos”; a revisão aguarda também suas demais dependências. |
| Limite atingido | Grupo em atenção, sem indicador de trabalho | Explicar o que falta e abrir a revisão do limite/abordagem; não reiniciar automaticamente. |
| Sem progresso | Mesmo grupo e posição preservados | Mostrar o resultado repetido e pedir orientação concreta. |
| Falta de conexão/estado antigo | Última posição preservada, sem afirmar atividade atual | “Último estado recebido”; controles dependentes de conexão indisponíveis. |

“Etapa terminada”, “critérios atendidos” e “entrega encerrada” continuam sendo fatos diferentes. Critério comprovado em uma revisão anterior não pode ser contado como atual se a alteração seguinte o invalidou.

### Pausa e retomada: semântica conferida no código

O rótulo escolhido é **Pausar execução**. Hoje, `stopRun` cancela o trabalho e solicita interrupção dos processos; não aguarda a etapa terminar. Retomar recoloca etapas pendentes na fila, reconcilia o estado e inicia outra tentativa do provider quando necessário. Não promete restaurar uma sessão de modelo viva.

Texto de ajuda proposto: “Interrompe a tentativa atual. Ao retomar, o Fronda confere o estado do trabalho e inicia uma nova tentativa quando necessário.” Cancelar permanece no menu de ações da tarefa.

O código registra o estado lógico de pausa antes de encerrar os processos. Para mostrar “Solicitando pausa…” e depois parada confirmada, a implementação precisará expor também a confirmação do encerramento; apenas ler `RunState.paused` não comprova que todos os processos já pararam. Referências: [RunExecution.swift](../Sources/HarnessCore/RunExecution.swift), [ProcessRunner.swift](../Sources/HarnessInfrastructure/ProcessRunner.swift) e [ProviderGateway.swift](../Sources/HarnessProviders/ProviderGateway.swift).

“Pausar após esta etapa” fica fora deste contrato visual. Preparar nova tentativa de uma etapa também é uma ação distinta: pode invalidar resultados dependentes e não deve ser acionada por explorar o histórico.

### Quem executa cada parte

| Rótulo | Exemplos | Informação no detalhe |
| --- | --- | --- |
| Modelo | Investigar, propor implementação, revisar semanticamente | Papel, provider/modelo, contexto entregue e resultado |
| Código | Rodar verificador, calcular condição de saída, executar ferramenta | Comando/ferramenta, entrada, resultado e evidência |
| Pessoa | Aprovar contexto, resolver ambiguidade, revisar entrega | Decisão solicitada, consequência e ações |

Esses rótulos descrevem o trabalho selecionado. Uma etapa de modelo pode chamar ferramentas de código; o detalhe mostra a atividade corrente sem criar uma falsa separação absoluta. Papel (“revisor”) e modelo são campos diferentes. Não é necessário um modelo em cada nó, nem vários agentes para existir um grafo.

### Loop visível e compreensível

Exemplo de acompanhamento: **“Conferindo se o filtro continua selecionado”**, seguido do comportamento observado anteriormente e da comprovação ainda necessária. “Ciclo 2 de até 4” aparece como informação secundária. “1 critério pendente” sozinho não substitui a descrição do que falta.

O grupo “Corrigir e verificar” reúne a implementação, a validação e a decisão de continuar. A seta de retorno ganha destaque apenas quando o runtime escolhe repetir. O histórico registra, para cada ciclo, a revisão de entrada, o que mudou, o resultado e por que houve outra tentativa.

Mostrar separadamente a quantidade de critérios satisfeitos e o limite de ciclos. “2 de até 4” não significa metade do objetivo concluída. Um ciclo pode terminar com pendências: isso não deve receber o mesmo tratamento visual de uma entrega aprovada.

Não inferir progresso do texto do agente. Critérios determinísticos são avaliados por código quando possível; avaliações semânticas usam um modelo quando necessário; decisões humanas continuam explícitas. O runtime aplica orçamento, condições e autorização, inclusive quando um modelo recomenda continuar.

### Grafo fiel à execução

No mapa, diferenciar o plano previsto do caminho percorrido. Exibir estados “não iniciada”, “aguarda X”, “em execução”, “precisa de você”, “concluída”, “não aplicável” e “resultado desatualizado”. Uma condição não percorrida não deve aparecer como falha.

Ramos só aparecem simultaneamente ativos quando houver execução concorrente real. Com o motor atual, um ramo independente pode estar disponível, mas aguardando sua vez. Selecionar uma dependência deve explicar o bloqueio em linguagem de tarefa, sem exigir conhecer IDs internos.

O grafo de execução não deve ser misturado em uma única tela com o grafo de arquivos e símbolos. É mais útil ligar os dois pelo inspetor: “esta etapa usou estes arquivos e produziu estas evidências”.

### Quadro, ilha e mascote

O quadro mantém a fase macro da tarefa. Durante o ciclo, o card recebe uma linha de atividade; não deve saltar repetidamente entre Implementar e Revisar. Uma fase só muda quando a transição correspondente for registrada.

A central de sessões e o mascote usam a mesma projeção: “ciclo 2 · validando”, “aguarda sua decisão” ou “sem atualização recente”. Decisão e impedimento continuam tendo prioridade sobre animação de execução. Não animar sessões externas como se o Fronda conhecesse seu grafo interno; só mostrar o que a integração informa.

A metáfora de escritório pode inspirar papéis e passagens de trabalho. Para esta proposta, a informação central fica na tarefa e no mapa nativos. O mascote pode apontar uma pendência e abrir seu detalhe, sem exigir uma nova cena 3D.

### Movimento, tema e acessibilidade

Reaproveitar os tokens adaptativos de [FrondaTheme.swift](../Sources/HarnessUI/Components/FrondaTheme.swift), a toolbar compartilhada e o split view existente. Movimento pontual sinaliza uma mudança de estado; não é uma animação contínua de todo o grafo.

Oferecer uma lista equivalente para VoiceOver e janelas estreitas. Estado combina ícone, texto e cor. Respeitar Reduzir Movimento e Reduzir Transparência. O foco deve continuar no nó selecionado durante atualizações; resultados novos não devem reorganizar o mapa inteiro.

O estudo representa a composição em largura ampla com acompanhamento aberto. A sidebar persistente no workspace é uma evolução solicitada nesta exploração, não uma capacidade já implementada. Respeitar os contextos existentes ao adaptar: inspetor lateral na janela própria e detalhes em popover nas abas, especialmente quando já há dois painéis. Não criar automaticamente uma terceira coluna ilegível. Com pouco espaço, usar uma apresentação temporária nomeada, preservando seleção e acesso ao acompanhamento.

Navegação por teclado deve alcançar nós e grupos em uma ordem lógica estável; Return abre o detalhe e Escape fecha a apresentação transitória, sem alterar a execução. VoiceOver anuncia nome, responsável, estado e dependências pelos títulos. Ajustes de zoom não devem ser necessários para entender a tarefa na apresentação em lista.

## Contrato proposto para o motor

Manter o DAG externo e adicionar um grupo repetível delimitado. Permitir ciclos arbitrários em `dependencies` quebraria pressupostos atuais de ordenação, invalidação e conclusão.

| Elemento proposto | Papel |
| --- | --- |
| `LoopPolicy` | Etapas participantes, critério de saída, máximo de ciclos, orçamento, tempo e política de estagnação |
| `LoopIteration` | Identidade da iteração, revisões, tentativas, verificações e evidências associadas |
| `LoopDecision` | Continuar, concluir, pedir orientação ou interromper, sempre com motivo e evidências |
| `LoopState` | Estado interno do ciclo, preservando `RunState` como estado geral da tarefa |

Separar definição estável do nó, execução daquela etapa, tentativa técnica e iteração de melhoria. Um retry de processo não deve incrementar silenciosamente o ciclo de qualidade. Uma bifurcação de abordagem continua tendo identidade própria.

Antes de iniciar a próxima iteração, persistir a decisão e verificar se suas evidências ainda correspondem à revisão atual. A retomada precisa distinguir resultado comprovado, execução interrompida e efeito externo de resultado desconhecido. Não repetir publicação ou outra operação com efeito externo apenas porque o app reiniciou.

Para uma checagem determinística, continuar exige: critério pendente, correção permitida no escopo, orçamento disponível, ausência de decisão humana pendente e progresso plausível. Uma falha repetida com a mesma assinatura e sem mudança relevante deve levar à orientação, com tolerância configurável para casos transitórios.

Resultados e interrupções distintos: objetivo comprovado; limite atingido; sem progresso; cancelado; falha operacional. Aguardar decisão é uma suspensão retomável, não um estado terminal. Atingir um limite encerra a política de execução vigente; continuar exige uma decisão explícita sobre o novo escopo ou limite. “Pronto para revisão” não equivale a publicação ou entrega encerrada.

Novas associações como `iterationID` devem ser opcionais/versionadas para runs antigas. Evidência anterior permanece no histórico, mas só a evidência válida para a revisão corrente pode satisfazer a entrega. A projeção de comparação precisa preservar ciclos anteriores; a atual substituição de resultados por validador não basta para isso.

O paralelismo entre nós é uma mudança adicional: exige dependências satisfeitas, política de junção, orçamento agregado e isolamento de escrita. Contexto separado de agente não cria worktrees separadas. Investigações e revisões somente leitura são candidatas mais simples; escritas concorrentes exigem posse de arquivos ou worktrees com reconciliação explícita.

### Economia de tokens e contexto

Reaproveitar Context Compiler, artefatos e ledger existentes. Entregar ao próximo ciclo as evidências da falha, o diff relevante e critérios pendentes, evitando reenviar conversas inteiras. Invalidar pacotes quando sua revisão mudar.

Não chamar modelo para posicionar nós, animar a interface, contar critérios, aplicar teto ou executar uma condição determinística. Essas são responsabilidades do código. Revisores adicionais devem ter justificativa de qualidade, não existir em todo nó por padrão.

Uso reportado, estimado e indisponível precisam permanecer distinguíveis. Um teto verificado entre chamadas não é garantia de corte exato dentro de uma chamada: limites fortes dependem das capacidades do provider e de interrupção. Não prometer custo monetário preciso sem preços e telemetria suficientes.

## Ordem de trabalho para um resultado completo

Esta é uma ordem de dependências técnicas, não uma proposta de fragmentar a entrega em várias versões incompletas:

1. Fixar o contrato de estados, critérios e evidências; desenhar sucesso, repetição, estagnação, limite, pausa e recuperação.
2. Projetar o DAG já existente no mapa e integrar a jornada ao Plano, mantendo a semântica atual.
3. Implementar o grupo de correção e verificação com política, persistência, histórico e retomada.
4. Propagar a mesma informação para quadro, cabeçalho, ilha, mascote e detalhes de evidência.
5. Acrescentar execução paralela somente com contratos de isolamento e junção completos.

Os quatro primeiros itens formam um recorte coerente para tornar loops e grafos úteis no Fronda. O quinto não deve ser simulado na apresentação.

## Estudos visuais

As três imagens foram geradas a partir das capturas existentes do Fronda, incluindo o tema escuro. Elas estão na [pasta dos estudos](../output/fronda-loops-grafos-2026-11-01/). A numeração corresponde à ordem em que apareceram no chat.

- [Estudo 1](../output/fronda-loops-grafos-2026-11-01/estudo-01.png)
- [Estudo 2](../output/fronda-loops-grafos-2026-11-01/estudo-02.png)
- [Estudo 3](../output/fronda-loops-grafos-2026-11-01/estudo-03.png)

Após sua escolha, acrescentei o [mapa com acompanhamento de ciclos](../output/fronda-loops-grafos-2026-11-01/mapa-com-ciclos.png). Seu feedback posterior rejeitou a clareza dessa composição. A [revisão com resumo direto](../output/fronda-loops-grafos-2026-11-01/mapa-resumo-direto.png) forneceu o informativo que você pediu para mover à direita. A [sidebar com cores de estado](../output/fronda-loops-grafos-2026-11-01/mapa-sidebar-estados.png) é o alvo visual aprovado; os estudos anteriores permanecem como registro.

São estudos de hierarquia e composição, não uma especificação literal de todos os textos e controles. Refinamentos necessários antes de construir: evitar check verde para ciclo encerrado com falhas; remover sugestões de arrastar entre fases como substituto de execução; explicitar a condição de saída do ciclo; reduzir cartões aninhados e ações repetidas; ajustar “pausar após esta etapa” ao comportamento que o runtime realmente garantir.

## O que validar manualmente na próxima etapa

- Em poucos segundos, identificar atividade atual, responsável, critério pendente e motivo da próxima ação.
- Distinguir uma etapa terminada de uma validação aprovada e de uma tarefa concluída.
- Seguir o retorno de um ciclo e abrir a evidência que motivou a repetição.
- Entender limite atingido e estagnação sem confundi-los com sucesso.
- Comparar duas iterações sem perder a relação com revisões e alterações.
- Ver uma dependência bloqueada e um ramo disponível sem inferir paralelismo inexistente.
- Conferir que pausa, cancelamento, retomada e reinício preservam a identidade e não duplicam operações.
- Conferir teclado, VoiceOver, janelas estreitas, claro/escuro e movimento reduzido.
- Selecionar grupo, etapa e ciclo histórico sem duplicar painéis ou misturar passado e presente.
- Receber uma nova iteração enquanto se lê uma evidência anterior, preservando foco e seleção.
- Conferir o mesmo detalhe na janela própria, em aba e no workspace já dividido.
- Sem ler o mapa ou abrir detalhes, identificar atividade concreta, falha anterior e resultado ainda necessário.
- Conferir que o resumo considera dependências obrigatórias fora da área visível e não inventa fatos quando falta telemetria.
- Identificar execução pelo azul sem confundi-la com seleção; distinguir alteração aplicada de comportamento comprovado.
- Conferir a sidebar aberta/oculta e a apresentação compacta; validar cores no tema escuro, contraste aumentado e sem depender de percepção de cor.

## Implementação autorizada em 02/11

- **Mapa nativo na aba Plano:** dependências reais do DAG, condições, grupo do ciclo, zoom, ajuste, navegação por teclado e lista em painéis estreitos. A seleção é neutra e independente do estado de execução. A proposta e os controles anteriores permanecem em “Proposta e etapas”.
- **Acompanhamento à direita:** Agora, Por que repetiu e O que falta, com histórico, critérios e limites recolhíveis. Em painéis estreitos, resumo compacto e painel de acompanhamento sob demanda. A desconexão indica o último estado recebido.
- **Ciclo opt-in:** configuração no fluxo e no editor do plano. Apenas Implementar → Validar, com uma única validação obrigatória diretamente dependente da implementação. Tarefas e fluxos antigos continuam sem ciclo automático até edição explícita.
- **Motor e persistência:** cada iteração mantém revisões, tentativas, resultados e evidências. Nova correção recebe a decisão anterior e as falhas observadas. Aprovações, escopo, validações obrigatórias e revisão independente continuam exigidos. Desativar e reativar o mesmo grupo preserva seu histórico e limite absoluto.
- **Limites:** até dez iterações configuráveis, tolerância de estagnação, tempo ativo e orçamento existente. Tempo e orçamento são conferidos entre etapas; uma chamada em andamento pode terminar depois do teto. Pausar execução interrompe a tentativa atual, preservando o estado para retomada.
- **Resumo consistente:** quadro, ilha e mascote identificam os ciclos e direcionam o acompanhamento para o mapa. Iterações não viram porcentagem de conclusão.

Não há dependências novas nem testes ou mocks novos. O DAG continua com execução sequencial dentro da tarefa; conexões independentes não prometem paralelismo. O primeiro grupo repetível não inclui revisão humana, publicação, entrega nem extensões com efeitos externos.

### Onde agir quando aparece “Sua vez”

Na Conversa, a ação fica acima do relato. Em **Plano → Mapa**, ela fica na sidebar direita, junto de **Agora**; no painel estreito, o botão fica no resumo, ao lado de **Acompanhar**. O texto acompanha o estado da tarefa e independe do nó que você está inspecionando.

| Situação | Onde agir | O que o botão faz |
| --- | --- | --- |
| Contexto aguardando autorização | **Revisar contexto** | Abre os arquivos e o destino do envio. A autorização é um clique separado. |
| Proposta pronta | **Revisar proposta** | Abre a proposta escrita em Plano. A aprovação da implementação fica nessa revisão. |
| Evidência de cenário faltando | **Registrar reprodução** ou **Registrar resultado do cenário** | Abre o formulário no momento correto; o registro depende de salvar. |
| Falta aprovar um comando | **Conferir validações → Revisar comando no projeto…** | Seleciona o comando exato. Se veio apenas do fluxo, oferece uma cópia para revisar antes de salvar no projeto. |
| Falta uma verificação obrigatória no ciclo | **Conferir validações → Cadastrar verificação no projeto…** | Abre um rascunho. Depois de atender à pendência, **Retomar etapas** volta a colocar a tarefa na fila. |
| Ciclo esgotado ou sem progresso | **Revisar plano do ciclo** | Abre o editor existente com limites, etapas e orçamento. |
| Operação externa pendente | **Conferir operação** | Abre a ficha com destino e conteúdo. Um resultado incerto pode ser consultado sem repetir a operação. |

O coordenador distingue uma espera por configuração de outra por resultado. A ação para retomar uma rodada com validação pendente requer resultados observados para os comandos obrigatórios na iteração e na revisão atuais. Um resultado de falha é evidência para o motor decidir se cabe uma nova correção; não equivale a aprovação.

### Como experimentar

1. Em Fluxos, edite um fluxo com escrita e etapas Implementar → Validar. Em Configuração, ative “Corrigir e verificar em ciclos” e salve. Também é possível ativar no plano de uma tarefa parada.
2. Cadastre pelo menos uma validação obrigatória no projeto ou fluxo e mantenha seu comando autorizado.
3. Crie a tarefa, revise contexto e proposta e aprove pelos controles existentes.
4. Na aba Plano, acompanhe o mapa e a sidebar. A rodada seguinte só aparece após uma falha observada, com motivo registrado e limite disponível.
5. Selecione outra etapa e confira que Agora continua mostrando a execução corrente. “Ir para agora” restaura o acompanhamento da etapa atual.
6. Confira interrupção/retomada, falha repetida, teto, tema escuro e modo dividido antes de usar em trabalho longo.

### Validação desta implementação

- `script/build_and_run.sh --build-only`: compilação universal e empacotamento concluídos.
- `script/validate.sh --unit-only`: lint estrito e 42 testes existentes passaram. Relatório: `.build/qa/run-8nLeLr/unit.xml`.
- `git diff --check` e verificação da assinatura ad hoc: passaram. Não foi feita distribuição nem notarização.
- Conferência no app nativo em uma base isolada: tema escuro e claro, sidebar aberta/oculta, seleção sem alterar o acompanhamento, grupo selecionado, painel compacto no workspace dividido, navegação para validações, edição e persistência do limite de 3 para 4 ciclos, retorno da rolagem para a etapa atual.
- Ações contextuais: em uma segunda base isolada, “Revisar contexto” abriu Contexto pela Conversa e pela sidebar. O editor de Validação abriu o comando solicitado com a aprovação desmarcada; cancelar não habilitou o comando. “Revisar contexto” também apareceu no resumo e no acompanhamento compactos. Após a navegação, a tarefa permanecia em WAITING_USER, sem aprovação e com zero tentativas. O lint passou e os 42 testes existentes passaram novamente (`.build/qa/run-OKjxi9/unit.xml`).
- O tipo de dado antigo foi exercitado pela suíte existente. Não foram criados testes, arquivos de teste ou mocks.
- Não executados: XCUITest, ciclo completo com Codex/Claude, repetição com falha real seguida de correção, esgotamento/estagnação em provider, interrupção/reinício de um loop em voo e publicação real. Esses cenários permanecem no roteiro manual acima. A conferência local preparou contexto, mas não autorizou envio a um provider.

A primeira passagem encontrou uma regressão na validação manual: runs paradas ficavam pausadas em vez de recalcular o resultado parcial. A correção distingue cancelamento/interrupção de validação manual; a suíte completa passou depois. A revisão estática também corrigiu a atestação após commit sem mudança de conteúdo e o estado da iteração em bloqueios, mas esses caminhos novos ainda precisam de execução real com loop.

### Arquivos de implementação

- `Harness.xcodeproj/project.pbxproj`
- `Sources/HarnessCore/ArtifactIntake.swift`
- `Sources/HarnessCore/DeliveryWorkflow.swift`
- `Sources/HarnessCore/EvidenceEngine.swift`
- `Sources/HarnessCore/ExtensionExecution.swift`
- `Sources/HarnessCore/LoopEvaluation.swift`
- `Sources/HarnessCore/LoopExecution.swift`
- `Sources/HarnessCore/RunCoordinator.swift`
- `Sources/HarnessCore/RunExecution.swift`
- `Sources/HarnessCore/StepExecution.swift`
- `Sources/HarnessCore/ValidationReview.swift`
- `Sources/HarnessDomain/Artifacts.swift`
- `Sources/HarnessDomain/Loop.swift`
- `Sources/HarnessDomain/Run.swift`
- `Sources/HarnessDomain/Runbook.swift`
- `Sources/HarnessUI/Components/FrondaTheme.swift`
- `Sources/HarnessUI/Views/Mascot/MascotActivity.swift`
- `Sources/HarnessUI/Views/RunPlanView.swift`
- `Sources/HarnessUI/Views/RunWorkspace.swift`
- `Sources/HarnessUI/Views/Runbooks/Editor/LoopPolicyEditor.swift`
- `Sources/HarnessUI/Views/Runbooks/Editor/RunbookConfigurationEditor.swift`
- `Sources/HarnessUI/Views/Runbooks/RunbookDetailView.swift`
- `Sources/HarnessUI/Views/Runs/RunBoardCard.swift`
- `Sources/HarnessUI/Views/Runs/RunBoardStage.swift`
- `Sources/HarnessUI/Views/SessionIsland/IslandSessionRows.swift`
- `Sources/HarnessUI/Views/Workflow/PlanEditorView.swift`
- `Sources/HarnessUI/Views/Workflow/RunFlowAppearance.swift`
- `Sources/HarnessUI/Views/Workflow/RunFlowMap.swift`
- `Sources/HarnessUI/Views/Workflow/RunFlowMapEdges.swift`
- `Sources/HarnessUI/Views/Workflow/RunFlowMapLayout.swift`
- `Sources/HarnessUI/Views/Workflow/RunFlowMapList.swift`
- `Sources/HarnessUI/Views/Workflow/RunFlowMapModel.swift`
- `Sources/HarnessUI/Views/Workflow/RunFlowMapNode.swift`
- `Sources/HarnessUI/Views/Workflow/RunFollowupCriteria.swift`
- `Sources/HarnessUI/Views/Workflow/RunFollowupEvidence.swift`
- `Sources/HarnessUI/Views/Workflow/RunFollowupHistory.swift`
- `Sources/HarnessUI/Views/Workflow/RunFollowupLoopProjection.swift`
- `Sources/HarnessUI/Views/Workflow/RunFollowupModel.swift`
- `Sources/HarnessUI/Views/Workflow/RunFollowupSidebar.swift`
- `Sources/HarnessUI/Views/Workflow/RunJourneyModel.swift`
- `Sources/HarnessUI/Views/Workflow/RunPlanDetailsView.swift`
- `Sources/HarnessUI/Views/Workspace/RunWorkspaceHeader.swift`
- `Sources/HarnessUI/Components/ValidationCommandsEditor.swift`
- `Sources/HarnessUI/Views/CommandCenter/CommandWorkQueue.swift`
- `Sources/HarnessUI/Views/CommandCenter/HomeWorkContent.swift`
- `Sources/HarnessUI/Views/DecisionsView.swift`
- `Sources/HarnessUI/Views/MenuBarView.swift`
- `Sources/HarnessUI/Views/Navigation/RememberScrollPosition.swift`
- `Sources/HarnessUI/Views/ProjectSettingsView.swift`
- `Sources/HarnessUI/Views/Projects/ProjectWorkSections.swift`
- `Sources/HarnessUI/Views/ReviewView.swift`
- `Sources/HarnessUI/Views/Runs/RunDisplay.swift`
- `Sources/HarnessUI/Views/Runs/RunRow.swift`
- `Sources/HarnessUI/Views/ScenarioEvidenceView.swift`
- `Sources/HarnessUI/Views/ValidationView.swift`
- `Sources/HarnessUI/Views/Workspace/RunActionSheet.swift`
- `Sources/HarnessUI/Views/Workspace/RunTaskHomeView.swift`
- `Sources/HarnessUI/Views/Workspace/RunUserAction.swift`
