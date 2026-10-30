# Fronda — pacote completo de identidade digital v2

Esta entrega consolida nome, f ramificado, mascote e paleta em arquivos utilizáveis. A aparência principal recupera volume, textura e calor; as reduções vetoriais existem como apoio para reprodução e escala pequena. O código e o nome instalado do aplicativo não foram alterados.

## Comece por aqui

1. Abra `manual/Fronda-Brand-Book.pdf`: manual de 17 páginas com regras e aplicações.
2. Abra `review-board.html` no navegador: prévia dos arquivos finais.
3. Use `logos/wordmark-primary-light.png` ou `wordmark-primary-dark.png` para apresentações e comunicação. Os nomes light/dark indicam o fundo de destino.
4. Use os arquivos em `mascot/exports/` para compor peças. Os PNGs na raiz de mascot são fontes originais, preservadas para rastreabilidade.

## Conteúdo

| Pasta | Conteúdo e uso |
|---|---|
| `logos/` | Assinatura principal clara/escura em PNG e SVG híbrido; símbolo principal; assinaturas e símbolos reduzidos em SVG puro; variantes técnicas de uma cor. |
| `icons/macos/` | `.icns`, `.iconset` e `AppIcon.appiconset`, com 10 slots de tamanho/escala. |
| `icons/liquid-glass-layers/Fronda.icon/` | Projeto nativo, editável no Icon Composer, com haste e duas ramificações em camadas. |
| `icons/liquid-glass-layers/` | SVGs independentes de cada camada e fundo, para continuidade. |
| `icons/web/` | PNGs de 16 a 1024 px, favicon SVG/ICO e apple-touch-icon. |
| `mascot/exports/` | Presença, acolhida, atenção e repouso, com fundo transparente e margem preservada. |
| `social/` | Quatro peças em PNG e SVG editável: 1080², 1080×1350, 1080×1920 e 1200×630; dois avatares 512². |
| `system/` | Paleta, tokens claro/escuro, cores semânticas, espaçamento, tipografia, contraste e gesto CSS com redução de movimento. |
| `preview/` | Aplicações visuais de produto em claro/escuro e provas de apresentação. São exemplos estáticos. |
| `manual/` | Manual PDF e guia textual editável. |
| `source/`, `licenses/` | Fontes tipográficas, licenças, contornos, composição e scripts de exportação. |
| `qa/` | Evidências de exportação e relatório de verificação. |

## O que é vetorial e o que é raster

- **SVGs `reduced` e `single-color`:** curvas vetoriais puras, sem bitmap ou fonte externa.
- **SVGs `primary`:** contornos vetoriais para `ronda` e PNG do f incorporado. Preservam o material; não são vetores puros. Usar até a resolução útil do elemento raster.
- **Social SVG:** composição e textos editáveis, fontes incorporadas e recortes PNG incorporados. Para editar texto em um software que ignore fontes embutidas, instalar DM Serif Display e Inter, incluídas com suas licenças.
- **Mascote e símbolo com textura:** imagens raster de 1254 px na origem. Há quatro poses; não há malha 3D ou rig articulado.
- **Ícone nativo .icon:** geometria reduzida em camadas; luz, translucidez e máscara são interpretadas pelo Icon Composer. Não deve receber um tile PNG por cima de outro tile.

## Regras essenciais

Preservar a proporção da assinatura. O f faz parte da palavra; não duplicá-lo com outro símbolo ao lado. Manter área livre igual a um quarto da altura visível do f. Preferir a assinatura principal acima de 240 px de largura e o mascote acima de 128 px, com 256 px ou mais em comunicação. Para microícones, usar a exportação técnica específica.

A aparência de uma cor é uma adaptação técnica, não a comunicação principal. Não substituir o material por clipart plano em peças de apresentação. O arquivo nativo de ícone e o render texturizado são adaptações da mesma forma a meios diferentes.

Claro: fundo marfim e musgo profundo para leitura/ação. Escuro: superfícies casca e texto marfim; ações em musgo claro. Não usar musgo médio ou argila como texto pequeno sem conferir contraste. Estados de erro, alerta e sucesso usam os tokens semânticos e sempre têm texto/ícone de apoio.

## Para integrar no app

Escolher o fluxo de ícone adequado ao projeto: o `.icon` para Icon Composer, ou o catálogo/.icns no fluxo clássico. Importar em etapa própria, conferir aparências e executar o app no Dock. Não utilizar simultaneamente os dois fluxos sem definir a precedência no projeto.

Aplicar materiais nativos de Liquid Glass na navegação, preservar superfícies de leitura e respeitar Reduce Transparency/Reduce Motion. Os tokens entregues são especificação de marca, não uma migração automática do design system.

## Reprodução

Os scripts em `source/` geram exportações e composições a partir dos masters incluídos, sem modificar o app. Dependências de produção: Python com Pillow, NumPy e ReportLab; `iconutil` e Icon Composer no macOS. Não foram adicionadas dependências ao projeto.

Ordem: `normalize-exports.py`, `export-assets.py`, `build-system.py`, `export-icons.py`, `build-layouts.py`, `build-manual.py`. A finalização do `.icon` foi conferida no aplicativo nativo. Alterações em camadas SVG devem ser sincronizadas com a pasta Assets do .icon antes de reabrir.

## Escopo

Kit digital em sRGB, não prova de impressão. Nenhuma peça foi publicada. Não foram produzidos vídeos, rig 3D ou campanha em veiculação. O material permite essas próximas produções usando o mesmo personagem e linguagem. Validação em Dock, em hardware de diferentes densidades e sobre Liquid Glass real do app permanece como parte da integração.
