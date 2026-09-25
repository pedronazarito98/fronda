# Central de sessões

A ilha do Harness acompanha runs do coordenador local e eventos de sessões externas de Codex e Claude Code. Abra com **⌥⌘I** no Harness, pelo menu **Execução → Central de sessões**, pela barra de menus ou clicando na ilha. Os ajustes ficam em **Ajustes → Geral → Central de sessões**.

## Interação

- Compacta: em repouso acompanha o tamanho da câmera; durante atividade, mostra indicadores nas laterais livres do notch.
- Prévia: atividade prioritária, provider e estado; tempo decorrido somente quando uma tentativa do Harness informa o início. Sessões externas não têm duração estimada.
- Expandida: lista compacta de sessões, estado e etapas das runs; tokens **reportados** no tooltip da run e na tela de detalhes. Sessões externas mostram estado e horário do último evento.
- Hover de 180 ms mostra uma prévia; clique/⌥⌘I abre a lista. Sair da ilha recolhe após 500 ms, exceto quando fixada. **Esc** recolhe e solta a fixação.
- Aumento na quantidade de pendências revela uma prévia por cinco segundos, sem tomar foco. Clicar abre a lista e interrompe o recolhimento automático.
- Uma run abre sua revisão no Harness. Sessões externas do Codex oferecem um link para o aplicativo Codex, quando instalado.
- Pausar/retomar fila controla apenas a fila do Harness. Aprovações e comandos de sessões externas continuam nos providers.
- A câmera é medida pelas áreas seguras de `NSScreen`. Sem notch, a ilha fica abaixo da barra de menus do monitor principal. Mudanças de monitores recalculam a posição.
- O modo compacto permanece escuro para se integrar à câmera. A expansão usa uma superfície Liquid Glass adaptável ao tema no macOS 26/27, com material alternativo no macOS 15 e fundo opaco com Reduzir Transparência. Reduzir Movimento desativa as transições.

## Conectar Codex

Use **Configurar hooks do Codex** nos ajustes ou, a partir do checkout:

```sh
./dist/harness connect codex
```

O instalador mescla apenas registros identificados como `Harness session status` no arquivo dedicado `$CODEX_HOME/hooks.json` (ou `~/.codex/hooks.json`). Outros hooks são preservados; `config.toml`, autenticação e transcrições não são lidos. **O Codex exige revisar e autorizar hooks novos em `/hooks`**. Instalar não significa que o provider já está emitindo eventos. Inicie ou retome a sessão após autorizar.

Também é possível iniciar o CLI com `./dist/harness watch codex`, que configura esses mesmos hooks antes de abrir o provider. O acompanhamento depende de a versão/interface do Codex carregar e autorizar os hooks. Sessões anteriores à configuração não são importadas.

Para remover apenas a integração:

```sh
./dist/harness disconnect codex
```

Se mover o app ou mudar o diretório de dados, configure os hooks novamente para atualizar o caminho do helper.

## Conectar Claude Code

No terminal do projeto, inicie:

```sh
/caminho/para/Harness.app/Contents/Helpers/harness watch claude
```

No checkout, use `./dist/harness watch claude`. Os ajustes oferecem o comando absoluto para copiar. Para retomar uma sessão existente, acrescente `--resume`. Os hooks são passados como configurações adicionais somente para essa invocação; nenhum arquivo de configuração ou autenticação do Claude é editado. O CLI precisa estar instalado e autenticado pelo próprio usuário. Políticas administradas podem impedir hooks locais.

O wrapper mantém o terminal, os argumentos e os sinais do CLI original. Não envia prompts nem inicia trabalho por conta própria. Não oferece aprovação automática, controle remoto ou importação de conversas.

## Dados e confiabilidade

O helper `session-event` decodifica somente `session_id`, `cwd`, `hook_event_name`, `source` e `agent_id`. Persiste apenas identificador, provider, nome da pasta do projeto, estado e horário. Ignora prompts, argumentos/resultados de ferramentas, mensagens e `transcript_path`. Não abre arquivos de sessão, bancos dos providers, credenciais ou históricos. Não envia dados à rede.

