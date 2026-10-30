# Mascote Fronda — assets raster

Quatro poses individuais em PNG RGBA 1254 × 1254, geradas com referência visual e inspecionadas: `master.png`, `welcome.png`, `focus.png` e `rest.png`.

## Identidade preservada

Cinco ramos com pontas pendentes, marfim no topo e caramelo na base, dois pés e olhos pequenos. O personagem não recebe braços humanos, mãos, roupas ou adereços. Acolhimento e foco se expressam por inclinação dos ramos; repouso usa olhos fechados e ramos baixos.

## Fontes originais e acabamento final

Os PNGs nesta raiz são fontes originais da geração, preservadas com seus resíduos de alpha. **Use os arquivos em `exports/` para produção:** a máscara externa foi normalizada, com antialiasing, sem repintar o interior do personagem. Os recortes finais foram compostos sobre fundo escuro e revisados visualmente. A evidência está em `../qa/alpha-export.json` e `../qa/mascot-dark-proof.png`. A segunda tentativa nativa de limpeza está preservada em `master-cleanup-attempt.png` e não foi adotada; o original também está em `master-v1.png`.

A resolução entregue pela ferramenta é 1254 px, embora 1536 px ou mais tenha sido pedido. Não houve ampliação artificial. Os PNGs são poses estáticas, sem rig, camadas de animação ou modelo 3D.

## Rastreabilidade

Prompts completos em `prompts/`, referências e arquivos fonte em `generation-manifest.json`, análise objetiva de alpha em `alpha-inspection.json`. Nenhum código do app foi modificado.
