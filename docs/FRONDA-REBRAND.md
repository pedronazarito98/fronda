# Fronda — integração da identidade no produto

Verificado em 26/09/2026.

## Alterações

- Nome apresentado pelo macOS, menus, ajustes, central de sessões, textos da interface, mensagens ao usuário, ajuda do CLI e documentação operacional: Fronda.
- Pacote local: `dist/Fronda.app`. Comando: `dist/fronda` e `Fronda.app/Contents/Helpers/fronda`.
- Logo e mascote originais aprovados incluídos no pacote, com carregamento explícito pelo bundle. Nenhuma imagem foi regenerada.
- Paleta adaptativa de musgo, sálvia, marfim e terra nas superfícies, navegação e ações. Cores semânticas de estado foram preservadas.
- Ícone aprovado do Dock e símbolo fino do menubar preservados.
- Novos links usam `fronda://`; links antigos `harness://` continuam aceitos.

## Arquivos principais

| Área | Arquivos |
| --- | --- |
| Assets | `Resources/Fronda.icns`, `FrondaWordmark.png`, `FrondaMascot.png`, `FrondaBrand.md` |
| Componentes | `Sources/HarnessUI/Components/FrondaAssets.swift`, `FrondaWordmark.swift`, `FrondaMascot.swift`, `FrondaTheme.swift`, `DesignPrimitives.swift` |
| Identidade do app | `Resources/Info.plist`, `Sources/HarnessUI/App/HarnessApp.swift`, `FrondaMenuBarIcon.swift` |
| Interface | Sidebar, ContentView, CommandCenter, CommandPalette, Settings, RunWorkspace e views que consomem o tema, incluindo a central de sessões |
| Textos e links | CLI, stores de UI e mensagens ao usuário em Core, Domain, IPC, Infrastructure e Providers |
| Empacotamento | `script/generate_xcode_project.py`, `build_and_run.sh`, `release.sh`, `validate.sh`, projeto e scheme Xcode |
| Documentação | `README.md`, `docs/OPERATIONS.md`, `EXTENSIONS.md`, `SESSION-ISLAND.md` |

## Compatibilidade

Os módulos Swift, identificadores `com.harness.*`, executáveis internos, pasta de dados, chaves persistidas e nomes de ferramentas de integração mantêm os identificadores existentes. Isso evita invalidar permissões, dados e integrações durante a mudança de marca. O argumento antigo `--harness-data-root` continua aceito ao lado de `--fronda-data-root`.

O empacotamento mantém aliases locais para `dist/Harness.app` e `dist/harness`. Hooks existentes não foram reescritos; marcadores de integração e de reconciliação foram preservados. Nenhuma dependência nova, migração de banco ou publicação foi realizada.

## Validação observada

| Verificação | Resultado |
| --- | --- |
| SwiftLint estrito | PASS |
| Build SwiftPM e 42 testes XCTest existentes | PASS — `.build/qa/run-ESGTNu/unit.xml` |
| Build Xcode e abertura de `Fronda.app` | PASS |
| Assinatura local `codesign --verify --deep --strict` | PASS |
| Sintaxe dos scripts e `git diff --check` | PASS |
| Ajuda do comando `dist/fronda` e alias interno | PASS |
| Logo e mascote idênticos às matrizes aprovadas, por SHA-256 | PASS |
| Inspeção nativa de tela inicial e ajustes nos temas claro/escuro | PASS |
| Navegação de projetos e tarefas; coordenador conectado | PASS |
| XCUITest automatizado | NOT-RUN nesta alteração |
| Release assinada/notarizada, Intel físico, VoiceOver e execução real com provider | NOT-RUN nesta alteração |

Capturas reais: `output/brand-kit/fronda-product-qa/light.png`, `dark.png` e `settings-dark.png`. A preferência de aparência foi restaurada para **Sistema** ao terminar.

## Conferência manual restante

1. Avaliar a presença da marca durante o uso cotidiano, principalmente a logo no tamanho real, o Dock e o menubar.
2. Com um projeto real, percorrer uma execução e suas evidências nos dois temas; os testes existentes passaram, mas não foi iniciada uma execução com provider para validar esta alteração visual.
3. Antes de distribuir uma versão, executar o fluxo completo de XCUITest e release, incluindo notarização e validação em outra máquina.