Cada sessão tem um resumo JSON atômico em `Application Support/Harness/session-status`, com nome derivado de hash e permissões de usuário. O app consulta esses resumos junto de seu ciclo de atualização de dois segundos. Subagentes com `agent_id` são ignorados para não sobrescrever o estado do pai. Sessões já vinculadas a uma run não são duplicadas.

`Stop` significa **turno concluído**, não tarefa validada. `SessionEnd` remove a sessão da lista. Após cinco minutos sem eventos, um estado ativo recebe **Sem atualização recente** e deixa de contar como ativo; não é possível inferir conclusão de uma sessão encerrada abruptamente. Resumos com mais de 24 horas não aparecem. Tokens externos não são estimados nem inventados.

## Validação manual

- Expandir/recolher, fixar, usar Esc, abrir o Harness com a janela principal fechada e alternar a preferência da ilha.
- Conferir uma run real mudando de estado, abrindo detalhes e atualizando etapas/tokens.
- Autorizar hooks no Codex e confirmar eventos de uma nova sessão, aprovação pendente, fim de turno e encerramento.
- Iniciar Claude autenticado com `watch claude` e repetir o ciclo.
- Validar VoiceOver, Reduzir Movimento/Transparência, Spaces, tela cheia, monitor sem notch e conectar/desconectar monitor.

