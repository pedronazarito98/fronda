# Fronda — ícone final

A arte aprovada da direção v3 é a fonte definitiva. Não houve nova geração, reconstrução da forma, retoque de textura, recoloração ou alteração de luz. A mudança foi a transparência fora do contorno e o enquadramento/redimensionamento exigido pelas exportações.

## Arquivos de produção

- `master/Fronda-original-rgba.png`: master transparente em 1254 × 1254, com todos os valores RGB idênticos aos da referência.
- `master/Fronda-1024.png`: canvas 1024 × 1024; ícone centralizado com área útil de aproximadamente 824 px.
- `macos/Fronda.icns`: dez representações de 16 a 1024 px.
- `macos/AppIcon.appiconset/`: catálogo para Xcode, com dez arquivos e Contents.json.
- `macos/Fronda.iconset/`: fonte clássica do .icns.
- `web/`: PNGs de 16, 24, 32, 48, 64, 128, 256, 512 e 1024 px; favicon.ico.
- `source/Fronda-Compositing.blend`: composição 2D editável no Blender 5.2, com original e máscara incorporados. Não é um modelo 3D.
- `source/approved-icon.png`: referência aprovada intacta.
- `preview/` e `review-board.html`: comparação e conferência de tamanhos.

## Fidelidade

O master em resolução original preserva exatamente os valores RGB de todos os pixels da fonte. Somente o canal alpha é novo: isola o objeto, remove o fundo creme e a sombra projetada da cena, com antialiasing no contorno externo. As sombras, luz e textura dentro do ícone permanecem as da referência.

As exportações menores usam Lanczos, sem sharpening, recoloração ou nova ilustração. Portanto a identidade visual é mantida, mas uma imagem de 16 px não contém a mesma quantidade de detalhe do original. Não foi criada uma versão simplificada diferente.

## Decisão sobre Icon Composer

O documento .icon foi aberto e renderizado pelo Icon Composer instalado. Mesmo com a camada raster sem vidro e o preenchimento configurado como None ou totalmente transparente, a exportação macOS adicionou uma base que mudou a silhueta. Esse resultado não atende à exigência de aparência exata.

Por isso os arquivos finais recomendados são .icns / AppIcon.appiconset e PNG. Os experimentos do Icon Composer ficaram em `qa/` no workspace, identificados como não fiéis e excluídos do ZIP de produção. Eles não devem substituir o master. O caminho Apple para imagens pré-renderizadas foi consultado em https://developer.apple.com/videos/play/wwdc2026/8012/ e https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer .

## Verificação executada

- PASS: fonte aprovada preservada por hash; diferença RGB máxima do master = 0.
- PASS: PNGs, dimensões e transparência verificados; contorno revisado sobre fundos claro e escuro.
- PASS: .icns reaberto em dez representações; RGB dos pixels opacos e alpha preservados em todos os tamanhos. Duas representações legadas alteram RGB de pixels não opacos na codificação; as demais são integralmente idênticas.
- PASS: Blender salvou e renderizou a composição; arredondamento máximo de 1/255 nos pixels opacos, por conversão de espaço de cor. O PNG final usa o master determinístico, não esse render.
- NOT-RUN: integração no aplicativo, aparência no Dock do aplicativo real, testes, lint e build do app. Nenhum código do app foi alterado.

## Validar na integração

Conferir o ícone no Dock e no Finder em 1×/2× e nas aparências de ícone escolhidas pelo sistema. Modos de ícones tingidos/monocromáticos do macOS podem substituir as cores por escolha do usuário. Evitar qualquer reconstrução vetorial automática ou aplicação de efeitos sobre a arte.

## Reprodução

No macOS: `extract-matte.swift` usa Vision para obter a máscara; `export-icon.py` usa Pillow e NumPy para normalizar a máscara e exportar, e iconutil para .icns. `build-blender.py` cria a composição no Blender. Dependências de produção não foram adicionadas ao aplicativo.
