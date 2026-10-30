# QA visual — toolbar única e escolha dos painéis

Data: 28/09/2026. Plataforma: Fronda nativo para macOS, SwiftUI/AppKit.

## Escopo desta revisão

As duas capturas do Codex enviadas pelo usuário orientam esta revisão: abas na mesma linha da navegação, página de abertura espaçosa, escolha livre do conteúdo e troca dos lados. A identidade e as cores do Fronda foram preservadas. O registro anterior, mantido abaixo, documenta a primeira implementação e não define mais a posição das abas.

final result: passed

A comparação conjunta dos estados capturados não deixou diferenças P0, P1 ou P2 acionáveis dentro deste escopo. As limitações de cobertura manual estão descritas abaixo.

## Referências e evidências atuais

Arquivos em `output/workspace-chrome/`:

- `reference-1.png` (2912 × 1812) e `reference-2.png` (2904 × 1816): capturas originais fornecidas pelo usuário.
- `before.png`: versão com duas faixas no topo, antes desta revisão.
- `split-light.png` e `split-dark.png` (2908 × 1814): quadro e página de escolha lado a lado, toolbar única e controle central de troca.
- `swapped-search.png`: busca “Nebula” mantida no painel após trocar os lados.
- `compact.png` (1742 × 1846, 871 pontos de largura): página de escolha e seletor compacto de painéis.
- `tabs-overflow-before.png`: botão de adição fora da área visível quando rolava junto das abas.
- `tabs-overflow-final.png` (2940 × 1846): quinze abas, rolagem horizontal e botão de adição visível; clicar nele abriu a décima sexta aba.
- `workspace-final.png` (2940 × 1846): pacote final reaberto no workspace normal, com as duas abas originais, navegação lateral expandida e escolha de conteúdo ao lado da Home.
- `comparison-full.jpg`: referência e implementação reduzidas proporcionalmente à mesma largura de 1454 px e inspecionadas juntas.
- `comparison-details.jpg`: comparação legível da toolbar, opções de abertura e botão central de troca. Os recortes preservam os pixels das capturas; não há interface reconstruída.

As capturas nativas são Retina 2×. O produto é nativo: não há CSS ou console web para conferir. O cenário de QA usa os três projetos e seis tarefas preexistentes. O Codex possui ferramentas próprias de navegador/terminal; no Fronda as opções são páginas, projetos e tarefas realmente disponíveis.

## Correções e decisões

1. Removida a faixa adicional de abas. `WorkspaceTabBar` agora ocupa o item principal da toolbar compacta da janela; histórico e ações ficam na mesma linha.
2. `+` e `⌘T` abrem a página de escolha. O botão de divisão abre essa mesma página no segundo painel, sem destino de execução predefinido.
3. A página reúne busca local, destinos em duas colunas, projetos e tarefas recentes. Mantém espaços amplos, superfícies discretas, tipografia de sistema e tokens claro/escuro existentes.
4. Cada painel oferece “Escolher conteúdo”. A troca central move as próprias instâncias de navegação, preservando histórico, estado de busca e foco; a proporção física das colunas permanece.
5. Adicionada ajuda nativa nos controles de abas, toolbar, painéis, menus dos cards e navegação da tarefa. Descrições conferidas na árvore de acessibilidade; o tempo de aparecimento segue o macOS.
6. Corrigido o desaparecimento do `+` em excesso de abas: o botão fica fora da área rolável, junto ao fim das abas quando há espaço. O item da toolbar aceita redução de largura.

## Interações conferidas nesta revisão

- Criar aba por atalho e por clique no `+`, inclusive com quinze abas já abertas.
- Abrir divisão sem conteúdo presumido; escolher projeto no painel direito sem substituir o esquerdo.
- Trocar esquerda/direita, voltar pelo histórico do painel em foco e preservar busca preenchida.
- Abrir nova escolha pelo cabeçalho do painel e manter acesso ao destino anterior pelo histórico.
- Arrastar o divisor; a largura acompanhou o gesto.
- Alternar temas claro/escuro e restaurar a preferência Sistema.
- Conferir modo compacto, fechar/reabrir abas e restaurar a sessão após reiniciar.

