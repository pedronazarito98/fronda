# Fronda — logo final da direção v3

O lettering aprovado é a matriz desta entrega. O f ramificado, as seis letras, o a de dois andares, as superfícies musgo, as bordas marfim, as lamelas argila e a iluminação são provenientes da imagem original, sem redesenho ou recoloração.

## Arquivos

- `master/fronda-logo-original.png`: composição original aprovada, 1920 × 819 px, com fundo e sombra de estúdio. Cópia idêntica à v3.
- `master/fronda-logo-transparente.png`: mesma matriz e mesmos valores RGB, com alpha para isolar as seis letras. Mantém o enquadramento original.
- `web/fronda-logo-{320,640,960,1280,1920}.png`: exportações proporcionais transparentes. Selecione pelo menos 2 pixels de imagem por pixel de exibição em telas Retina.
- `preview/fronda-logo-light.png` e `preview/fronda-logo-dark.png`: provas sobre marfim #EEE8DA e terra escura #211F1B; a logo não é recolorida entre modos.
- `source/wordmark-aprovado-v3.png`, `source/mascara-alpha.png` e `source/export-logo.swift`: matriz, máscara e processo reproduzível.
- `qa/fidelidade.json`: comparação dos canais RGB do original com o master transparente.
- `review-board.html`: apresentação, comparação de fundo e tamanhos reais.

## Uso

Preserve a proporção 1920:819 e o espaço livre do arquivo. Não estique, incline, acrescente contornos, sombras, glow ou filtros sobre a logo. A luz e o relevo já pertencem à arte.

Prefira fundos uniformes marfim ou terra escura. A mesma arte colorida é usada nos dois modos. Em fotografias ou superfícies muito movimentadas, reserve uma área uniforme. Evite musgo escuro como fundo, pois reduz a separação do corpo das letras.

Como ponto inicial, use a assinatura completa a partir de 240 px de largura de canvas, preferencialmente 320 px ou mais quando a textura importa. Para espaços pequenos, use o ícone Fronda já aprovado. Revise a escala no contexto real da interface antes da integração.

## Fidelidade e limites

A comparação verifica RGB idêntico, diferença máxima zero, no master de 1920 × 819. O alpha é novo: as bordas semitransparentes e a retirada da sombra no chão mudam a composição sobre outros fundos. Isso não significa identidade de pixels na imagem já composta sobre outro fundo. As exportações reduzidas usam interpolação de alta qualidade e naturalmente perdem microdetalhes.

A máscara foi obtida com Vision e suavizada na borda. O pacote contém arte raster, não uma fonte, malha 3D ou vetor com curvas editáveis. Não foi ampliada artificialmente nem prometida resolução ilimitada. A fonte original permite aproximadamente 16,3 × 6,9 cm a 300 ppi para o canvas completo.

Uma tentativa com image_gen foi descartada porque mudou detalhes da referência. Ela permanece somente na pasta local `qa/`, fora do ZIP de produção. O master final usa exclusivamente a matriz aprovada.

## Verificação

- RGB do master comparado por pixel com a matriz aprovada.
- Transparência e contraformas das seis letras inspecionadas.
- Provas claras, escuras e tamanhos reduzidos revisados.
- Nenhuma integração da logo no app nesta etapa; ícone anterior preservado.
- Testes, lint e build do app não executados nesta etapa de produção gráfica.

## Reprodução

No macOS: `xcrun swift source/export-logo.swift /caminho/absoluto/fronda-logo-final`.
O script usa AppKit, Core Image e Vision do sistema, sem dependências novas no aplicativo.
