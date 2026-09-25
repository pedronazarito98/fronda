# Extensões e evidências no Harness

O coordenador seleciona extensões habilitadas por projeto, palavras do objetivo e etapa. A seleção e sua justificativa ficam no contexto antes da autorização. O usuário pode incluir/excluir capacidades por tarefa. Em cada tentativa, o agente recebe o catálogo correspondente à etapa e escolhe ferramentas conforme objetivo, resultado e evidências faltantes. A seleção inicial é determinística; não é um classificador treinado nem instalação automática.

## Configurar

Em Ajustes → Extensões, adicione uma skill (`SKILL.md`), MCP ou comando. Selecione projetos, etapas e palavras relevantes. Um MCP é salvo antes de consultar “Descobrir ferramentas”; habilite explicitamente as ferramentas e quais podem atuar em etapas de leitura. Alterar uma extensão selecionada invalida o contexto das tarefas pendentes.

Skills são carregadas sob demanda pelo agente, incluindo referências textuais dentro da pasta. O hash de `SKILL.md` é conferido antes da leitura; recursos carregados têm seus hashes registrados. Importar uma skill não executa seus scripts. Cadastre comandos necessários separadamente. Diretórios privados de providers não são varridos automaticamente. Nas sessões de trabalho, o Harness desativa a descoberta nativa de skills/apps do Codex e as skills nativas do Claude; as capacidades são fornecidas pelo catálogo autorizado. Os flags foram conferidos nos CLIs instalados.

MCP: stdio local ou Streamable HTTP (JSON/SSE), com negociação, descoberta paginada, sessão e chamadas de ferramentas. Token Bearer opcional fica no Keychain. OAuth dinâmico, SSE legado, sampling, elicitation e assinaturas de recursos não são implementados. Processos stdio podem gerenciar sua própria autenticação. Não coloque segredos em argumentos, manifestos ou URLs. Redirecionamentos HTTP não são seguidos.

Comandos têm executável e argumentos fixos; dados da tarefa entram por JSON em stdin. Nenhum shell é criado implicitamente. A permissão de leitura é uma autorização explícita do usuário, não isolamento de processo: MCPs e comandos locais executam com o acesso do usuário. Projetos que exigem isolamento forte bloqueiam extensões executáveis.

## Contrato de comando

Entrada em stdin:

```json
{
  "runID": "id",
  "revision": "snapshot",
  "workspace": "/pasta/do/projeto",
  "outputDirectory": "/armazenamento/Harness/captures/id",
  "arguments": {},
  "criteria": [{"id": "criterio", "text": "Resultado esperado"}]
}
```

Resposta JSON em stdout:

```json
{
  "text": "Cenário executado; captura disponível.",
  "artifacts": [{
    "path": "@output/captura.png",
    "title": "Resultado observado",
    "criterionIDs": ["criterio"],
    "providerReadable": true
  }]
}
```

Salve capturas em `outputDirectory`, fora do código. `@output/` resolve somente dentro dessa pasta. Caminhos relativos comuns resolvem no workspace. Links simbólicos, traversal e arquivos privados são recusados. Se o comando modificar o código, o snapshot muda e os resultados precisam de nova conferência. Imagens PNG/JPEG retornadas diretamente por MCP também entram na galeria; os demais recursos remotos não são baixados automaticamente.

O adaptador real `examples/extensions/project-report.py` gera um relatório do estado Git, sem afirmar validação funcional. O manifesto ao lado usa caminho relativo a este repositório; configure caminho absoluto para reutilizar em outros projetos. Há uma skill de revisão em `examples/extensions/evidence-review/SKILL.md`.

## CLI e MCP do Harness

```sh
harness extensions list
harness extensions add /caminho/manifesto.json
harness extensions skill "Revisão de evidências" /caminho/SKILL.md
harness extensions discover EXTENSION_ID
harness extension-call RUN_ID EXTENSION_ID TOOL < argumentos.json
harness evidence list RUN_ID
harness evidence add RUN_ID /caminho/captura.png --title "Resultado observado" --revision SNAPSHOT --criteria CRITERION_ID --share
harness evidence show RUN_ID ARTIFACT_ID
harness mcp --run RUN_ID
```

`--root` mantém o suporte a armazenamento isolado. `extensions add` aceita manifesto parcial e preenche campos padrão. Extensões importadas começam desabilitadas salvo escolha explícita no manifesto. `--share` permite acesso pelo provider; omitido, o artefato fica somente no app.

O MCP do Harness e o adaptador Codex usam as mesmas definições: `harness_capabilities`, `harness_skill_read`, `harness_extension_call`, `harness_evidence_list`, `harness_evidence_record`, `harness_evidence_read`, `harness_scenario_record`, além das operações de projeto existentes. Ferramentas de agente só atuam durante uma tentativa ativa; CLI e interface têm entradas próprias para tarefas pausadas. A interface permite importar, visualizar, compartilhar e vincular artefatos a cenários.

## Revisão e recuperação

Artefatos preservam hash, origem, tentativa, critérios, snapshot e permissão de envio. Recebimento não satisfaz critérios. Reprodução/conferência pode usar o agente quando há capacidades selecionadas; sem observação comprovada, a etapa continua aguardando evidência. Cenários automatizados exigem artefato vinculado e têm origem distinta da observação humana.

A revisão recebe um trecho do diff dimensionado pelo orçamento de contexto e pode consultar os arquivos omitidos pelas ferramentas; o tamanho fornecido e o tamanho total são explícitos.

O revisor pode pedir imagens e frames de vídeo com timestamp. Imagens são reduzidas até 1600 px; vídeos usam AVFoundation e dependem dos codecs do macOS. Um frame não representa o vídeo inteiro; áudio não é analisado. O evento registra conteúdo fornecido, sem afirmar que o modelo o compreendeu. Relatórios textuais têm limite de 256 KB para leitura pelo provider.

Chamadas registram intenção antes da execução e recibo depois. Erro, interrupção ou timeout deixam resultado UNKNOWN e bloqueiam repetição até conferência do destino pelo usuário. Não há retry automático de escrita. Evidências ficam fora da worktree e entram na exportação quando conteúdo e mídia são selecionados.

Referências de implementação: [transportes MCP](https://modelcontextprotocol.io/specification/2025-06-18/basic/transports), [ferramentas MCP](https://modelcontextprotocol.io/specification/2025-06-18/server/tools). O formato multimodal Codex foi verificado no JSON Schema gerado pelo CLI instalado.
