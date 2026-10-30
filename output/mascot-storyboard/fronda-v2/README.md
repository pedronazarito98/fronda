# Fronda — ramificações vivas, versão 2

Revisão visual de 28/09/2026 a partir do feedback: mais vida nas ramificações, pontas coloridas conforme o estado e interação mais expressiva. Esta entrega é um storyboard estático para orientar a animação e a implementação posteriores.

## Arquivos

- `01-ramificacoes-vivas.png`: repouso, trabalho e pedido de atenção, com três poses por situação.
- `02-expressao-e-resposta.png`: conclusão, erro e orientação, com três poses por situação.
- `03-reage-a-voce.png`: resposta ao cursor, toque nas pontas e arraste, com três poses por interação.
- `prompts/`: prompts integrais e correções pontuais de anatomia.

As três pranchas somam 27 poses-chave. Arte gerada com image_gen integrado, referenciada diretamente em `Resources/FrondaMascot.png` e nas pranchas anteriores. Nenhum fallback CLI/API foi usado. A versão 1 permanece preservada.

## Direção visual

O corpo mantém a textura orgânica marfim e dourada do mascote aprovado. A cor se concentra nas franjas terminais e bordas das terminações. Os ramos flexionam de maneira independente, com formas mais abertas, fechadas, inclinadas e curvas, mantendo a identidade do personagem.

Os olhos orientam a atenção. O tronco desloca seu peso. A base de cada ramo inicia o gesto, a terminação acompanha e as franjas se acomodam depois. Ao soltar, há um retorno elástico curto, com amortecimento.

O vocabulário cromático parte dos tokens já existentes em `FrondaTheme.swift`: sálvia/acento, sucesso, atenção e perigo. Os códigos abaixo são referência de intenção; o tom exato em renderização precisa ser calibrado na preparação dos assets para light/dark.

| Situação | Pontas | Movimento e leitura |
| --- | --- | --- |
| Tudo tranquilo | Marfim com toque discreto de sálvia | Respiração, espreguiçar ocasional e curiosidade pelo cursor |
| Trabalhando | Sálvia, referência #BDCCA7 / #8D9877 | Uma onda percorre grupos de ramos em sequência; sem sugerir porcentagem de progresso |
| Precisa de você | Âmbar, referência #E3BD7E / #8E5A21 | Um ramo acena, os outros equilibram; a ponta em destaque permanece âmbar durante a espera |
| Resultado disponível | Verde, referência #A7CC99 / #356540 | Ramos se abrem em um pequeno salto único, seguido de acomodação |
| Algo deu errado | Coral, referência #F0A49D / #A7443F | Ramos se recolhem e depois um deles se oferece para ajudar; coral persiste até resolução real |
| Ensinando | Sálvia apenas na ponta que indica | Olhar localiza o alvo, um ramo aponta e o corpo convida o usuário a acompanhar |

Trabalho e conclusão compartilham a família verde, mas são diferenciados pelo gesto, pela distribuição da cor e pelo estado escrito. Cor nunca deve ser a única indicação de estado.

## Interações propostas

1. **Aproximar o cursor:** olhos orientam primeiro; o ramo mais próximo inclina-se em seguida, com um destaque local nas pontas. A reação acontece apenas na proximidade do mascote.
2. **Tocar uma ponta:** pequena compressão e retorno elástico; o impulso percorre as outras ramificações. A reação dura pouco e retorna ao estado real da tarefa.
3. **Arrastar o corpo:** o tronco acompanha o cursor diretamente; os ramos e franjas atrasam e se inclinam na direção oposta. Ao soltar, acomodam sem deslocar novamente a posição escolhida.
4. **Clicar no corpo:** abre ações rápidas com o contexto de projeto/tarefa. O gesto deve diferenciar clique de arraste para evitar abertura acidental ao mover.
5. **Levar um arquivo até o mascote:** evolução proposta, ainda fora das pranchas; ramos próximos se abrem para indicar recepção e o popover mostra o arquivo e seu destino antes de criar uma tarefa.

O feedback lúdico de toque deve preservar a cor semântica de uma pendência ou falha: se o estado for coral/âmbar, o impulso varia brilho e intensidade dessa mesma cor. A prancha de toque ilustra o estado tranquilo, em sálvia.

## Ritmo e prioridade

- Trabalho real altera o estado; passar o cursor ou tocar o personagem produz uma reação temporária sobre esse estado.
- Gestos de atenção e conclusão acontecem uma vez por evento novo. Depois, ele assume uma postura estável e reconhecível.
- Os ramos nunca somem, se multiplicam ou viram mãos humanas. Devem conservar as cinco terminações, o broto central, os olhos e os pés do original.
- Olhar e postura continuam comunicando o estado quando houver movimento reduzido. Substituir ondas, saltos e balanços por poses estáveis; manter texto e ações acessíveis por teclado.
- Na futura implementação, interromper uma animação de forma suave ao entrar uma interação ou um estado prioritário. Não exigir que um ciclo inteiro termine para responder ao usuário.

## Revisão e validação seguinte

Pranchas inspecionadas visualmente. Foram restauradas ramificações ausentes nas poses “Se dispõe”, “Indica” e “Acompanha” do arraste. A revisão verificou clareza das sequências, distribuição das cores e continuidade geral da identidade.

Ainda são ilustrações de poses, não animações contínuas ou recortes prontos para instalar no app. A produção de animação precisa conferir anatomia quadro a quadro, continuidade de volume, trajetória dos ramos, alinhamento e transparência.

Na avaliação visual, conferir principalmente se a amplitude dos ramos ficou viva o suficiente, se a intensidade das pontas combina com a identidade e se a reação ao cursor/toque/arraste parece natural. Depois de animar, validar no tamanho real do desktop, nos dois temas e com movimento reduzido.

Nenhum código ou asset de produção foi alterado. Não foram executados build, lint ou testes nesta etapa visual.
