# QA observado — Harness

Data: 23/09/2026 (horários de eventos em UTC). Mac Apple Silicon arm64, macOS 27.0 (26A428), Xcode 27.0 (27A266a). Build nativo Debug para arm64/x86_64, deployment macOS 15. Execução observada somente em arm64/macOS 27.

**Resultado da distribuição: PARTIAL.** Existe uma implementação nativa funcional e fluxos locais concluídos. Os 12 critérios completos da especificação ainda não passaram: Claude, integrações autenticadas, distribuição assinada/notarizada e parte do QA manual permanecem pendentes. Claude está **NOT_RUN por decisão do usuário**, sem insistência de login.

## Revisão dos critérios e suíte automatizada — 23/09/2026

A evidência histórica abaixo foi preservada, mas seus hashes e runs descrevem o build anterior. Esta revisão adiciona uma barreira repetível para mudanças futuras. Os critérios completos continuam sendo os da seção 18 da [SPEC](SPEC.md); passar testes locais não substitui integrações reais, providers autenticados ou QA de distribuição.

Comando canônico: `./script/validate.sh`. Executa lint estrito, XCTest via SwiftPM, XCTest/XCUITest pelo scheme `Harness`, build universal e verificação de assinatura ad hoc. `--unit-only` é uma execução parcial explicitamente identificada. Resultados estruturados: `.build/qa/run-*/unit.xml` e `Harness.xcresult`.

### Critérios de passagem revisados

| Aceite | Preparação e ação | Resultado obrigatório | Cobertura automática e limite |
|---|---|---|---|
| AC-01 | Cadastrar dois repositórios, indexar, buscar símbolo e reiniciar o coordenador. | Ambos permanecem cadastrados; busca retorna arquivo/símbolo e índice válido. | `ExecutionTests.testTwoProjectsKeepTheirSearchIndexAcrossCoordinatorRestart`; `WorkspaceTests` valida o parser; XCUITest cobre persistência visual após reabrir o app. |
| AC-02 | Importar Jira e concluir uma implementação com cada provider. | Plano/contexto aprovados, worktree, gates, revisão e critérios no mesmo snapshot; apenas então READY. | `CoordinatorTests` e `ExecutionTests` cobrem o fechamento positivo e recusam etapas incompletas, exit ausente, snapshot vazio e vínculos inválidos. Jira e os dois providers reais seguem pendentes. |
| AC-03 | Preparar duas worktrees simultâneas; alterar uma; interromper execução. | Branches/arquivos independentes, checkout original intacto e término observado. | `WorkspaceTests` cria worktrees reais em paralelo; `ExecutionTests` interrompe processo real. Concorrência de sessões de providers mantém a evidência histórica, não foi repetida nesta suíte. |
| AC-04 | Alterar catálogo, pedir retry e trocar provider. | Invalidar etapas dependentes e revisões; preservar etapas anteriores não afetadas; exigir nova revisão do contexto. | `CoordinatorTests.testRetryInvalidatesOnlyStepAndDescendants` e `ExecutionTests` cobrem catálogo/provider. Steering de hunk e nova tentativa real entre providers permanecem manuais. |
| AC-05 | Compilar pack com pin, exclusão, conteúdo sensível sintético e orçamento insuficiente. | Excluir conteúdo solicitado, redigir padrões em campos livres, conferir hash/estimativa, recusar perda silenciosa de pin obrigatório. | `ContextTests`; XCUITest abre Contexto da run criada. Inspeção visual completa do grafo e payload efetivamente enviado a cada provider ainda exige cenário real. |
| AC-06 | Tentar path externo, fora de escopo, hash antigo, escrita em modo leitura/revisão e isolamento forte. | Nenhuma escrita indevida; negativa explicável; estado não pode avançar para sucesso. | `ContextTests`, `PolicyEvidenceTests`, `ExecutionTests`. `WorkspaceTests` confirma que um hook de commit do projeto continua sendo respeitado. |
| AC-07 | Executar comandos locais exit 0/1, comando não aprovado, timeout e edição posterior; reabrir estado interrompido. | PASS/FAIL/BLOCKED/NOT_RUN/STALE corretos; sem exit code inventado após interrupção. | `CoordinatorTests`, `WorkspaceTests`, `ExecutionTests` e XCUITest da tela Validação. Recuperação do core usa estado interrompido controlado; crash real continua registrado na evidência histórica. |
| AC-08 | Repetir request simultaneamente e aprovar proposta após alterar arquivos. Depois testar perda de resposta remota. | Uma operação local por request ID; proposta obsoleta não executada; efeito remoto incerto exige reconciliação. | `ExecutionTests.testConcurrentRetriesOfSameCreateRequestCreateExactlyOneRun` e `PolicyEvidenceTests.testChangedSnapshotRejectsPreparedCommitWithoutWriting`. GitHub/Jira reais e perda de resposta remota: NOT_RUN. |
| AC-09 | Fazer replay e exportar pacotes completo e apenas metadados. | Replay não executa trabalho; hashes conferem; metadados omitem conteúdo, nomes e caminhos locais. | `CoordinatorTests.testReplayReturnsEarlierStateWithoutExecutingIt` e `PolicyEvidenceTests.testExportHashesAndMetadataOnlyPrivacy`. |
| AC-10 | Receber métricas acumuladas repetidas, cruzar 80%/100% e comparar com estimativa de pack. | Não somar estimativa/cache ao total; um alerta por cruzamento; bloquear no teto observado. | `RunbookTests`, `ContextTests`, `PolicyEvidenceTests`. Eventos são sintéticos de teste; não medem cobrança nem substituem métricas reais do Claude. |
| AC-11 | Criar run por ⌘N, buscar por ⌘K, dispensar com Esc, abrir segunda janela e alterar tema. | Controles operáveis, persistência e janela principal preservada. | Seis XCUITests no app nativo. VoiceOver falado, notificações, menu bar, múltiplos monitores e navegação completa por teclado continuam manuais. |
| AC-12 | Reabrir estado interrompido, fornecer bookmark inválido e diretório que não é a worktree esperada. | Recuperação/erro explícitos, sem falso sucesso ou reutilização indevida. | `CoordinatorTests`, `ExecutionTests`, `WorkspaceTests`. Offline, expiração OAuth e versões incompatíveis em sessões reais continuam pendentes. |

