import type { MascotState, StateId } from './animation.types.js';

export const STATES: readonly MascotState[] = [
  { id: 'idle', label: 'Tudo tranquilo', detail: 'Os ramos crescem devagar. Cada ponta tem seu próprio ritmo.', color: [.70, .79, .57], pose: [0, 0, 0, 0, 0], message: 'Estou por aqui. O que vamos criar?', action: 'Começar algo' },
  { id: 'working', label: 'Trabalhando', detail: 'O crescimento percorre os ramos; os tentáculos vêm depois.', color: [.49, .68, .34], pose: [.07, -.08, .06, -.09, .07], message: 'Concentrado no trabalho. Você pode continuar por aqui.', action: 'Acompanhar tarefa' },
  { id: 'attention', label: 'Precisa de você', detail: 'Um ramo se ergue; as pontas âmbar pedem sua atenção.', color: [.92, .57, .12], pose: [.10, -.05, -.02, -.10, .03], message: 'Há uma decisão esperando você.', action: 'Ver decisão' },
  { id: 'success', label: 'Resultado disponível', detail: 'Um salto, ramos que se expandem e chapéus que se abrem.', color: [.33, .70, .27], pose: [-.13, .10, .10, -.10, -.10], message: 'O resultado está pronto para revisar.', action: 'Ver resultado' },
  { id: 'error', label: 'Algo deu errado', detail: 'Os ramos encolhem e os tentáculos se curvam em coral.', color: [.91, .32, .28], pose: [-.24, -.22, -.19, .24, .20], message: 'Esta etapa parou. Vamos entender o que aconteceu.', action: 'Entender o problema' },
  { id: 'guide', label: 'Ensinando', detail: 'Um ramo se alonga até o alvo; os outros seguem vivos.', color: [.51, .72, .36], pose: [-.05, .12, .10, -.32, -.04], message: 'Escolha uma situação para conhecer meu jeito de reagir.', action: 'Experimentar comigo' },
];

export function stateFor(id: StateId): MascotState {
  return STATES.find(state => state.id === id) ?? STATES[0]!;
}