A captura compacta antecede o último ajuste de largura do item da toolbar; o excesso de abas foi reconferido na janela ampla após esse ajuste. Não houve medição de latência física de trackpad nem sessão completa de VoiceOver. As ajudas foram conferidas pelo contrato nativo e pela acessibilidade, sem cronometrar o hover.

## Verificações desta revisão

- `./script/build_and_run.sh --build-only`: pacote gerado após as alterações finais de layout.
- `./script/lint.sh`, `git diff --check` e `codesign --verify --deep --strict dist/Fronda.app`: código 0 após as alterações finais de código.
- Seis testes de UI existentes aprovados em `.build/qa/workspace-chrome-final.xcresult`. Após o último ajuste de largura, a suíte foi repetida com sucesso em `.build/qa/workspace-chrome-verified.xcresult`: seis aprovados, zero falhas, ignorados ou avisos de execução. Três tentativas intermediárias expiraram na inicialização do executor; o processo `testmanagerd` travado foi reiniciado antes das execuções bem-sucedidas.
- Nenhum teste, mock ou dependência foi criado. Os testes unitários citados no registro abaixo pertencem à etapa anterior.

---

## Registro da primeira implementação — workspace, abas e Kanban

Data: 28/09/2026. Plataforma: aplicativo macOS nativo, SwiftUI com integração AppKit.

## Resultado visual

final result: passed

Não restaram diferenças visuais P0, P1 ou P2 acionáveis na comparação final dos estados capturados. Este resultado trata da comparação visual e dos controles inspecionados; não certifica latência física de trackpad nem substitui a avaliação subjetiva do arraste pelo usuário.

## Evidência e normalização

- Referência aprovada: `/Users/pedronazarito/.codex/generated_images/01a0e395-962f-7b82-9325-66ff7e8f3ee3/exec-5c9c78a6-0517-47ba-9db5-278a34f19197.png` (1586 × 992 px).
- Aplicativo renderizado: `output/workspace-ui/board-light-final.png` (2940 × 1846 px, captura Retina 2×; janela equivalente a 1470 × 923 pontos). As primeiras capturas usaram 1454 × 907 pontos; a última usou a janela ampliada nativa.
- Comparação conjunta: `output/workspace-ui/comparison-final.jpg`. Referência e implementação foram proporcionalmente reduzidas à mesma largura de 1454 px; redução de 49,46% para a captura Retina final. Nenhum conteúdo da interface foi reconstruído na captura.
- Comparação de detalhes: `output/workspace-ui/comparison-details.jpg`, recortes da referência e do aplicativo juntos, cobrindo cabeçalho, navegação e compositor.
- Tema escuro: `output/workspace-ui/board-dark-final.png`.
- Modo compacto: `output/workspace-ui/narrow-final.png` (1752 × 1552 px, 876 × 776 pontos) e `narrow-board.png`. Antes/depois do cabeçalho em `comparison-compact.jpg`.
- Estados adicionais: `model-picker.png`, `effort-picker.png`, `inspector-popover.png`, `plan-beside.png`, `home.png`, `home-organize.png`, `home-moved.png`, no mesmo diretório.
- Não há CSS, navegador ou console web neste produto. A densidade foi normalizada por pontos nativos do macOS.

Estado comparado: quadro de todos os projetos com uma tarefa aberta ao lado. A referência contém exemplos ilustrativos; o aplicativo mostra as seis tarefas preexistentes do ambiente local de QA. Seus nomes, número de tarefas em cada coluna, comprimentos dos textos e ações exigidas diferem. Não foram criados mocks para imitar o conteúdo da imagem.

## Histórico da comparação e correções