### Regressões corrigidas nesta revisão

1. **READY prematuro:** etapas obrigatórias NOT_RUN/RUNNING/FAIL/BLOCKED/STALE/CANCELLED, snapshot vazio e critérios ausentes não podem produzir READY. Vínculos de arquivo precisam apontar para critérios existentes. Skip condicional só vale quando a condição é falsa, e exit 0 precisa ter sido observado.
2. **Validação parcial exibida como completa:** executar apenas um comando não marca a etapa PASS quando ainda faltam gates obrigatórios do catálogo vigente.
3. **Snapshot incompleto:** alteração apenas no index Git agora muda a revisão e invalida aprovações/evidências, sem ler o conteúdo de arquivos privados.
4. **Contexto inconsistente:** um item previamente incluído não conserva esse estado ao ser excluído. O compilador redige também critérios, títulos de etapas, conteúdo candidato e diff antes de montar o payload.
5. **Duplicação por concorrência:** repetições simultâneas do mesmo request ID aguardam a mesma operação; o cache continua atendendo repetições após a conclusão.
6. **Hooks ignorados:** commit/push explícitos preservam os hooks do projeto. Operações de inspeção/preparação continuam sem executar hooks de checkout.
7. **Lint ausente:** fontes Swift próprias e testes foram normalizados; a lib C vendorizada não foi reformatada. Dois `forEach` de liberação de ponteiros foram substituídos por loops equivalentes exigidos pelo lint.

A suíte trabalha com arquivos, processos, Git, RPC e armazenamento temporários criados para o teste. Não usa mocks, não envia tarefas a providers e não faz push ou publicação remota. O XCUITest mantém o sandbox padrão da Apple; o scheme prepara as fixtures pela CLI antes de iniciar o runner e remove os coordenadores/diretórios temporários ao terminar.

### Resultado da execução atual

**Ciclo local: PASS.** `./script/validate.sh` terminou com exit 0 em 23/09/2026. Relatórios desta execução: [JUnit SwiftPM](../.build/qa/run-f27rg5/unit.xml) e [resultado nativo do Xcode](../.build/qa/run-f27rg5/Harness.xcresult).

| Verificação | Estado | Evidência observada |
|---|---|---|
| Lint estrito | PASS | `swift-format lint --strict` em `Sources`, `Tests` e `Package.swift`. |
| XCTest via SwiftPM | PASS | JUnit contém 42 testes, zero falhas, erros ou skips. |
| XCTest nativo | PASS | Os mesmos 42 testes passaram pelo scheme `Harness` no Xcode. |
| XCUITest | PASS | Seis cenários passaram: criação de run, estados de gates, palette, persistência de projetos/runs, segunda janela e temas. As capturas de tema ficam restritas à janela de ajustes do Harness. |
| Resultado agregado do Xcode | PASS | `xcresulttool` confirmou 48 testes, zero falhas e zero skips. São 42 XCTest + 6 XCUITest; a repetição via SwiftPM não aumenta a cobertura para 90 cenários distintos. |
| Build Debug universal | PASS | 11 targets gerados (9 de produto e 2 de teste). `lipo -archs` confirmou `x86_64 arm64` no executável, dylib Debug, serviço e CLI empacotados. |
| Assinatura ad hoc | PASS | `codesign --verify --deep --strict dist/Harness.app` concluiu com sucesso. |
| Limpeza das fixtures de UI | PASS | O post-action concluiu e o manifesto temporário de fixtures deixou de existir. |

