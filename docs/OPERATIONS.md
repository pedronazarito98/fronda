# Operação, integrações e distribuição

## Processos e dados

- `Harness.app`: SwiftUI; janelas, Inspector, Settings, MenuBarExtra e notificações.
- `HarnessService`: coordenador único por raiz de dados, ativado sob demanda por launchd. O plist fica na própria raiz; não instala um agente de login por padrão. Durante encerramento, recusa novas requisições/agendamento antes de sair; o próximo cliente reconecta ao novo processo.
- `harness`: cliente XPC e host MCP restrito. Não abre SQLite diretamente.
- Runner: `posix_spawn`, argv UTF-8 sem shell, ambiente mínimo, pipes drenados, timeout e grupo de processos cancelável. Preserva acentos nos argumentos aprovados.
- SQLite: WAL, transações, eventos imutáveis, deltas por evento, checkpoints por fase/100 eventos, FTS5 e leases. Migração para schema 2 cria backup pelo mecanismo SQLite e executa `quick_check`.
- Artefatos: conteúdo redigido identificado por SHA-256. Diretórios privados 0700 e arquivos 0600. Worktrees e histórico são preservados; não há limpeza automática destrutiva.

O banco, backups e artefatos privados não devem ser enviados para suporte. Use a exportação de evidência do app. A prévia da exportação permite incluir ou retirar diff e eventos. O modo somente metadados omite textos livres, nomes de arquivos, comandos e outputs, preservando IDs, hashes e estados. O manifesto identifica os arquivos efetivamente incluídos; o pacote não inclui Keychain ou sessões de providers. A redação automática não é garantia de remoção de todos os dados pessoais de textos livres.

## GitHub

Registre/configure um GitHub App com Device Flow e permissões apenas nos repositórios necessários. Informe o Client ID em Ajustes → Integrações. O navegador mostra a conta e o escopo a autorizar; o usuário conclui a autorização. GitHub Enterprise usa o host do endpoint configurado.

Referência primária: [token de usuário de GitHub App](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app).

Leitura: PR, arquivos/diff, checks e comentários selecionados por ID. Cada consulta retorna revisão/ETag disponível. A prévia de escrita fica vinculada ao endpoint, conta, corpo exato e snapshot; um marcador da operação permite consultar o destino se a resposta se perder. Paginação de reconciliação: até 1.000 recursos; ausência não é tratada como prova de que a escrita falhou.

## Jira

Configure um App OAuth 3LO próprio e o callback `http://127.0.0.1:8765/oauth/callback`, conforme a configuração aceita pela sua instância. Informe Client ID, secret e endpoint `https://api.atlassian.com/ex/jira/CLOUD_ID/rest/api/3`. O listener local verifica `state`, só escuta loopback e encerra após o callback. O secret não é embutido no app distribuído. OAuth real ainda não foi validado neste ambiente.

Referência primária: [Jira OAuth 2.0 3LO](https://developer.atlassian.com/cloud/jira/software/oauth-2-3lo-apps/).

O formulário também aceita um token autorizado já emitido para o endpoint. Falhas/expiração pedem reconexão; refresh tokens OAuth são renovados pelo endpoint oficial e permanecem no Keychain. Não há importação de credenciais de outro aplicativo.

Leitura: descrição, estado, tipo, revisão, comentários selecionados e anexos autorizados. Em Configurar projeto → Critérios do Jira, informe o ID `customfield_…`. A extração de texto/ADF é determinística, conserva o JSON original e preenche critérios editáveis na Nova run. A primeira leitura lista os anexos; marque os desejados e releia a fonte para inspecionar o conteúdo. A criação fica bloqueada enquanto essa seleção estiver desatualizada.

O download usa a rota autenticada de [conteúdo de anexos Jira](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-attachments/#api-rest-api-3-attachment-content-id-get), com `redirect=false`, sem aceitar outro host ou a URL arbitrária do anexo. O firewall valida o nome antes de baixar; limites de 10 MB por arquivo, 20 MB por importação e 40 anexos. Extração ocorre em memória, aplica redação e conserva SHA-256, sem guardar bytes remotos brutos. A implementação compilou; o fluxo autenticado remoto permanece NOT_RUN.

## Outbox

`PREPARED → APPROVED → SENDING → CONFIRMED` ou `UNKNOWN`. Recusa gera `REJECTED`; mudança de snapshot gera `STALE`. Não existe retry automático de escrita incerta. **Consultar destino sem repetir operação** pesquisa o marcador ou o estado remoto; se a consulta não provar o resultado, continua `UNKNOWN`.

As rotas REST são limitadas por tipo de ação. Aprovação é válida somente para o digest e a revisão exibidos. Configurar uma conexão não autoriza commit, push, comentário, PR ou transição Jira automaticamente.

## Distribuição

O pacote `dist/Harness.app` é de desenvolvimento, assinado ad hoc. A verificação local de integridade passou; isso não é notarização nem distribuição Developer ID.

```sh
export HARNESS_SIGN_IDENTITY='Developer ID Application: SUA IDENTIDADE'
./script/release.sh
# Somente quando desejar enviar o pacote à Apple:
export HARNESS_NOTARY_PROFILE='SEU_PERFIL_EXISTENTE'
./script/release.sh --notarize
```

O script assina helpers e app com hardened runtime, verifica assinaturas, gera ZIP e SHA-256 e, quando solicitado, envia/staple/avalia com Gatekeeper. Ele não cria certificados ou perfis e não publica o pacote. Não foi executado porque não há Developer ID Application disponível neste Mac.

Ajustes → Armazenamento verifica uma atualização `.app` selecionada: mesmo identificador/Team ID, versão superior, assinatura profunda e avaliação Gatekeeper. Instalação é manual depois da verificação, preservando Application Support. Feed de atualização e substituição automática não estão implementados.

## Limites explícitos

- Validadores leem até 4 MB por stream em memória; a interface mostra até 100 KB e a evidência exporta um trecho. Não anunciar retenção integral de saída acima desse limite.
- Índice: até 50 mil paths elegíveis, arquivos textuais até 256 KB, lotes de 64, cache limitado a aproximadamente 16 MB. Contexto usa até 256 candidatos, mais pins, com orçamento obrigatório; 50 mil arquivos não foram medidos com Instruments.
- Screenshots: OCR local. PDF: texto extraível. Máximo 40 arquivos por pasta e 10 MB por anexo, com limite de texto extraído.
- Grafo: definições/imports/chamadas sintáticas, associação de testes por nome e histórico Git recente. Não é um language server nem promete resolução semântica completa.
- O broker recusa links simbólicos e aplica exclusões privadas sem distinguir maiúsculas/minúsculas. Selecione o arquivo original elegível.
- APIs externas e parsers podem evoluir; versões dos CLIs são verificadas. Operações não reconhecidas falham fechadas.
- Sem sincronização com iCloud, telemetria, publicação automática ou execução de testes gerados sem pedido explícito.