1. **[P1, corrigido] Cabeçalho encoberto no painel dividido.** A captura `board-light-initial.png` tinha uma camada do inspetor nativo sobre o título. A referência mantém título e ações legíveis. Em divisão, os detalhes passaram a usar um popover; a tarefa isolada preserva o inspetor. Evidência posterior: `board-light-final.png` e `inspector-popover.png`.
2. **[P2, corrigido] Divisão inicial em partes iguais.** `comparison-initial.jpg` mostra a implementação em 50/50 contra um quadro mais largo na referência. A restauração do divisor agora usa as `arrangedSubviews` do NSSplitView, com proporção inicial de 0,63. Evidência posterior: `comparison-final.jpg`; valor acessível de 880 pontos no quadro, em aproximadamente 1397 pontos disponíveis. A largura também foi ajustada para 760 e restaurada para 880 pelo controle acessível nativo.
3. **[P2, corrigido] Nova aba distante das abas existentes.** O botão de adição foi movido para junto das abas dentro da mesma área rolável. A seleção de novas abas mantém a aba visível. Evidência posterior: barra superior em `board-light-final.png`.
4. **[P2, corrigido] Restauração do workspace ao reiniciar.** A persistência das abas saiu do armazenamento de cena e passou ao armazenamento de preferências, com chave por raiz de dados explícita. Reinício observado restaurou duas abas, painel lateral e histórico. O estado de QA ficou separado do workspace principal.
5. **[P3, corrigido] Singular nas raias.** Projetos com uma tarefa agora mostram “1 tarefa”.
6. **[P1, corrigido] Mesmo problema de inspetor no modo compacto.** O redimensionamento real da janela revelou o cabeçalho encoberto também fora da divisão ampla. Os popovers agora cobrem todas as abas da janela principal; o inspetor nativo fica na janela própria da tarefa. Correção renderizada e comparada em `comparison-compact.jpg`.
7. **[P2, corrigido] Área do divisor difícil de arrastar.** O divisor podia ser ajustado pela acessibilidade, mas o arraste por coordenadas não deslocava o conteúdo. Foi adicionada uma alça de 10 pontos com indicação ao passar o cursor, sincronizada com o NSSplitView e com ajuste acessível. O gesto posterior alterou a largura de 880 para 763 pontos e retornou a 880; captura `divider-dragged.png`. O layout amplo foi recapturado em `board-light-final.png`.

## Superfícies de fidelidade

| Superfície | Conferência e decisão |
| --- | --- |
| Fontes e tipografia | Fonte de sistema do macOS, pesos moderados e hierarquia compacta. Título da tarefa legível, navegação sublinhada, textos dos cards limitados e conteúdo completo acessível na tarefa. A imagem conceitual não especifica uma fonte instalável; não foi introduzida uma fonte arbitrária. |
| Espaçamento e distribuição | Navegação lateral de 56 pontos, linhas discretas, cinco etapas, raias recolhíveis e proporção inicial 63/37. Cabeçalho da tarefa cresce para acomodar uma ação real pendente. O compositor permanece preso à base. |
| Cores e tokens | Paleta existente do Fronda preservada. Acento, aviso, sucesso, superfícies e bordas usam os tokens existentes. Claro e escuro foram capturados e inspecionados. |
| Imagens e identidade | Símbolos oficiais existentes reutilizados em PNG apropriado para Retina; ícones de ação usam SF Symbols. Nenhuma aproximação desenhada do logotipo foi criada. |
| Texto e conteúdo | Dados e resultados reais da tarefa; nenhum texto de briefing inserido como decoração. Etapas técnicas são agrupadas no quadro e estados como cancelamento permanecem explícitos. “Concluído” requer entrega encerrada. |

## Diferenças esperadas da imagem conceitual

