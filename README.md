# Fronda

Aplicativo nativo de macOS para executar, orientar e revisar agentes de programação em worktrees isoladas, com contexto inspecionável e evidências vinculadas à revisão dos arquivos.

A [experiência V2](docs/V2-EXPERIENCE.md) torna o fluxo da tarefa visível e interativo: clique nas etapas para conferir contexto, diagnóstico, plano, alterações, validações e evidências; veja o que depende de você e volte à etapa atual para acompanhar a execução. Criação de tarefas, busca, inspector e janelas nativas apoiam esse trabalho; atalhos complementam os controles visíveis. A interface mantém a identidade Fronda e usa recursos do macOS 27 com compatibilidade a partir do macOS 15. A validação local da V2 passou por lint, testes existentes, build universal e conferência visual; os limites estão no relatório da experiência.

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

O diretório `.qa` é isolado, ignorado pelo Git e não faz parte de uma instalação nova. Na abertura normal, os dados ficam em `~/Library/Application Support/Harness`.

## Validação automatizada

```sh
./script/validate.sh             # lint, XCTest, XCUITest, build e assinatura ad hoc
./script/validate.sh --unit-only # lint + XCTest; não substitui o ciclo completo
./script/lint.sh                 # falha também em avisos
./script/lint.sh --fix           # normaliza apenas Swift próprio e testes
```

O lint usa o `swift-format` do Xcode, com quatro espaços e limite de 120 colunas. `Vendor` fica fora da formatação. Os testes XCTest usam processos reais e repositórios temporários. O XCUITest usa o app, helper e CLI reais, com dados isolados preparados pelas ações do scheme `Harness`; também pode ser executado com **⌘U** no Xcode. Nenhuma tentativa é enviada a um provider nem há publicação remota.

XCUITest precisa de uma sessão gráfica desbloqueada e assume o foco do app durante a execução. Os resultados ficam em `.build/qa/run-*/unit.xml` e `Harness.xcresult`. Os projetos e coordenadores temporários são removidos ao fim do teste; depois de uma interrupção forçada, `python3 script/ui_test_fixtures.py cleanup` remove apenas essas fixtures. A validação completa termina empacotando `dist/Fronda.app` pelo script canônico.

## Primeiro fluxo

1. Adicione uma pasta com repositório Git e pelo menos um commit. Confira as permissões e aprove os comandos literais de validação no projeto.
2. Crie uma run, selecione runbook/provider/escopo e critérios. A escrita usa uma worktree exclusiva, sem transportar alterações locais não commitadas.
3. Confira plano, arquivos, orçamento, destino e **Payload exato**. Aprove o envio para iniciar o provider.
4. Inspecione diff, gates, parecer independente, critérios e revisão. Mudanças posteriores invalidam as evidências do snapshot anterior.
5. Exporte o pacote com manifesto e hashes. Commit, push, PR e Jira são propostas separadas, com confirmação individual.

O app pode ser fechado enquanto o coordenador continua. **Sair e parar runs** interrompe as execuções. Iniciar no login é opcional. Não há telemetria de produto.

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
