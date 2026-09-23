# Implementação e inventário

## Decisões técnicas

Swift 6, SwiftUI e macOS 15+. O projeto tem targets nativos Xcode para domínio, infraestrutura, providers, core, IPC, serviço, CLI e app, além da biblioteca C Tree-sitter. O gerador usa somente Python padrão. SwiftPM oferece uma segunda entrada de build; o pacote `.app` é produzido pelo script Xcode.

O core é um actor proprietário das transações, da fila e das políticas. A UI usa projeções observáveis; a CLI usa o mesmo protocolo XPC. Cada raiz de dados possui um único coordenador, lock de processo e Mach service. Os clientes são validados por UID, assinatura e localização; em distribuição assinada também por Team ID/identificador.

O Runner usa `posix_spawn`, evitando a normalização de argumentos Unicode observada no protótipo com Foundation Process. Pipes são drenados independentemente; grupos de processo permitem interromper descendentes. Validações não usam shell implícito.

A persistência combina projeções atuais, eventos append-only, deltas e snapshots. O replay aplica deltas desde o checkpoint e nunca executa comandos. Artefatos são redigidos e identificados por hash. O índice é escrito em lotes na FTS5; definições, imports e chamadas usam Tree-sitter para Swift, Python, Go, TS/TSX e JS/JSX. Demais linguagens mantêm busca lexical.

## Superfícies implementadas

| Requisitos | Implementação |
|---|---|
| RF-01–05 | Composer com fontes, anexos/OCR/PDF, projetos, 12 runbooks, editor de DAG/condições/retries/gates versionados, Command Center e palette. Fontes remotas dependem de conexão configurada. |
| RF-06–09 | Indexação por hash/lotes, símbolos/imports/chamadas, associação de testes por nome, histórico Git recente, ranking configurável, pack com hash/proveniência, pins/exclusões/travas, grafo navegável e payload por tentativa. |
| RF-10–13 | Adapters Codex/Claude, streaming, capacidade/autenticação, filas e limites por projeto/provider, worktrees com base/branch/lease, pausa/cancelamento e retomada por novas tentativas. Claude não foi validado por decisão do usuário. |
| RF-14–16 | Steering em run/hunk, edição de plano, retry localizado no DAG, skip justificado, troca de provider, fork, comparação, eventos e replay com artefatos. |
| RF-17–20 | Diff textual nativo com números de linha, modos unificado/lado a lado, comentários/steering, Scope Guard, comandos vetorizados, resultados ligados a snapshot, revisão independente e confirmação humana. |
| RF-21–23 | READY derivado de gates literais/revisão/critérios/escopo, exportação com prévia, opção de metadados, manifesto e vínculos, propostas de publicação, ledger acumulado com cache/modelo quando reportados, aviso/interrupção de orçamento e comparação reproduzível de payload. |
| RF-24 | Leitura GitHub/Jira e escrita por outbox com prévia/identidade/endpoint/digest, Keychain e OAuth configurável, reconciliação sem repetir operação. Jira inclui campo de aceite por projeto, extração ADF e anexos selecionados com limites e hash. Integrações reais ainda não validadas. |
| RF-25–27 | MenuBarExtra, notificações com deep link, Settings, aparência, atalhos, múltiplas janelas, acesso renovável à pasta, login opt-in, diagnóstico e CLI compartilhada. VoiceOver completo/notificações/múltiplos monitores ainda não validados. |

A tabela descreve o código existente, não substitui os cenários de aceite observados. O [QA](QA.md) é a referência para afirmar PASS.

## Invariantes aplicadas

- Escritas de arquivos exigem plano aprovado, worktree exclusiva, path contido, escopo e trava. Conteúdo suspeito é rejeitado antes da escrita.
- Alterações sensíveis geram proposta; recusa não cria exceção permanente.
- Gates exigem o mesmo snapshot **e o mesmo comando configurado**. Mudanças no catálogo/política invalidam a revisão; mudanças nos arquivos invalidam validações dependentes.
- READY exige todos os gates obrigatórios, revisão independente e confirmação dos critérios no snapshot, arquivos rastreados, ausência de achados abertos/riscos aceitos, etapas obrigatórias concluídas, aprovação do plano/contexto e códigos de término observados. Um skip condicional só é aceito quando sua condição não se aplica.
- Revisão independente não pode escrever nem disparar validadores mutáveis pelo broker.
- Edição não transporta alterações locais não commitadas do checkout original.
- Repetições simultâneas do mesmo request ID compartilham a operação em andamento; respostas concluídas permanecem idempotentes.
- O snapshot inclui objetos e modos do index Git. Commit/push explícitos preservam hooks do repositório; preparação não executa hooks de checkout.
- Resultados incertos de publicação ficam UNKNOWN; nova tentativa automática é proibida. Prévia vincula conta, endpoint, corpo, revisão e digest.
- Providers sem autenticação/capacidade e projetos que exigem isolamento forte não avançam indevidamente.
- Atualização distribuída exige assinatura/Team ID/identificador/versão e Gatekeeper; builds ad hoc não são tratados como distribuição confiável.

## Verificação e pontos restantes

O comando `script/validate.sh` integra lint estrito (`swift-format` do Xcode), XCTest via SwiftPM e Xcode, XCUITest no app nativo, empacotamento e verificação ad hoc. Os targets `HarnessTests` e `HarnessUITests` são gerados junto com os nove targets de produto. As fixtures usam repositórios Git, processos e o coordenador reais, sem mocks e sem contas remotas. Resultados executados e limites de cobertura ficam no [QA](QA.md).