Os testes foram executados em Apple Silicon/macOS 27.0. A presença da arquitetura Intel no pacote não comprova execução em Intel ou macOS 15. A geração JUnit usa o runner XCTest com um único worker; o runner nativo de UI mantém o sandbox padrão. Não foram adicionadas dependências externas.

A adoção do lint normalizou 54 arquivos Swift de produção sem mudança funcional. As demais alterações se concentram nas regressões descritas acima, em identificadores de acessibilidade e na infraestrutura de testes. O código C vendorizado foi preservado.

SHA-256 do pacote desta execução (substituem os hashes históricos somente para identificar este novo build):

```text
Harness             10253f27df1fbaf4f7e89d7c97e87b7d4a61c7637b8a77128c20401559e758fb
Harness.debug.dylib 842d25a2cd37fd2e7da2f3bb189d2ab8fa72c9d31c8f1de389303fca2697428d
HarnessService     64b566bc9842581c09a1ff47f16f9193a0625fbda211240bcc4b95095d3f28c8
harness            12d4d73f85d135477f80a069c85cff7764020eff7e8453a6a59c5de700aaa4a5
```

**Resultado da distribuição: PARTIAL.** Integrações autenticadas, Claude, QA manual restante e distribuição Developer ID/notarizada não foram aprovados por esta suíte. As lacunas de cada aceite estão na matriz acima e na seção de validação manual ao final.

## Registro anterior: builds e ambiente

| Verificação | Estado | Evidência |
|---|---|---|
| `script/build_and_run.sh --build-only` | PASS | Xcode compila os 9 targets nativos e gera `dist/Harness.app` com helper/CLI. |
| `codesign --verify --deep --strict` | PASS | Bundle e binários válidos sob assinatura ad hoc. Não equivale a Developer ID/Gatekeeper/notarização. |
| `swift build --product HarnessCLI` | PASS | Build SwiftPM concluído. Avisos de conversão numérica em C de terceiros preservados; nenhuma supressão global adicionada. |
| App aberto e operado por acessibilidade | PASS | Command Center, run, gates, revisão, contexto, Settings e palette inspecionados no app empacotado. |
| Codex 0.153.2 | PASS local | Sessões reais App Server, streaming, leitura/escrita mediada, métricas, interrupção e revisão independente. |
| Claude Code 2.1.280 | NOT_RUN | Binário atualizado e capacidade `--restricted` detectada; autenticação ausente. Nenhuma execução autenticada foi afirmada. |
| Developer ID/notarização | BLOCKED | Nenhuma identidade `Developer ID Application` disponível. Script de release preparado, sem upload à Apple. |
| Lint / XCTest / XCUITest | NOT_RUN naquele registro | A suíte formal foi adicionada na revisão descrita acima. |

## Projetos de referência

- **Nebula** — Python, projeto `09cc6ddc-16cc-4237-9482-4532db63cd7d`, base `a51ebcd89ddeb44673b03a730fd042708d2a78c4`. `notes.md` representa uma alteração preexistente não relacionada.
- **Orbit** — TypeScript, projeto `0b2b9715-55b1-4de1-a0b3-c7d29f020f35`, usado para políticas e resultados de processo.
- **Corpus** — 102 arquivos locais, projeto `a56445fd-d8a5-43eb-86ef-b77e3c96053c`, usado somente para compilação/seleção de contexto. Nenhum provider foi acionado para o benchmark de payload.

Todos ficam em `.qa/projects`; runtime separado em `.qa/runtime`. Não são projetos de produção. Nenhum commit/push foi feito no repositório Harness; commits foram feitos apenas para estabelecer bases Git nos projetos de referência.

## Registro anterior: cenários observados

