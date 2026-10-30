# Fronda — assets de produção

- `Fronda.icns`: ícone aprovado e conferido no Dock.
- `FrondaWordmark.png`: master transparente da logo v3, 1920 × 819. SHA-256: `510fbcd5f11a26ac34f2796f81316fc3516e7ffb03b1137da2936c2f3699ef89`.
- `FrondaMascot.png`: imagem aprovada do mascote v3, 1254 × 1254. SHA-256: `fbf13659e3981d9bfdb97b1568c05700e3d83ae35e09dbbb20d542f37e3cbf25`.

Os PNGs foram copiados das matrizes aprovadas, sem regeneração, recoloração ou retoque. A logo é raster: a interface reduz sua resolução de exibição e preserva a proporção. O mascote usa a cena original completa; a aplicação não inventa poses ou altera sua anatomia.

O símbolo do menubar é uma adaptação vetorial de traço fino aprovada pelo usuário, definida em `Sources/HarnessUI/App/FrondaMenuBarIcon.swift`. É template para respeitar a aparência do sistema. Não substitui o ícone colorido do Dock.

`FrondaTheme` centraliza a paleta adaptativa: musgo nas ações claras, sálvia nas escuras, marfim e terra nas superfícies. Cores semânticas de erro, atenção e sucesso continuam distintas da identidade da marca.