- Na primeira implementação, as abas ficavam abaixo da toolbar. Esta diferença foi eliminada pela revisão descrita no início deste documento.
- Aprovações e próximas ações reais continuam visíveis. A referência não representava esses estados; ocultá-los para reduzir a altura prejudicaria o fluxo funcional.
- Contexto, Validação e demais áreas existentes continuam acessíveis. As opções adicionais não foram eliminadas para reproduzir três rótulos ilustrativos.
- O símbolo reaproveita a identidade já aprovada do aplicativo. A paleta original foi preservada conforme solicitado.
- O compositor envia orientações pelo contrato existente. Não foi adicionado um botão de anexo sem suporte funcional correspondente.
- Etapas do Kanban refletem execução e aprovação reais. Arrastar um card entre colunas para alterar o estado não faz parte desta entrega. Os gestos de organização/redimensionamento se aplicam aos cards da Home.

## Interações observadas

- Criar aba com ⌘T, fechar com ⇧⌘W e reabrir com ⇧⌘T.
- Restauração das duas abas e painel lateral após reiniciar o app.
- Abrir tarefa pelo card, acessar Plano, voltar para Conversa e abrir o plano ao lado; voltar no painel principal restaura o quadro.
- Alternar resumo fixado; as ações necessárias permanecem disponíveis.
- Abrir seletores separados de modelo e esforço e detalhes da tarefa em popover. A configuração de execução das tarefas existentes não foi alterada nesta conferência.
- Ajustar a largura pela acessibilidade e arrastar a alça de 880 para 763 pontos, retornando a 880; distribuição do quadro e quebra de linha acompanham o valor.
- Redimensionar a janela para 876 pontos de largura e alternar entre quadro e tarefa pelo seletor compacto, com título e controles legíveis.
- Com plano e conversa abertos lado a lado, ⌃⌘I abriu apenas o inspetor do painel em foco.
- Home: redimensionamento até 352 pontos, reorganização dos dois primeiros cards e desfazer cada gesto. A disposição original foi restaurada.
- Temas claro/escuro conferidos; preferência anterior de sistema restaurada no ambiente de QA.

## Limites da conferência manual

- Não foi medida latência de trackpad físico nem executada uma sessão completa de VoiceOver. Foram inspecionados os controles de acessibilidade e exercitados os gestos de arraste pela automação nativa.
- A conferência responsiva cobre as janelas ampla e compacta registradas; não representa uma captura de cada largura possível.
- Não foi enviado um novo pedido a um provider apenas para validar o visual. Os contratos de aprovação e execução existentes foram preservados.

## Checklist da implementação

- [x] Comparar referência e aplicativo na mesma imagem.
- [x] Inspecionar detalhes legíveis de cabeçalho, abas e compositor.
- [x] Corrigir os problemas visuais encontrados e recapturar.
- [x] Conferir claro/escuro e controles contextuais.
- [x] Preservar cores, dados, aprovações e conteúdo funcional existente.
- [x] Documentar o alcance das verificações, sem afirmar testes físicos não observados.

## Validação automatizada observada

- `./script/lint.sh`: concluído com código 0 após as alterações finais.
- `git diff --check`: concluído com código 0.
- `./script/validate.sh`: os 42 testes SwiftPM passaram; XML em `.build/qa/run-oTZThV/unit.xml`, sem falhas, erros ou testes ignorados. Os 42 testes de código do Xcode também passaram nessa rodada. A inicialização do executor de UI expirou, portanto a rodada inteira não foi reportada como aprovada.
- Repetição de `xcodebuild ... -only-testing:HarnessUITests ... test -quiet`: seis testes de UI passaram, zero falhas/ignorados. Após as correções finais de interação e modo compacto, repetidos novamente com sucesso em `.build/qa/workspace-ui-complete.xcresult`; resumo consultado com `xcresulttool`, seis aprovados e nenhum runtime warning.
- `./script/build_and_run.sh --build-only`: pacote final gerado. `codesign --verify --deep --strict dist/Fronda.app`: código 0.
- Não foram criados arquivos de teste, mocks ou dependências. As suítes e os ambientes de teste preexistentes foram utilizados.