Ainda exigem validação externa ou manual: Claude autenticado; OAuth/API reais de GitHub e Jira; perda de resposta de escrita remota; Developer ID/notarização/atualização assinada; VoiceOver, notificações, menu bar, múltiplos monitores e medição de responsividade/50 mil arquivos com Instruments. Screenshots enviam OCR, não pixels; associação de testes é heurística; não há feed de atualização ou limpeza automática de histórico.

## Arquivos

Abaixo estão os arquivos próprios criados nesta implementação. `Vendor/CTreeSitter` contém código de terceiros e licenças identificados pelo manifesto; `.build`, `dist` e `.qa` são saídas locais ignoradas pelo Git.

```text
.codex/environments/environment.toml
.gitignore
Harness.xcodeproj/project.pbxproj
Harness.xcodeproj/xcshareddata/xcschemes/Harness.xcscheme
Package.swift
README.md
Resources/Info.plist
Sources/CSQLite/module.modulemap
Sources/CSQLite/shim.h
Sources/HarnessCLI/CLIMain.swift
Sources/HarnessCLI/MCPHost.swift
Sources/HarnessCore/EvidenceEngine.swift
Sources/HarnessCore/ExternalActions.swift
Sources/HarnessCore/OutboxReconciliation.swift
Sources/HarnessCore/PolicyEngine.swift
Sources/HarnessCore/RunCoordinator.swift
Sources/HarnessCore/RunExecution.swift
Sources/HarnessCore/SourceImport.swift
Sources/HarnessCore/StepExecution.swift
Sources/HarnessCore/ToolBroker.swift
Sources/HarnessCore/ValidationReview.swift
Sources/HarnessDomain/Artifacts.swift
Sources/HarnessDomain/Project.swift
Sources/HarnessDomain/Protocol.swift
Sources/HarnessDomain/Run.swift
Sources/HarnessDomain/Runbook.swift
Sources/HarnessDomain/States.swift
Sources/HarnessIPC/CoordinatorClient.swift
Sources/HarnessIPC/CoordinatorProtocol.swift
Sources/HarnessInfrastructure/AttachmentCompiler.swift
Sources/HarnessInfrastructure/ContextCompiler.swift
Sources/HarnessInfrastructure/ContextFirewall.swift
Sources/HarnessInfrastructure/ContextRelations.swift
Sources/HarnessInfrastructure/EventStore.swift
Sources/HarnessInfrastructure/GitWorkspace.swift
Sources/HarnessInfrastructure/IndexEngine.swift
Sources/HarnessInfrastructure/IntegrationClient.swift
Sources/HarnessInfrastructure/JiraDocumentText.swift
Sources/HarnessInfrastructure/OAuthClient.swift
Sources/HarnessInfrastructure/ProcessRunner.swift
Sources/HarnessInfrastructure/StoragePaths.swift
Sources/HarnessInfrastructure/StructuralParser.swift
Sources/HarnessInfrastructure/UpdateVerifier.swift
Sources/HarnessProviders/ClaudeSession.swift
Sources/HarnessProviders/CodexSession.swift
Sources/HarnessProviders/HarnessTools.swift
Sources/HarnessProviders/ProviderGateway.swift
Sources/HarnessService/ServiceMain.swift
Sources/HarnessUI/App/HarnessApp.swift
Sources/HarnessUI/Components/DesignPrimitives.swift
Sources/HarnessUI/Components/RunbookValidatorsEditor.swift
Sources/HarnessUI/Stores/AppStore.swift
Sources/HarnessUI/Stores/NotificationRouter.swift
Sources/HarnessUI/Stores/OAuthBrowserSession.swift
Sources/HarnessUI/Views/ActivityView.swift
Sources/HarnessUI/Views/CommandCenterView.swift
Sources/HarnessUI/Views/CommandPaletteView.swift
Sources/HarnessUI/Views/ContentView.swift
Sources/HarnessUI/Views/ContextView.swift
Sources/HarnessUI/Views/DecisionsView.swift
Sources/HarnessUI/Views/DiffModel.swift
Sources/HarnessUI/Views/DiffView.swift
Sources/HarnessUI/Views/EvidenceExportView.swift
Sources/HarnessUI/Views/EvidenceView.swift
Sources/HarnessUI/Views/IntegrationSettingsView.swift
Sources/HarnessUI/Views/NewRunView.swift
Sources/HarnessUI/Views/ProjectSettingsView.swift
Sources/HarnessUI/Views/ProjectsView.swift
Sources/HarnessUI/Views/ReviewView.swift
Sources/HarnessUI/Views/RunPlanView.swift
Sources/HarnessUI/Views/RunWorkspace.swift
Sources/HarnessUI/Views/RunbooksView.swift
Sources/HarnessUI/Views/RunsView.swift
Sources/HarnessUI/Views/SettingsView.swift
Sources/HarnessUI/Views/SidebarView.swift
Sources/HarnessUI/Views/TokensView.swift
Sources/HarnessUI/Views/ValidationView.swift
docs/IMPLEMENTATION.md
docs/OPERATIONS.md
docs/QA.md
docs/SPEC.md
script/build_and_run.sh
script/generate_xcode_project.py
script/package_licenses.py
script/release.sh
```
