# Guia Fronda, importação de contexto e escolha de executores

## Experiência

- **Guia Fronda** aparece no primeiro uso e continua acessível na biblioteca, na visão geral, no menu Ajuda e em `⌘K`.
- O percurso **Conecte → Traga → Prepare → Comece** acompanha conexões, extensões, projetos e tarefas reais. Importar contexto é opcional.
- Seis guias pesquisáveis explicam conexão, importação, modelos, primeira tarefa, revisão e atalhos. Cada guia leva à ação correspondente.
- A tela usa a marca, a mascote e os tokens existentes, com temas claro/escuro e respeito à preferência de reduzir movimento.
- **Ajustes → Providers → Conectar e escolher contexto** salva o executável, verifica a instalação e abre a revisão de importação. A autenticação continua no CLI oficial.
- A revisão oferece busca, checkboxes, origem e prévia por item. Nada vem marcado. É possível revisar novamente em Providers ou Extensões.
- Na criação da tarefa é possível escolher modelo e esforço. **Modelo e esforço**, no cabeçalho da tarefa, também permite personalizar os agentes de cada etapa.

## O que pode ser importado

| Origem | Conteúdo portátil |
| --- | --- |
| Codex do usuário | `~/.codex/skills`, `rules`, `commands`, `agents` em Markdown, `AGENTS.md`, `AGENTS.override.md`, `~/.agents/skills` |
| Codex do projeto | As mesmas pastas em `.codex`, regras na raiz do projeto e `.agents/skills` |
| Codex `config.toml` | `model`, `model_reasoning_effort` e tabelas simples `mcp_servers.<nome>` com `command`, `args` ou `url` |
| Claude Code do usuário | `~/.claude/skills`, `rules`, `commands`, `agents` em Markdown, `CLAUDE.md`, padrões de `settings.json` e `settings.local.json` |
| Claude Code do projeto | As mesmas pastas em `.claude`, `CLAUDE.md`, `CLAUDE.local.md` e MCPs em `.mcp.json` |
| Plugins instalados | Arquivos `SKILL.md` em diretórios `skills` do cache de plugins dos providers |

`CODEX_HOME` e `CLAUDE_CONFIG_DIR` são considerados quando presentes no ambiente do coordenador. Variáveis definidas apenas em um shell não necessariamente chegam ao serviço iniciado pelo macOS.

Ao selecionar um projeto na importação, os itens escolhidos ficam restritos a esse projeto. Sem projeto, ficam disponíveis no catálogo global. A importação mantém vínculo com a origem e versão do conteúdo; repetir a mesma importação não duplica o item. Alterar a origem exige nova revisão das tarefas vinculadas.

### Limites explícitos

- Não há cópia de sessões, históricos, credenciais, bancos de dados, hooks ou concessões de permissão.
- `~/.claude.json` mistura estado privado e não é aberto. MCPs privados/globais desse arquivo precisam ser configurados em Extensões ou exportados pelo usuário para `.mcp.json` do projeto.
- Regras de execução `.rules`, definições de agentes em TOML, arquivos adicionais de plugins e sintaxes TOML fora do subconjunto portátil não são traduzidos automaticamente.
- Agentes e comandos em Markdown entram como **instruções sob demanda**. Isso não instancia agentes nativos do Codex ou do Claude Code.
- Skills mantêm referência à origem local e verificação de conteúdo. Não são uma cópia transportável de todos os arquivos do pacote. Scripts não são executados pela importação.
- Arquivos precisam ser regulares, UTF-8, sem links simbólicos e ter até 128 KB. Cada árvore tem limite de 500 documentos e profundidade limitada; atingir o limite de documentos gera aviso.
- A prévia visível tem até 8.000 caracteres. O coordenador mantém o conteúdo aprovado em memória por 15 minutos e aceita apenas IDs dessa prévia para aplicar a seleção.

### Regras e ferramentas

Regras importadas são incluídas como conteúdo não confiável no contexto aprovado da tarefa. Skills, comandos e instruções de agentes são lidos sob demanda pelo broker existente. Importação não concede permissões adicionais.

MCPs chegam **desativados**, sem variáveis de ambiente, cabeçalhos de autenticação ou concessões de ferramentas. URLs com credenciais, query ou fragmento, transportes incompatíveis e argumentos não portáteis pedem configuração manual. Atualizar uma conexão limpa concessões anteriores. Descoberta de ferramentas e ativação continuam explícitas em Extensões.

## Modelos, esforço e agentes

- Codex consulta `model/list` no App Server instalado e apresenta os esforços anunciados por cada modelo. Essa consulta não inicia uma tarefa de inferência.
- Claude Code apresenta os aliases `haiku`, `sonnet` e `opus`; a disponibilidade depende da conta. O suporte a `--effort` é conferido no CLI instalado. Identificadores personalizados também podem ser informados.
- Padrões de modelo/esforço importados são usados em novas tarefas desse provider.
- Cada etapa herda a configuração da tarefa e permite sobrescrever provider, modelo e esforço. Ao trocar de provider na etapa, os padrões do outro provider não são herdados.
- O controle vale para **agentes por etapa coordenados pelo Fronda**. Subagentes internos dos CLIs continuam fora desse fluxo.
- Alterações durante execução ativa são bloqueadas. Salvar uma nova configuração cria revisão, invalida aprovações e resultados dependentes e exige revisar o contexto novamente.
- O coordenador envia modelo/esforço ao adapter e registra os valores solicitados em cada tentativa. Valores históricos não são reescritos.
- O orçamento é o teto de tokens existente da tarefa. As orientações de esforço não são cotações de preço nem garantias de custo monetário.

