# Fluxo de tarefas e diário

O Harness mantém a `Run` como unidade auditável. `CardWorkflow` é uma extensão opcional: registros anteriores continuam decodificando sem migração destrutiva. As fases exibidas são derivadas do plano; o estado operacional continua em `RunState`.

## Fluxo

1. Escolher projeto, fonte, critérios e fluxo de trabalho.
2. Preparar worktree e contexto local; conferir os executores de cada etapa.
3. Autorizar o contexto para investigação em modo de leitura.
4. Para bugs, registrar a reprodução antes da implementação.
5. O provider produz diagnóstico e proposta concreta; o usuário aprova a implementação.
6. Executar implementação, catálogo de validação e conferência dos cenários.
7. Produzir parecer independente em tentativa separada, sem ferramentas de escrita.
8. Resolver achados, conferir critérios e aprovar a revisão humana.
9. Preparar e autorizar separadamente commit, push e PR em rascunho.
10. Consultar o merge no GitHub; consolidar o diário e liberar somente uma worktree limpa, no HEAD entregue.

Investigações sem escrita podem ser consolidadas após atingir READY, sem PR e sem remover o checkout original.

## Requisitos por tipo

| Tipo | Exigência |
| --- | --- |
| Feature | Critérios, validação, rastreabilidade e revisão atuais. |
| Bug | Reprodução observada antes da implementação e conferência posterior dos mesmos cenários. |
| Interface | Observação visual em PASS, com imagem ou vídeo, no snapshot vigente. |
| Investigação | Diagnóstico e revisão, respeitando o modo de leitura. |

Os runbooks padrão usam essas etapas como requisitos obrigatórios. Fluxos personalizados anteriores, sem `workKind`, mantêm seu contrato original. Revisões editadas pelo usuário e cópias de runbooks em runs antigas são preservadas; apenas padrões intactos da versão 1 são atualizados.

## Evidência e mídia

Um cenário registra nome, esperado, observado, ambiente, critérios, resultado, instante e snapshot. PASS em uma reprodução significa que o problema foi observado; PASS na conferência significa que o comportamento esperado foi observado.

A captura pode ser manual ou executada por uma extensão selecionada para reprodução/conferência. MCPs e comandos devolvem artefatos ao Harness; o provider registra o cenário ligado a esses artefatos, com origem distinta da observação humana. Sem capacidade disponível ou observação suficiente, a etapa permanece pendente. Consulte [Extensões](EXTENSIONS.md) para configurar o contrato.

PNG, JPEG, HEIC, MP4 e MOV são aceitos até 100 MB. A mídia fica no armazenamento local por hash, fora da worktree, desde o rascunho. O acesso verifica a integridade; a exportação de mídia exige seleção explícita. Arquivos privados e links simbólicos são bloqueados. Artefatos liberados pelo usuário podem ser lidos pelo provider: imagens e frames de vídeo com timestamp. A análise de um frame não implica análise do vídeo completo.

A autorização também compara o snapshot atual com o contexto preparado; mudanças exigem recompilação antes do envio ao provider. Verificações posteriores se tornam obsoletas quando o snapshot muda. O diário é uma projeção das runs e suas evidências; `workflow.json` e as mídias selecionadas complementam o pacote exportado. O diário não cria outra fonte de estado.

## Publicação e recuperação

- O Core bloqueia commit, push e PR sem READY, validações obrigatórias e revisões no snapshot atual. Uma proposta pode ser preparada pela API antes disso, mas não executada.
- O commit preserva os hooks do repositório. O Harness compara o conteúdo antes do staging e após os hooks; somente conteúdo idêntico e worktree limpa permitem manter as evidências, com evento explícito de atestação. Mudanças exigem revalidação.
- O push exige worktree limpa. O PR usa a branch da tarefa, uma base explícita e é criado como rascunho.
- Resultados remotos incertos são consultados por marcador, sem repetir a escrita. O PR e o HEAD recuperados alimentam o diário.
- O merge é consultado na API do GitHub e precisa corresponder ao HEAD enviado. A remoção exige HEAD local igual ao integrado, sem arquivos adicionais, inclusive ignorados. Não é usado `--force`.
- A intenção de limpeza é persistida antes da remoção, permitindo concluir o registro se houver interrupção após remover a worktree.
- Comandos concorrentes de uma mesma run são serializados; mudanças de política do projeto aguardam essas operações. A persistência continua usando as transações e o controle de sequência existentes.

## Interface

Caixa de entrada prioriza tarefas aguardando decisão. Cada linha mostra etapa e próxima ação. Novas tarefas usam quatro áreas principais e uma trilha selecionável de etapas; contexto, plano, revisão, validação e tokens continuam acessíveis. Runs antigas mantêm a navegação anterior.

O diário tem busca, filtro por projeto e registros consolidados. A entrega possui campos próprios para PR e mantém a prévia por operação. O editor de fluxos permite executor/modelo por etapa; a seleção aparece na revisão de contexto, e o consumo permanece vinculado à tentativa.

