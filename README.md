# Fronda

Aplicativo nativo de macOS para executar, orientar e revisar agentes de programação em worktrees isoladas, com contexto inspecionável e evidências vinculadas à revisão dos arquivos.

O Fronda abre em uma conversa. Envie mensagens, anexe arquivos e escolha o modelo e o esforço para cada envio. Para pedir mudanças em um repositório, selecione a pasta no controle **Conversar**. As etapas, o grafo e as decisões aparecem junto à mensagem que iniciou o trabalho.

A implementação local está disponível. **A primeira distribuição ainda não satisfaz todos os critérios de aceite**: Claude não foi autenticado, as integrações remotas não foram exercitadas com contas reais e a distribuição Developer ID/notarizada não foi produzida. O [relatório de QA](docs/QA.md) diferencia o que passou, o que é parcial e o que não foi executado.

## Abrir e compilar

Requisitos: macOS 15+, Xcode com SDK macOS compatível com Swift 6 e Command Line Tools configuradas. O desenvolvimento foi validado em macOS 27 e Xcode 27.

```sh
./script/build_and_run.sh
# Somente compilar e empacotar:
./script/build_and_run.sh --build-only
```

O resultado está em `dist/Fronda.app`. O botão **Run** do Codex usa o mesmo script. O projeto Xcode é gerado por `script/generate_xcode_project.py`, sem XcodeGen/Tuist. Não há pacotes Swift remotos; os parsers C têm revisões fixadas em `Vendor/CTreeSitter/manifest.json`.

Para abrir a interface com os projetos de referência usados nesta validação local:

```sh
open -n dist/Fronda.app --args --fronda-data-root "$PWD/.qa/runtime"
```

O bundle de desenvolvimento em `dist` mantém suas conversas em `~/Library/Application Support/Fronda Development/`, em uma pasta própria de cada checkout. Assim, o app instalado e a cópia local podem funcionar lado a lado. O app instalado continua usando `~/Library/Application Support/Harness`. A opção `--fronda-data-root` tem precedência nos dois casos.

## Validação automatizada

```sh
./script/validate.sh             # lint, XCTest, XCUITest, build e assinatura Developer ID
./script/validate.sh --unit-only # lint + XCTest; não substitui o ciclo completo
./script/lint.sh                 # falha também em avisos
./script/lint.sh --fix           # normaliza apenas Swift próprio e testes
```

O lint usa o `swift-format` do Xcode. Os testes XCTest exercitam o coordenador e os provedores com processos reais e repositórios temporários. O XCUITest precisa de uma sessão gráfica desbloqueada e usa dados isolados.

## Primeiro fluxo

1. Abra **Nova conversa**, escreva uma pergunta e pressione Return. Shift+Return insere uma linha. Selecione modelo e esforço no campo de mensagem.
2. Anexe um arquivo pelo clipe ou arraste-o para o campo. O histórico inclui o texto extraído de documentos e PDFs. Imagens usam reconhecimento de texto local.
3. Para trabalhar em código, abra **Conversar**, escolha um projeto Git ou adicione uma pasta com pelo menos um commit. O envio inicia uma execução na worktree do Fronda.
4. Acompanhe no chat as ações do agente e os retornos das ferramentas. Expanda **Etapas** ou abra **Grafo** para inspecionar uma etapa, pausar ou retomar a execução.
5. No modo **Automático**, o Fronda segue com o trabalho e solicita sua decisão quando necessário. Escolha **Revisar antes** para aprovar o contexto e o plano.
6. Envie uma pergunta sobre o resultado. Para pedir outra alteração, selecione o projeto novamente. O Fronda preserva a worktree, os resultados anteriores e o grafo correspondente a cada envio.

As configurações de acesso e verificações de cada repositório ficam em **Ajustes → Projetos**. O coordenador pode continuar trabalhando com a janela fechada. A instalação do app e a autenticação dos provedores são locais.

## CLI

```sh
./dist/fronda projects
./dist/fronda project add /caminho/para/repo
./dist/fronda create MeuProjeto 'Corrigir a saudação' \
  --runbook 'Corrigir bug' --provider Codex --scope src/greet.ts \
  --budget 128000 --criterion 'Nome vazio usa o valor padrão'
./dist/fronda inspect RUN_ID
./dist/fronda approve-plan RUN_ID SEQUENCIA_REVISADA
./dist/fronda validate RUN_ID
./dist/fronda export RUN_ID
```

`--root DIRETORIO` mantém um ambiente separado. A CLI e o app usam o mesmo coordenador por XPC e as mesmas políticas. `fronda help` lista os demais comandos; `fronda rpc` aceita um `RPCRequest` JSON pelo stdin.

## Providers e conexões

Codex usa App Server, ferramentas dinâmicas e sandbox de leitura; as edições passam pelo broker. Claude usa `--restricted`, ferramentas internas desativadas e um MCP exclusivo do Fronda. A autenticação é feita pelos CLIs oficiais; o Fronda não abre seus arquivos privados. Pausa/retomada é um checkpoint do workflow com nova tentativa; sessões de provider são efêmeras e a continuidade nativa não é anunciada.

O consumo acumulado pode ser muito maior que o tamanho do Context Pack: inclui o contexto de sistema e chamadas do provider. A estimativa de payload usa UTF-8/4 e não é somada ao consumo reportado. Ao observar o teto, o coordenador interrompe a sessão e bloqueia novas etapas; consumo já ocorrido não pode ser desfeito.

Ajustes → Integrações oferece GitHub App Device Flow, Jira OAuth 3LO com App próprio e token previamente autorizado. A configuração do App/escopos pertence à conta do usuário. Tokens e refresh tokens ficam no Keychain. Consulte [integrações e distribuição](docs/OPERATIONS.md) antes de conectar.

## Arquitetura e limites

[Implementação e inventário](docs/IMPLEMENTATION.md) · [QA observado](docs/QA.md) · [Operação e distribuição](docs/OPERATIONS.md) · [Especificação recebida](docs/SPEC.md).

O Fronda não declara confinamento completo de processos de terceiros. Projetos que exigem isolamento forte bloqueiam a execução quando essa garantia não é demonstrada. Binários, credenciais, sessões, bancos de apps, diretórios privados e logs brutos são excluídos do contexto. Screenshots usam OCR local; os pixels não são enviados.

## Identidade Fronda e compatibilidade

O produto usa a logo e o mascote aprovados da direção Fronda v3, paleta musgo/marfim/argila e símbolo monocromático próprio na barra de menus. Os assets de produção ficam em `Resources/`; o visual claro/escuro é definido por `FrondaTheme`.

O app é entregue como `dist/Fronda.app` e a CLI local como `dist/fronda`. O bundle ID `com.harness.app`, o executável interno `Harness`, o coordenador, os módulos Swift, a raiz `Application Support/Harness`, os nomes de ferramentas MCP e os identificadores persistidos continuam compatíveis. Isso preserva dados, Keychain, integrações e automações. `harness://` e `--harness-data-root` seguem aceitos; novos links usam `fronda://`. O build mantém aliases locais `dist/Harness.app` e `dist/harness` para hooks e launchd existentes.
