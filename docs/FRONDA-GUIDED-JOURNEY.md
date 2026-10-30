# Primeira jornada com o mascote

Implementação de 28/09/2026. Integra as expressões já aprovadas às atividades reais
e acrescenta a jornada de preparação. Não altera a arte nem implementa as sete
ideias de personalidade adiadas.

## Entradas e percurso

Disponível em **Guia Fronda → Preparar minha primeira tarefa**, no menu **Ajuda**
e no popover do mini companheiro. Depois de uma pausa, a mesma entrada oferece
**Retomar minha jornada**.

1. Projeto: escolha uma pasta Git cadastrada ou adicione pelo botão existente.
2. Fluxo: escolha e confira o percurso da tarefa.
3. Executor: escolha Codex/Claude; modelo e esforço mantêm seus controles existentes.
4. Objetivo: escreva e saia do campo, ou confirme no guia.
5. Critérios: resultados verificáveis por linha; orientação opcional.
6. Preparação: use o botão real **Criar e preparar contexto**.
7. Contexto: confira as opções e conclua a orientação quando o contexto estiver disponível.

A dica acompanha o campo com um contorno, o mascote animado e uma explicação curta.
Sua posição evita o alvo quando há espaço. A interface continua interativa; o
usuário pode escolher opções, editar e navegar por conta própria.

Escolhas reais avançam a orientação. Os botões de confirmação permitem manter um
valor já selecionado. Objetivo vazio, projeto ausente e fluxo inválido não avançam
pela confirmação. Pular pula somente a orientação; não preenche dados nem executa
ações. Nas etapas finais, **Continuar sem guia** pausa a orientação.

Fechar ou pausar salva etapa e rascunho localmente. Reiniciar o app oferece retomada
sem abrir formulários automaticamente. O rascunho é gravado após 350 ms sem alteração
e imediatamente ao pausar/fechar. A tarefa criada fica associada à jornada; uma
retomada abre seu contexto, inclusive se a preparação ocorreu com o guia pausado.
Se a tarefa foi removida/arquivada, a retomada explica isso e inicia nova preparação.

Concluir o guia não aprova contexto/plano, não envia ao executor e não inicia
execução. Essas ações mantêm os controles e confirmações existentes.

## Estados e ações

A prioridade do mini é decisão → impedimento/erro → parcial → resultado pronto →
execução → repouso. Durante o ensino, usa a pose de guia, exceto quando uma decisão
ou impedimento precisa de atenção. Cores são acompanhadas por texto, ícone e ação.

- Contexto/plano aguardando usuário: abre a seção correspondente da tarefa.
- Operação preparada: abre Decisões filtrada para essa tarefa.
- Resultado: abre relatório ou alterações; parcial pede conferência.
- Impedimento: abre a conversa com o contexto do problema.
- Em execução: abre o acompanhamento da tarefa.
- Sessão Codex: abre a sessão pelo destino já usado no app.
- Sessão Claude: abre a central existente.

Tarefas arquivadas/canceladas/encerradas não mantêm alertas. Estados antigos ou sem
conexão são identificados. Não há polling novo nem mudança de autorização.

## Organização dos arquivos

- `Stores/FirstTaskJourney.swift`: progresso persistido e entrada/retomada.
- `Views/Guide/FirstTaskStep.swift`: etapas e textos.
- `Views/Guide/GuideCoachCard.swift`, `GuideCoachHost.swift`, `GuideSpotlight.swift`: dica, geometria e alvo.
- `Views/Guide/FirstTaskJourneyEntry.swift`, `RunJourneyCoach.swift`: entradas e contexto.
- `Views/NewRun/NewRunJourney.swift`: integração do formulário com ações reais e rascunho.
- `Views/Mascot/MascotActivity.swift`, `MascotActivityRow.swift`: prioridade e ações.
- Integrações em `AppStore`, `FrondaCommands`, `FrondaMascot`, `MascotCompanionController`,
  `MascotCompanionPopover`, `GuideView`, `ContentView`, `NewRunView`, `NewRunDraft`,
  `NewRunConfiguration`, `NewRunSourceSection`, `RunWorkspace`, `ContextView`, `DecisionsView`.

Sem dependências, testes ou mocks novos. O armazenamento usa as preferências locais
já empregadas pelo app. Texto do rascunho permanece no Mac até a ação normal de envio.

## Verificação observada

- Build universal Debug pelo script oficial; aplicativo assinado e inicializado.
- Lint estrito e `git diff --check` sem ocorrências. A suíte existente de 42 testes
  passou nesta etapa (`./script/validate.sh --unit-only`); nenhum teste novo foi criado.
- Interface nativa: escolhas confirmadas, objetivo vazio impedindo avanço, avanço
  após preencher e sair do objetivo, pular orientação sem criar tarefa, pausa/saída,
  retomada de etapa e texto após reiniciar o app, repetição após conclusão.
- Mascote animado visível tanto na dica do formulário quanto na página Contexto.
  A dica usa uma superfície `NSHostingView` própria para compor corretamente o
  personagem Metal com o material do cartão sobre a sheet. Usa o tema da tela.
- Preparação real de uma tarefa de conferência: a jornada acompanhou a criação até
  o contexto disponível e exibiu conclusão sem aprovar contexto/plano ou iniciar
  provider. A tarefa de conferência foi cancelada ao terminar, preservando histórico.
- Mini companheiro: decisão nativa apareceu antes da sessão Codex em execução;
  **Abrir decisão** levou diretamente ao contexto daquela tarefa.

A conferência não iniciou execuções pagas nem provocou falhas em tarefas reais
para gerar os estados erro, parcial e sucesso. As regras desses estados foram
revisadas no código. VoiceOver falado, conforto das dicas em diferentes telas e
modo escuro/Reduzir Movimento nesta jornada precisam da conferência de uso; não
foram tratados como resultados observados. O XCUITest completo não foi executado.