## Validação da entrega

Executar `./script/validate.sh`: lint, XCTest existente, XCUITest existente, build do app e verificação de assinatura ad hoc. Nenhum teste novo foi criado. O preparador existente de XCUITest explicita seu fluxo personalizado sem provider para preservar os cenários anteriores.

Validações manuais relevantes:

- Criar bug, registrar reprodução, aprovar proposta e repetir o cenário após a correção.
- Criar tarefa de interface, anexar mídia, visualizar e exportar antes do merge.
- Alterar código após conferir um cenário e observar a invalidação.
- Trocar provider ou editar plano e conferir a nova aprovação.
- Executar duas tarefas e tentar comandos concorrentes na mesma run.
- Conferir hooks que alteram arquivos, antes de autorizar o push.
- Conferir PR/merge com integração real e impedir limpeza diante de arquivos ou commits adicionais.
- Fechar/reabrir o app, alternar claro/escuro e usar teclado/VoiceOver.

Publicação remota e captura automatizada não são inferidas a partir de build ou testes locais.

## Arquivos desta implementação

- `Harness.xcodeproj/project.pbxproj`
- `Sources/HarnessCore/DeliveryWorkflow.swift`
- `Sources/HarnessCore/EvidenceEngine.swift`
- `Sources/HarnessCore/ExternalActions.swift`
- `Sources/HarnessCore/OutboxReconciliation.swift`
- `Sources/HarnessCore/RunCoordinator.swift`
- `Sources/HarnessCore/RunExecution.swift`
- `Sources/HarnessCore/SourceImport.swift`
- `Sources/HarnessCore/StepExecution.swift`
- `Sources/HarnessCore/ToolBroker.swift`
- `Sources/HarnessCore/ValidationReview.swift`
- `Sources/HarnessCore/WorkflowExecution.swift`
- `Sources/HarnessDomain/Artifacts.swift`
- `Sources/HarnessDomain/Protocol.swift`
- `Sources/HarnessDomain/Run.swift`
- `Sources/HarnessDomain/Runbook.swift`
- `Sources/HarnessDomain/Workflow.swift`
- `Sources/HarnessInfrastructure/ContextFirewall.swift`
- `Sources/HarnessInfrastructure/GitDelivery.swift`
- `Sources/HarnessProviders/ClaudeSession.swift`
- `Sources/HarnessProviders/CodexSession.swift`
- `Sources/HarnessUI/Stores/AppStore.swift`
- `Sources/HarnessUI/Views/CommandCenterView.swift`
- `Sources/HarnessUI/Views/ContentView.swift`
- `Sources/HarnessUI/Views/ContextView.swift`
- `Sources/HarnessUI/Views/DecisionsView.swift`
- `Sources/HarnessUI/Views/DeliveryStatusView.swift`
- `Sources/HarnessUI/Views/DiaryView.swift`
- `Sources/HarnessUI/Views/EvidenceExportView.swift`
- `Sources/HarnessUI/Views/EvidenceView.swift`
- `Sources/HarnessUI/Views/NewRunView.swift`
- `Sources/HarnessUI/Views/PublicationView.swift`
- `Sources/HarnessUI/Views/RunPlanView.swift`
- `Sources/HarnessUI/Views/RunWorkspace.swift`
- `Sources/HarnessUI/Views/RunbooksView.swift`
- `Sources/HarnessUI/Views/RunsView.swift`
- `Sources/HarnessUI/Views/ScenarioEvidenceView.swift`
- `Sources/HarnessUI/Views/SidebarView.swift`
- `Sources/HarnessUI/Views/WorkflowOverview.swift`
- `docs/CARD-WORKFLOW.md`
- `script/ui_test_fixtures.py`

## Evidência observada em 24/09/2026

- `./script/validate.sh`: lint PASS, 42 XCTest via SwiftPM PASS, 48 testes no Xcode (42 unitários + 6 XCUITest) PASS, build universal e assinatura ad hoc PASS.
- Resultado Xcode: `.build/qa/run-7tHJux/Harness.xcresult`, zero falhas e zero testes ignorados.
- App aberto com dados isolados, usando este repositório em modo de leitura: navegação por etapas, contexto, diário e persistência observados.
- API real: cenário salvo como NOT_RUN, exportação com `workflow.json` e hashes SHA-256 conferidos; conferência posterior sem plano aprovado e encerramento prematuro recusados.
- Não houve execução de provider nesse cenário manual, publicação GitHub, merge remoto ou automação de navegador. A demonstração não foi registrada como entrega funcional concluída.

- Checagem final do contexto obsoleto: autorização recusada com SNAPSHOT_STALE, nenhuma tentativa de provider criada. Após essa correção, lint e 42 XCTest foram repetidos com PASS e o pacote foi recompilado.
