# Fronda — storyboard do mascote v1

Data: 28/09/2026. Etapa: proposta visual de personalidade e movimento, antes da integração com tarefas e ações rápidas.

## Pranchas

- `01-presenca-e-atencao.png`: tudo tranquilo, trabalhando e precisa de você.
- `02-respostas-e-orientacao.png`: resultado disponível, algo deu errado e ensinando.
- Cada situação tem três poses-chave, lidas da esquerda para a direita. São 18 poses em seis sequências.
- `prompts/`: prompts completos de geração e de correção pontual de anatomia.

Referência de identidade: `Resources/FrondaMascot.png`, arte aprovada já usada pelo aplicativo. As pranchas foram geradas com a ferramenta integrada image_gen, usando essa referência diretamente. Não foi utilizado fallback CLI/API.

## Personalidade proposta

Curioso, atento, acolhedor e expressivo. Sua curiosidade aparece no olhar e na inclinação do corpo; sua atenção, no acompanhamento das tarefas; seu acolhimento, na maneira paciente de esperar uma decisão ou apresentar uma recuperação. A comemoração é breve e proporcional à conclusão real.

O mascote fala de forma curta e concreta. Exemplos de intenção, ainda sujeitos aos dados reais da interface: “Há uma decisão esperando você”; “O resultado está pronto para revisar”; “Esta etapa parou. Vamos ver o que aconteceu?”. Evitar afirmações de progresso ou conclusão que não estejam confirmadas pelo coordenador.

## Anatomia e linguagem visual

- Manter as cinco ramificações com terminações franjadas, o pequeno broto sem franja, os dois olhos ovais e os dois pés arredondados.
- Preservar a assimetria, a textura orgânica marfim/dourada e a identidade da arte original. Não adicionar boca, nariz, sobrancelhas, mãos, roupas ou acessórios.
- Olhos orientam a atenção; ramificações comunicam o gesto; o corpo desloca seu peso para equilibrar a ação.
- O corpo inicia o movimento, as ramificações acompanham e as franjas terminam de acomodar com pequeno atraso.
- A silhueta deve continuar reconhecível no tamanho de uso no desktop. As diferenças sutis das pranchas precisam ser conferidas novamente quando houver animação nesse tamanho.

## Sequências e comportamento planejado

Os tempos abaixo são pontos de partida para animação, ainda não implementados ou medidos.

| Estado | Sequência | Ritmo inicial proposto | Ao interagir |
| --- | --- | --- | --- |
| Tudo tranquilo | Respira → observa → acomoda | Respiração em ciclo de 4–6 s; olhar e piscada ocasionais | Próxima tarefa e trabalhos recentes |
| Trabalhando | Se concentra → acompanha → mantém o ritmo | Ciclo suave de 2,5–4 s, sem sugerir porcentagem de progresso | Etapa atual e tarefas ativas |
| Precisa de você | Percebe → acena → espera | Um aceno de aproximadamente 1 s ao surgir uma nova pendência; depois espera | Decisão pendente e seu contexto |
| Resultado disponível | Prepara → celebra → pousa | Um pequeno salto de 0,9–1,3 s, uma vez por conclusão confirmada | Prévia do resultado e acesso à revisão |
| Algo deu errado | Percebe → se recolhe → busca saída | Transição de 1,2–1,8 s; termina atento, com o erro ainda indicado | Motivo conhecido e ações de recuperação disponíveis |
| Ensinando | Olha → aponta → acompanha | Gesto de 0,8–1,2 s; espera pela ação do usuário | Instrução contextual e próxima ação |

## Regras para a etapa funcional

- Estado e ações devem vir do acompanhamento real de tarefas existente no Fronda.
- Entre tarefas concorrentes: primeiro decisões pendentes, depois falhas, resultados ainda não vistos e execuções ativas. O painel deve permitir acessar as demais tarefas.
- O modo de ensino começa por uma ação explícita do usuário e mantém o acesso às pendências do trabalho.
- O salto acontece uma vez; erros e pendências não provocam gestos repetitivos insistentes.
- “Busca saída” significa disposição para ajudar; não indica que o erro foi resolvido.
- Em movimento reduzido, usar poses estáveis e estados escritos. A animação não deve ser o único modo de identificar uma situação.
- Apresentar as ações em popover contextual com projeto e tarefa visíveis; aproveitar o acompanhamento da Central de sessões existente.
- A fase de implementação deve preparar recortes transparentes, alinhamento consistente, quadros intermediários ou deformação controlada e transições entre estados.

## Revisão realizada e limites

As duas imagens finais foram inspecionadas visualmente. Corrigi a falta de ramificações nas poses “Acena” e “Olha”. Conferi os seis estados, a sequência de três poses por estado, os textos e a preservação geral da identidade.

São storyboards estáticos, não um atlas pronto para uso nem animações executáveis. Ainda é necessário validar a fluidez, legibilidade no tamanho real, intensidade dos gestos e comportamento no aplicativo quando essas etapas forem implementadas.

Nenhum código do aplicativo ou asset de produção foi alterado. Não foram executados build, lint ou testes, pois a entrega desta etapa é visual.