Referências: [Codex App Server](https://learn.chatgpt.com/docs/app-server), [modelos do Claude Code](https://code.claude.com/docs/en/model-config), [configurações do Claude Code](https://code.claude.com/docs/en/settings) e [MCP no Claude Code](https://code.claude.com/docs/en/mcp).

## Arquivos desta implementação

Novos:

- `Sources/HarnessDomain/ExecutionConfiguration.swift` e `ProviderImport.swift`.
- `Sources/HarnessInfrastructure/ProviderImport/ProviderImportFiles.swift`, `ProviderConfigReader.swift` e `ProviderContextScanner.swift`.
- `Sources/HarnessCore/ProviderImportCoordinator.swift`.
- `Sources/HarnessProviders/ProviderModelCatalog.swift`.
- `Sources/HarnessUI/Views/Guide/GuideCatalog.swift`, `GuideJourney.swift`, `GuideView.swift` e `GuideEntryCard.swift`.
- `Sources/HarnessUI/Views/ProviderImport/ProviderImportView.swift`.
- `Sources/HarnessUI/Views/Execution/ExecutionControls.swift`, `StepExecutionControls.swift` e `RunExecutionEditor.swift`.
- `Sources/HarnessUI/Views/Settings/ProviderConnectionsView.swift` e este documento.

Integrações em arquivos existentes:

- Domain: `Run.swift`, `Runbook.swift`, `Project.swift`, `Extensions.swift`.
- Core: `RunCoordinator.swift`, `RunExecution.swift`, `ValidationReview.swift`, `ExtensionCatalog.swift`, `ExtensionExecution.swift`.
- Providers: `CodexSession.swift`, `ClaudeSession.swift`.
- UI: `AppStore.swift`, `FrondaCommands.swift`, `WorkspaceDestination.swift`, `ContentView.swift`, `CommandCenterView.swift`, `PaletteEntry.swift`, `SettingsView.swift`, `ExtensionsView.swift`, `NewRunDraft.swift`, `NewRunView.swift`, `RunPlanView.swift`, `RunWorkspaceHeader.swift`, `RunbookStepEditor.swift`, `RunJourneyDetail.swift` e `ContextView.swift`.
- O projeto Xcode é regenerado pelo script existente para incluir os novos fontes.

Campos persistidos novos são opcionais para manter a leitura dos registros anteriores. Nenhuma dependência ou arquivo de teste foi adicionado. O checkout já continha alterações de outras frentes; esta lista descreve somente o escopo da implementação.

## Validação

Conferência manual realizada em uma cópia do app com runtime isolado:

- **PASS:** primeiro uso abre o guia; navegação pelos guias e visual nos temas claro e escuro.
- **PASS:** na versão final, buscar `skills` em `⌘K` abre diretamente o conteúdo do guia correspondente.
- **PASS:** descoberta local do Codex, seleção e importação de uma skill, com origem e conteúdo visíveis.
- **PASS:** reimportação da skill na versão final com seleção individual; o item já importado permanece identificado na lista.
- **PASS:** descoberta de 21 skills locais do Claude Code na versão final, com seleção inicialmente vazia. Nenhum item dessa origem foi aplicado nesta conferência.
- **PASS:** catálogo real do Codex, escolha de `gpt-5.6-luna`/esforço baixo na tarefa e persistência.
- **PASS:** alteração do esforço da investigação para médio, demais etapas herdando baixo, persistência após reabrir e nova aprovação exigida.
- **PASS:** conflito de revisão preserva a tarefa atual e mantém a edição aberta, sem sobrescrever mudanças concorrentes.
- **NOT-RUN:** inferência paga, execução de ferramentas MCP importadas e execução real pelo Claude Code.
- **NOT-RUN:** VoiceOver e conferência manual da preferência Reduzir Movimento.

Comandos executados em 27/09/2026:

| Verificação | Resultado | Evidência |
| --- | --- | --- |
| `./script/validate.sh` | **PASS** | `.build/qa/run-Cw3IbO/` |
| SwiftPM | **PASS**, 42 testes existentes | `run-Cw3IbO/unit.xml` |
| Xcode | **PASS**, 48 testes existentes, incluindo 6 de interface; zero falhas e zero ignorados | `run-Cw3IbO/Harness.xcresult` |
| Build universal e assinatura ad hoc | **PASS** | `dist/Fronda.app` |
| `./script/validate.sh --unit-only` após os ajustes finais | **PASS**, lint e 42 testes existentes | `.build/qa/run-EQCVPQ/unit.xml` |
| `git diff --check` | **PASS** | Nenhum erro de whitespace |

Os dois últimos ajustes foram abrir o guia na posição do assunto pesquisado e usar o texto já sanitizado ao ler uma skill importada. Foram incluídos no pacote final e na repetição de lint/SwiftPM; a navegação e a importação foram reconferidas manualmente nesse pacote. A suíte Xcode completa não foi repetida após esses dois ajustes.

### Roteiro de aceite

1. Abrir Guia Fronda e procurar por skills ou modelo em `⌘K`.
2. Em Providers, conectar a instalação local e conferir origem/conteúdo antes de marcar itens.
3. Importar uma regra, uma skill e um MCP do projeto. Conferir o escopo e o MCP desativado em Extensões.
4. Preparar uma tarefa e conferir a regra no contexto antes de autorizar envio.
5. Escolher modelo/esforço diferentes na investigação e revisão; salvar, reabrir e conferir o resumo.
6. Com autorização para consumo, executar uma tarefa pequena em cada provider e conferir modelo, esforço solicitado e uso reportado no histórico.
7. Descobrir e conceder somente as ferramentas necessárias de um MCP importado, depois conferir uma chamada real.