| # | Estado | Resultado observado e limite |
|---|---|---|
| 1 | PASS | Mais de dois projetos cadastrados, FTS5 e símbolos reais recuperados; cadastro/índice preservados após reinício. |
| 2 | PARTIAL | Run local de correção com Codex chegou a READY com worktree, diff, gates, parecer independente, revisão e exportação. Origem Jira e Claude autenticado não exercitados. |
| 3 | PASS local | Duas tentativas de escrita em worktrees distintas sobre a mesma base se sobrepuseram por 9 s. A foi pausada, retomada e concluída; B foi bloqueada pelo orçamento e depois cancelada. Checkout original preservado. |
| 4 | PARTIAL | Retry/retomada e invalidação por snapshot observados. Steering/DAG e troca de provider implementados; matriz completa de todos os tipos de steering/provider não exercitada. |
| 5 | PASS local | Pack inspecionado; pin/exclusão geraram v3, pin incluído e exclusão respeitada. Hash, payload, razão e comparação estimada disponíveis. |
| 6 | PASS local | Path externo, arquivo privado, conteúdo com padrão sintético de segredo e escrita fora do escopo recusados. Mudança de dependência gerou proposta; recusa não gravou arquivo. |
| 7 | PASS local | PASS exit 0, FAIL exit 1, BLOCKED sem execução, NOT_RUN antes do gate e STALE após edição real. Crash durante gate produziu BLOCKED sem exit inventado. |
| 8 | NOT_RUN remoto | Adapters, prévia e reconciliação implementados; nenhuma conta GitHub/Jira conectada nem escrita remota enviada. Idempotência após perda real de resposta remota não afirmada. |
| 9 | PASS local | Replay recuperou evento #50/RUNNING sem reexecutar. Exportação READY teve todos os hashes de arquivos conferidos. Exportações finais incluem `trace.json`; prévia e modo somente metadados também conferidos. |
| 10 | PARTIAL | Codex: métricas acumuladas reais, interrupção por teto e retomada após ajuste. Corpus: redução estimada de payload reproduzida. Ledger Claude/custos reais não validados. |
| 11 | PARTIAL | Claro/escuro, Settings via ⌘,, palette via ⌘K, controles acessíveis e múltiplas janelas exercitados. VoiceOver falado, menu bar, notificações e monitores adicionais exigem QA manual. |
| 12 | PARTIAL | Reinício e recuperação durante validador, autenticação Claude ausente e divergência de snapshot observados. Rede offline, expiração OAuth e todos os tipos de bookmark/worktree divergente não exercitados. |

## Execução real com Codex

Run `2ed4f7e6-3618-497d-96a0-b113593194cd`: normalização de nome com `strip()` e fallback `mundo`; apenas `main.py` alterado na worktree. Dois gates PASS no mesmo snapshot: integridade do diff e asserções Python para espaços/nome vazio. Parecer independente sem achados de correção. O fluxo de confirmação humana foi exercitado por automação e assim registrado na justificativa; não representa uma revisão feita pessoalmente pelo usuário.

A UI mostrou **READY, 6/6 etapas**. Primeiro export verificado: `.qa/runtime/exports/2ed4f7e6-1790133589`, snapshot `9594737d91cd31df7a013bb1f0c4f49e852e815c161182e118907f7d6b155791`.

Preservação do checkout original:

```text
main.py  SHA-256 9bd66dcaf91cefc81c3ec2f76b52838c3efc583bc1e8cc904a39d88461f3cfb9
notes.md SHA-256 1f7e44dbc7237f68049a5cc53e3c2c2c48c9b9f912f77c812972e76ab708e747
Git: somente ?? notes.md; main.py original não modificado.
```

Run A `7be239ca-cf41-45ae-985c-ebf87558bcd6`: READY após pausa, orçamento e retomadas. 265.681 tokens reportados acumulados entre quatro tentativas, incluindo as interrompidas, no momento da exportação `.qa/runtime/exports/7be239ca-1790134118`. A primeira run de depuração usava a última requisição para parte do ledger; essa métrica antiga não foi usada como benchmark acumulado. O adapter final usa `tokenUsage.total` por sessão efêmera.

Run B `8e4f1a64-ab4a-44d3-a8ac-3e1cc19bdecd`: limite de 128 mil interrompeu a revisão quando o total observado ultrapassou o teto; depois foi cancelada. Há consumo posterior ao último evento recebido, portanto o teto é aplicado quando observado, sem prometer faturamento exato.

As primeiras tentativas se sobrepuseram entre **03:23:20Z e 03:23:29Z**. A não usou a worktree de B. Evidências locais: `.qa/concurrency-evidence.json` e os eventos normalizados de ambas as runs.

## Políticas, gates e crash

Run `ade4a3e9-e1a7-4c7c-bff4-e026cb94329b`, em Orbit, com workflow de validação sem etapa de implementação:

