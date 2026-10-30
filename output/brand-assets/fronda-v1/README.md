# Fronda — kit de logo e ícone v1

> Revisão em 26/09/2026: esta execução foi rejeitada pelo usuário por “falta de vida”. Mantida como histórico. A nova exploração está em `../../brand-exploration/fronda-forma-viva-v4/`. Não tratar este kit como aparência final aprovada.

Finalização da direção do f ramificado aprovada em 25/09/2026. O f inicial e o símbolo do app compartilham as curvas e terminações do mascote. Esta entrega finaliza os arquivos da marca; não altera o app Harness.

## Arquivos

| Uso | Arquivo ou pasta |
|---|---|
| Assinatura em fundo claro | `svg/fronda-wordmark-light.svg` |
| Assinatura em fundo escuro | `svg/fronda-wordmark-dark.svg` |
| Símbolo completo | `svg/fronda-symbol-light.svg`, `svg/fronda-symbol-dark.svg` |
| Símbolo para 16–24 px | `svg/fronda-symbol-micro-light.svg`, `svg/fronda-symbol-micro-dark.svg` |
| Ícone macOS | `macos/Fronda.icns` |
| Catálogo importável no Xcode | `macos/AppIcon.appiconset/` |
| Origem do .icns | `macos/Fronda.iconset/` |
| Ícone vetorial | `svg/fronda-app-icon.svg`, `svg/fronda-app-icon-micro.svg` |
| PNG transparente | `png/` |
| PDF vetorial da assinatura | `pdf/` |
| Paleta | `palette.json` |
| Desenho e exportador | `source/build-assets.swift` |
| Comparação visual | `galeria.html` |

## Decisões de desenho

- F próprio desenhado com curvas Bézier. A copa e o ramo central têm duas terminações pendentes; a haste é contínua e curva para a esquerda na base.
- O f faz parte da palavra. Não combinar um símbolo adicional com a assinatura completa.
- As letras `ronda` partem da DM Serif Display Regular, convertidas em contornos pelo CoreText. A licença OFL e o arquivo original estão incluídos. Fonte oficial: https://github.com/google/fonts/tree/main/ofl/dmserifdisplay ; licença: https://raw.githubusercontent.com/google/fonts/main/ofl/dmserifdisplay/OFL.txt .
- Ajuste óptico entre f e r elimina a sobreposição do primeiro desenho. A textura gerada foi substituída por preenchimentos planos.
- Claro: haste e letras em musgo profundo; copa em pedra, ramo em argila. Pedra conserva a família terrosa e torna a copa mais visível que marfim sobre marfim.
- Escuro: haste em argila; ramos e letras em marfim. O ícone usa essa versão sobre musgo profundo.
- Os SVGs e PDFs contêm curvas, sem imagens embutidas ou texto que dependa de fonte instalada.
- PNGs gerados em sRGB com transparência real. No ícone, o fundo musgo está dentro de uma margem externa transparente.

## Tamanhos e aplicação

- Símbolo: versão micro em 16–24 px de altura; versão completa a partir de 32 px. Em contexto prioritário, preferir pelo menos 32 px.
- A versão micro reduz cada par de terminações a uma terminação larga. É ajuste óptico, não apenas redução do arquivo grande.
- Ícone: micro em 16–24 px; completo em 32 px ou mais. O slot macOS 16@2x também usa micro, pois ocupa 16 pontos em uma tela Retina.
- Assinatura: largura recomendada a partir de 180 px. Abaixo disso, preferir o símbolo; não foi realizada avaliação formal de reconhecimento com usuários.
- Respiro externo recomendado: pelo menos 25% da altura visível do f. Não esticar, aplicar contorno improvisado ou mudar as proporções entre as letras.
- Em vidro e fundos variáveis, usar o ícone com base musgo ou colocar a assinatura sobre uma superfície com contraste estável. Evitar a assinatura diretamente sobre conteúdo visual intenso.
- Dark/light descrevem o fundo de destino. Os arquivos transparentes não contêm o fundo de aplicação.
- `AppIcon.appiconset` contém todos os 10 slots tradicionais do macOS. A importação é um passo futuro; este pacote não altera nome, bundle identifier ou recursos do app.

## Reproduzir as exportações

No macOS, a partir da raiz do projeto:

```sh
swift output/brand-assets/fronda-v1/source/build-assets.swift output/brand-assets/fronda-v1
iconutil -c icns output/brand-assets/fronda-v1/macos/Fronda.iconset -o output/brand-assets/fronda-v1/macos/Fronda.icns
```

Usa AppKit, CoreGraphics e CoreText do sistema. Não adiciona dependências ao app. O script reexporta SVG, PNG, PDF e catálogos; não altera a galeria nem recompõe o ZIP.

## Escopo e validação manual

O mascote permanece na referência aprovada; não foi vetorizado ou animado nesta entrega. A paleta é da marca e não substitui os tokens da interface.

Validar a aparência no Dock após integração, especialmente 16 pontos em telas Retina e não Retina, e as aplicações sobre Liquid Glass real. Consultar `VERIFICACAO.md` para os controles já realizados. Nenhuma pesquisa adicional de disponibilidade de marca foi realizada nesta etapa.
