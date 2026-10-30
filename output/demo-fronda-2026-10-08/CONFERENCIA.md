# Resultado da preparação — 08/10/2026

## O que ficou pronto no Fronda

Projeto **Demo Fronda · Cadastro de contato**, com nove tarefas, três runbooks e três comandos locais de sintaxe. Cada tarefa de escrita tem worktree isolada.

A tarefa **01** está em **Aguardando você**, pronta para demonstrar a aprovação inicial. Seu limite é 500.000 tokens, com esforço baixo e contexto reduzido. Esse é um teto, não uma previsão de consumo.

A tarefa **09** percorreu investigação, plano aprovado, implementação, validação e revisão independente com Codex. Alteração real: remoção de três linhas em `src/contact.ts`, permitindo omitir apelido.

### Estado final da tarefa 09

**Parcial.** A revisão independente não encontrou defeito no diff, mas deixou um parecer aberto por limitações de evidência. A aprovação humana e a conclusão integral dos critérios não foram marcadas como concluídas.

- A contagem de requisições no cenário de duplo envio não foi medida. Foram observados botão desabilitado, bloqueio durante a espera e um único resultado de sucesso na interface, além da guarda no código.
- As capturas antes/depois estão anexadas aos cenários da tarefa. O revisor independente informou que o catálogo de artefatos acessível ao provider retornou vazio; portanto não afirmou ter inspecionado as imagens.
- O parecer pediu nome vazio/somente espaços. Esses dois casos foram observados e registrados depois do parecer. Não houve nova rodada do revisor após esse complemento.
- Consumo reportado pelo Fronda na execução 09: 434.931 tokens, incluindo a primeira tentativa interrompida por orçamento. Não representa custo monetário medido. As tarefas auxiliares de estados não chamaram IA.

Esta situação também é demonstrável: uma correção pode funcionar e passar na sintaxe, mas ainda manter revisão e evidências pendentes.

## Conferência funcional

| Caso | Resultado observado | Origem |
| --- | --- | --- |
| Apelido vazio, antes | Cadastro bloqueado indevidamente | Interface, porta 8858 |
| Apelido com espaços, antes | Cadastro bloqueado indevidamente | Interface, porta 8858 |
| Apelido vazio, depois | Contato salvo, Sem apelido | Interface, porta 8859; captura depois.jpg |
| Apelido com espaços, depois | Contato salvo, Sem apelido | Interface, porta 8859 |
| Nome vazio, espaços ou um caractere | Erro no nome, foco no campo, dados mantidos | Interface e atributos do DOM |
| E-mail inválido | Erro no e-mail, dados mantidos | Interface e atributos do DOM |
| Normalização | Nome/apelido sem espaços externos; e-mail em minúsculas | Resultado exibido |
| Apelido preenchido | Valor mantido no contato salvo | Resultado exibido |
| Duplicidade | Erro Este e-mail já está cadastrado | Reenvio real na interface |
| Texto semelhante a HTML | <b>Demo</b> exibido literalmente | Interface; nenhum elemento b no resultado |
| Duplo envio | Botão desabilitado em Salvando; conclusão única visível após retomada | Duplo clique e Enter com servidor temporariamente suspenso; sem contagem de requisições |
| Conexão interrompida | Erro recuperável, campos mantidos, botão habilitado | Servidor local encerrado e depois reiniciado |
| Rótulos e mensagens | aria-describedby, aria-invalid, aria-live e foco observados | DOM da interface |
| VoiceOver falado, tema escuro, largura de celular | Não executados | Conferência manual futura |

Foram registrados dois cenários anteriores e dez posteriores na tarefa 09. Todos usam dados fictícios. O campo de origem da API aparece como “Observação humana”, mas o ambiente de cada registro explicita que a conferência foi feita pelo assistente na interface.

## Verificações executadas

- Três comandos de sintaxe: PASS, exit 0, no snapshot da correção.
- Diff inspecionado: apenas src/contact.ts na tarefa 09.
- Exemplos PASS, FAIL, BLOCKED, STALE, PAUSED, CANCELLED e limite de orçamento conferidos pela API pública e pela interface do Fronda.
- Nenhum teste automatizado, arquivo de teste ou mock criado; nenhum lint ou build do Fronda executado.

## Atenção durante a apresentação

- Use dados fictícios e e-mails diferentes para novos cadastros; repetir um e-mail demonstra duplicidade.
- Os servidores guardam contatos apenas em memória; reiniciá-los limpa a demo.
- O texto introdutório do formulário descreve o defeito inicial e foi preservado na worktree corrigida. Use as portas 8858 e 8859 para distinguir antes e depois.
- Arquivos e alterações preexistentes do Fronda foram preservados. Todo o exemplo está no repositório independente e no diretório de saída desta tarefa.
- Autenticação expirada, indisponibilidade externa real, conflito remoto, commit, push e PR não foram executados. O repositório de demonstração não tem remoto.