Referências: [hooks do Codex](https://developers.openai.com/codex/hooks), [hooks do Claude Code](https://code.claude.com/docs/en/hooks), [novidades de AppKit no macOS 27](https://developer.apple.com/videos/play/wwdc2026/289/).

## Evidência desta implementação — 23/09/2026

- **PASS**: `./script/build_and_run.sh --verify`, no macOS 27.0 / Xcode 27.0; app empacotado e processo em execução.
- **PASS**: `./script/lint.sh`, `git diff --check` e `codesign --verify --deep --strict --verbose=1 dist/Harness.app`.
- **PASS**: UI real expandindo por clique/⌥⌘I, fixação, recolhimento por Esc, preferência ligar/desligar, abertura da janela principal pela ilha inclusive após fechar as janelas principais.
- **PASS**: instalação real dos hooks do Codex por `./dist/harness connect codex`; a autorização continua pendente no provider.
- **PASS**: `./dist/harness watch claude --version` encaminhou a execução para Claude Code 2.1.280. Isso não comprova eventos de uma sessão autenticada.
- **NOT-RUN**: ciclo completo de eventos externos; Codex exige aprovação dos hooks e o Harness informa `AUTH_REQUIRED` para Claude. Também não foram validados nesta alteração runs em execução, múltiplos monitores, tela cheia, VoiceOver e preferências de acessibilidade.
- Testes automatizados não foram criados nem executados.

## Arquivos

Criados:

- `Sources/HarnessDomain/ExternalSession.swift`
- `Sources/HarnessInfrastructure/ExternalSessionBridge.swift`
- `Sources/HarnessInfrastructure/CodexIslandHooks.swift`
- `Sources/HarnessCLI/SessionCommands.swift`
- `Sources/HarnessUI/Stores/AppStore+SessionIsland.swift`
- `Sources/HarnessUI/Stores/SessionIslandController.swift`
- `Sources/HarnessUI/Views/SessionIsland/SessionIslandView.swift`
- `Sources/HarnessUI/Views/SessionIsland/IslandSessionRows.swift`
- `Sources/HarnessUI/Views/SessionIsland/ExternalSessionSetupView.swift`
- `docs/SESSION-ISLAND.md`

Modificados: `CLIMain.swift`, `HarnessApp.swift`, `AppStore.swift`, `CommandPaletteView.swift`, `ContentView.swift`, `SettingsView.swift` e o projeto Xcode regenerado. Fora do repositório, somente os registros desta integração no arquivo dedicado de hooks do Codex foram configurados. `.vscode/` já existia e não foi alterado.

## Refinamento visual

A expansão deixa o bloco preto e passa a ter Liquid Glass nativo, cantos de 30 pontos e hierarquia de títulos, indicadores e ações. O material compacto e expandido compartilha identidade em `GlassEffectContainer`. A geometria usa mola de 0,52 s; a janela reserva espaço durante a transição e libera a área transparente ao estabilizar, inclusive ao interromper uma transição. Títulos, indicadores, lista e ações aparecem em sequência curta, com deslocamento e desfoque discretos. Controles respondem a hover e pressão; o símbolo do estado vazio faz uma entrada única, sem animação contínua quando ocioso.

Arquivos desta revisão: `SessionIslandView.swift`, `IslandSessionRows.swift`, `SessionIslandController.swift`, novos `IslandVisualStyle.swift` e `IslandEmptyState.swift`, projeto Xcode regenerado e esta documentação. Integrações, dados, comandos dos providers e hooks não foram alterados nesta revisão.

Validação visual observada: tema claro/Sistema e Escuro, expansão, recolhimento, fixação e alternância rápida pelo atalho. A preferência Sistema foi restaurada. Build/abertura, lint e `git diff --check` passaram. Testes automatizados não foram criados nem executados; preferências de acessibilidade e monitores externos ainda precisam de validação manual. A inspeção por screenshots confirma os estados, mas não mede fluidez ou taxa de quadros.


## Revisão orientada pelas referências — 24/09/2026

Direção aprovada: [Alcove](https://tryalcove.com/) para apresentação compacta e transições, [Notchi](https://notch.website/) para acompanhamento de agentes e união com a câmera, e [DynamicLake](https://www.dynamiclake.com/liquidglass) para o material translúcido.

- Três estados explícitos: compacto, prévia e expandido. Um mesmo contorno se transforma com mola de 0,46 s e acomodação curta, mantendo o topo ancorado na tela.
- Ombros côncavos unem a superfície à borda; o corpo Liquid Glass fica conectado ao topo preto, sem intervalo transparente. A faixa preta fica fora do grupo de vidro para não sofrer refração, e termina antes do texto.
- A lista tem altura proporcional a até quatro sessões; o restante usa rolagem. Estado vazio compacto, sem ilustração decorativa ou animação ociosa. Indicador animado somente durante execução, respeitando Reduzir Movimento.
- A prévia dá prioridade a solicitações de atenção de Harness e sessões externas. Nenhum conteúdo de conversa é importado. A identificação de sessões, hooks e comandos dos providers foi preservada.
- Preferência de hover renomeada para “Mostrar prévia ao passar o mouse”.

Arquivos desta revisão:

- Alterados: `Sources/HarnessUI/Stores/SessionIslandController.swift`, `Sources/HarnessUI/Views/SessionIsland/SessionIslandView.swift`, `IslandVisualStyle.swift`, `IslandEmptyState.swift`, `IslandSessionRows.swift` (na mesma pasta), `Sources/HarnessUI/Views/SettingsView.swift`, projeto Xcode regenerado e este documento.
- Criados: `Sources/HarnessUI/Views/SessionIsland/IslandSilhouette.swift`, `IslandCrownView.swift` e `IslandActivitySummary.swift` (na mesma pasta).

Validação: build/abertura pelo script oficial, lint, diff e assinatura; interação observada por clique, ⌥⌘I, Esc, fixar e Abrir Harness. Claro/Sistema e Escuro inspecionados; preferência Sistema restaurada. O estado de repouso agora ocupa somente a área da câmera com margem mínima.

**Pendente de validação manual:** hover com ponteiro físico, sessões reais em execução/aguardando aprovação, prévia automática de pendências, monitores externos/Spaces/tela cheia, VoiceOver e preferências de redução de movimento/transparência. A inspeção de estados por screenshots não mede FPS. Não foram criados nem executados testes automatizados ou mocks.