- `git diff --check`: PASS, exit 0.
- `/usr/bin/false`: FAIL, exit 1.
- `/usr/bin/true` sem aprovação: BLOCKED, exit não observado.
- `/bin/sleep 20`: observado RUNNING; execução normal PASS. Em nova execução, SIGKILL foi aplicado somente ao coordenador QA e o reinício produziu RECOVERING + gate BLOCKED, sem exit code.
- Edição controlada e arquivo fora do escopo produziram STALE e finding do Scope Guard. Os arquivos temporários foram restaurados/removidos depois do registro.
- Broker recusou path externo, `.env`, escrita fora do escopo e padrão sintético de segredo, sem alterar `greeting.ts`. Proposta para `Package.swift` foi recusada e o arquivo permaneceu ausente.

Evidências: `.qa/policy-evidence.json`, `.qa/gate-evidence.json`, `.qa/crash-evidence.json`, `.qa/stale-evidence.json`. Esses arquivos contêm resultados resumidos, não credenciais ou logs privados.

## Comparação de payload

Run de contexto `917640a4-4e80-481d-b305-1561200ad839`, sem envio ao provider:

```text
Corpus candidato:     72.984 tokens estimados
Pack v3 selecionado:  11.143 tokens estimados
Redução de payload:   84,73%
Método:               bytes UTF-8 / 4, arredondados para cima
Hash v3:              d371421365f6080cfc75a0f544644621f2c1fb1ab8a9c28a7f9b04240cd7c8a5
Pin metric_001.ts:     incluído
metric_000.ts:         excluído
```

A comparação usa os mesmos wrappers e contrato. Mede redução de texto enviado em relação aos candidatos daquela compilação. **Não mede economia financeira, qualidade ou consumo total do provider.** Evidência: `.qa/context-evidence.json`. Recompilações após evolução do contrato/ranking podem gerar outro hash/valor; o snapshot v3 continua disponível no replay.

## Registro anterior: conferência do pacote

- Xcode e SwiftPM recompilaram após os ajustes de importação e exportação. A integridade ad hoc passou em `codesign --verify --deep --strict`.
- Na UI, a segunda janela abriu a mesma run READY com navegação independente; fechar essa janela preservou a principal. Busca no grafo encontrou `greet · L1`; o Inspector carregou o payload da tentativa de revisão. Ajustes aplicaram Claro e retornaram a Sistema, com inspeção visual.
- Exportações `7be239ca-1790136122-fb11b9` (completa), `7be239ca-1790136122-8c8cfb` (metadados) e `7be239ca-1790136161-b1acce` (metadados pela UI) tiveram todos os hashes conferidos. O modo metadados omitiu diff, `main.py`, título da tarefa e paths absolutos. Evidência: `.qa/final-export-evidence.json`.
- O Core recusou um ID inválido de campo Jira. Nenhuma consulta autenticada de issue/anexo foi feita; download e OAuth continuam NOT_RUN remoto.
- A conferência de encerramento encontrou uma corrida: uma nova validação podia ser aceita nos 200 ms antes da saída. O coordenador agora entra atomicamente em encerramento, recusa comandos com `SERVICE_STOPPING` e suspende o agendamento antes da confirmação.

- A correção de encerramento foi exercitada: `SERVICE_STOPPING` no intervalo, reconexão confirmada e zero runs iniciadas indevidamente. Encerrar durante um gate ativo também foi recusado. Evidência: `.qa/shutdown-evidence.json`.
- O broker recusou `AUTH/qa-not-created.txt` e um link simbólico para um nome `.env` inexistente. Nenhum conteúdo privado foi criado ou aberto; o link temporário foi removido. Evidência: `.qa/path-firewall-evidence.json`.

Hashes SHA-256 dos binários finais (Debug universal, ad hoc):

```text
HarnessService f5e7af7105064aef53ac1c2f50d3fa211def2497a8ced630b25ba533e00a9172
Harness.debug.dylib fda02790c0272e59ec715ec7093234473ff2e475bc8a91110355be20aa628212
harness 6183c2b07459b0f3e2ada8882e7af2dfe74df92a82d4a55126db99013e2088ea
```

## Validação manual restante

Conectar GitHub/Jira com apps e repositórios autorizados; executar os fluxos de leitura/escrita com prévias e verificar reconciliação remota. Claude permanece NOT_RUN conforme pedido. Validar VoiceOver, navegação completa por teclado, notificações/deep links, menu bar, login opt-in, múltiplos monitores, macOS 15, outras versões suportadas e Intel. Medir 50 mil arquivos e latência com Instruments. Produzir e verificar distribuição Developer ID/notarizada e pacote de atualização real.
