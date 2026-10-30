import type { StateId } from './animation.types.js';
import { connectInteractions } from './interactions.js';
import { MascotMotion } from './motion.js';
import { recordShowcase } from './recorder.js';
import { MascotRenderer } from './renderer.js';
import { STATES, stateFor } from './states.js';

function element<T extends HTMLElement>(id: string): T {
  const found = document.getElementById(id);
  if (!found) throw new Error(`Elemento ausente: ${id}`);
  return found as T;
}

interface PreviewSnapshot {
  state: StateId;
  time: number;
  reduced: boolean;
  paused: boolean;
  angles: number[];
  tips: number[];
  bends: number[];
  growth: number[];
  blooms: number[];
  filaments: number[];
  branches: (readonly [number, number])[];
  color: number[];
  body: number[];
  offset: { x: number; y: number };
  ready: boolean;
}

interface PreviewAPI {
  selectState(id: StateId): void;
  snapshot(): PreviewSnapshot;
}
declare global { interface Window { frondaPreview: PreviewAPI } }

async function start(): Promise<void> {
  const canvas = element<HTMLCanvasElement>('mascot');
  const renderer = new MascotRenderer(canvas), motion = new MascotMotion();
  const states = element('state-controls'), actions = element('actions');
  const pauseButton = element<HTMLButtonElement>('pause'), cycleButton = element<HTMLButtonElement>('cycle');
  const reducedInput = element<HTMLInputElement>('reduced');
  const reducedQuery = window.matchMedia('(prefers-reduced-motion: reduce)');
  const symbols = ['◌', '≈', '!', '✓', '↻', '↗'];
  let cycling = false, cycleAge = 0, lastStamp = performance.now(), recording = false;
  let oldState: StateId = 'idle';

  function updatePause(): void { pauseButton.textContent = motion.paused ? 'Continuar' : 'Pausar'; pauseButton.setAttribute('aria-pressed', String(motion.paused)); }
  function stopCycle(): void { cycling = false; cycleAge = 0; cycleButton.innerHTML = 'Percorrer estados <span aria-hidden="true">▷</span>'; }
  function selectState(id: StateId): void {
    const config = stateFor(id);
    motion.select(config.id);
    canvas.dataset.state = config.id;
    element('state-title').textContent = config.label;
    element('state-detail').textContent = config.detail;
    element('mascot-message').textContent = config.message;
    element('context-action').textContent = config.action;
    element('guide-target').hidden = config.id !== 'guide';
    document.querySelectorAll<HTMLButtonElement>('[data-state]').forEach(button => button.setAttribute('aria-pressed', String(button.dataset.state === id)));
    if (id === 'guide') motion.interaction.gaze = { x: .9, y: .05 };
  }

  STATES.forEach((state, index) => {
    const button = document.createElement('button');
    button.type = 'button'; button.className = 'state-button'; button.dataset.state = state.id;
    button.title = state.detail; button.setAttribute('aria-pressed', String(state.id === 'idle'));
    const symbol = document.createElement('span'); symbol.className = 'state-mark'; symbol.textContent = symbols[index]!; symbol.setAttribute('aria-hidden', 'true');
    const label = document.createElement('span'); label.textContent = state.label;
    const selected = document.createElement('span'); selected.className = 'selected-mark'; selected.textContent = '•'; selected.setAttribute('aria-hidden', 'true');
    button.append(symbol, label, selected);
    button.addEventListener('click', () => { stopCycle(); motion.paused = false; updatePause(); selectState(state.id); });
    states.append(button);
  });
  connectInteractions(canvas, motion, renderer, () => actions.togglePopover());
  element('context-action').addEventListener('click', () => { actions.hidePopover(); motion.paused = false; updatePause(); selectState(motion.state === 'idle' ? 'working' : motion.state === 'working' ? 'attention' : motion.state === 'error' ? 'working' : motion.state === 'guide' ? 'success' : 'guide'); });
  element('touch-action').addEventListener('click', () => { actions.hidePopover(); motion.touch(1); });
  element('guide-target').addEventListener('click', () => { stopCycle(); selectState('success'); });
  element('unfurl').addEventListener('click', () => { motion.paused = false; updatePause(); motion.unfurl(); });
  element('replay').addEventListener('click', () => { motion.paused = false; updatePause(); selectState(motion.state); });
  pauseButton.addEventListener('click', () => { motion.paused = !motion.paused; updatePause(); });
  cycleButton.addEventListener('click', () => {
    if (cycling) { stopCycle(); return; }
    cycling = true; cycleAge = 0; motion.paused = false; updatePause(); selectState('idle');
    cycleButton.innerHTML = 'Parar sequência <span aria-hidden="true">□</span>';
  });
  const rangeBindings = [
    { id: 'intensity', apply: (value: number) => { motion.intensity = value; }, format: (value: number) => `${Math.round(value * 100)}%` },
    { id: 'speed', apply: (value: number) => { motion.speed = value; }, format: (value: number) => `${value.toLocaleString('pt-BR')}×` },
    { id: 'size', apply: (value: number) => { renderer.size = value; motion.interaction.offset = { x: 0, y: 0 }; }, format: (value: number) => `${Math.round(value * 100)}%` },
  ];
  for (const binding of rangeBindings) element<HTMLInputElement>(binding.id).addEventListener('input', event => {
    const value = Number((event.currentTarget as HTMLInputElement).value);
    binding.apply(value); element(`${binding.id}-value`).textContent = binding.format(value);
  });
  function setReduced(reduced: boolean): void { motion.reduced = reduced; reducedInput.checked = reduced; element<HTMLButtonElement>('unfurl').disabled = reduced; if (reduced) stopCycle(); }
  setReduced(reducedQuery.matches);
  reducedInput.addEventListener('change', () => setReduced(reducedInput.checked));
  reducedQuery.addEventListener('change', event => setReduced(event.matches));
  element('reset').addEventListener('click', () => {
    for (const binding of rangeBindings) { element<HTMLInputElement>(binding.id).value = '1'; binding.apply(1); element(`${binding.id}-value`).textContent = binding.format(1); }
    motion.interaction.offset = { x: 0, y: 0 }; motion.interaction.velocity = { x: 0, y: 0 }; motion.interaction.gaze = { x: 0, y: 0 };
    setReduced(reducedQuery.matches); motion.paused = false; updatePause();
  });
  function setTheme(dark: boolean): void { document.documentElement.dataset.theme = dark ? 'dark' : 'light'; element('theme').textContent = dark ? 'Aparência clara' : 'Aparência escura'; }
  setTheme(window.matchMedia('(prefers-color-scheme: dark)').matches);
  element('theme').addEventListener('click', () => setTheme(document.documentElement.dataset.theme !== 'dark'));
  element<HTMLButtonElement>('record').addEventListener('click', async () => {
    if (recording) return;
    const button = element<HTMLButtonElement>('record');
    recording = true; button.disabled = true; stopCycle(); oldState = motion.state;
    const previous = { reduced: motion.reduced, paused: motion.paused, offset: { ...motion.interaction.offset }, speed: motion.speed, size: renderer.size };
    motion.reduced = false; motion.paused = false; motion.speed = 1; renderer.size = 1; motion.interaction.offset = { x: 0, y: 0 }; motion.interaction.gaze = { x: 0, y: 0 }; motion.interaction.hover = -1;
    document.querySelectorAll<HTMLButtonElement | HTMLInputElement>('.controls button, .controls input, #theme').forEach(control => { control.disabled = true; });
    try {
      await recordShowcase(canvas, id => { selectState(id); if (id === 'idle') motion.unfurl(); }, () => motion.state, label => { button.textContent = label; });
      element('announcement').textContent = 'Vídeo salvo com os seis estados.';
    } catch (error) {
      element('render-error').hidden = false; element('render-error').textContent = error instanceof Error ? error.message : 'Não foi possível gravar.';
    } finally {
      recording = false; button.disabled = false; button.textContent = 'Salvar vídeo ↗';
      document.querySelectorAll<HTMLButtonElement | HTMLInputElement>('.controls button, .controls input, #theme').forEach(control => { control.disabled = false; });
      motion.reduced = previous.reduced; motion.paused = false; motion.speed = previous.speed; renderer.size = previous.size; motion.interaction.offset = previous.offset; element<HTMLButtonElement>('unfurl').disabled = previous.reduced; selectState(oldState); renderer.render(motion.step(1 / 60)); motion.paused = previous.paused; updatePause();
    }
  });
  document.addEventListener('visibilitychange', () => { lastStamp = performance.now(); });
  canvas.addEventListener('rendererror', event => { element('render-error').hidden = false; element('render-error').textContent = String((event as CustomEvent<string>).detail); });
  await renderer.load('./assets/fronda-neutral.png');
  element('loading').hidden = true;
  selectState('idle');
  let frameCount = 0;
  function draw(stamp: number): void {
    const dt = Math.min(.032, (stamp - lastStamp) / 1000); lastStamp = stamp;
    if (!document.hidden) {
      if (cycling && !motion.paused && !motion.reduced) {
        cycleAge += dt;
        if (cycleAge >= 6) { cycleAge = 0; const index = STATES.findIndex(state => state.id === motion.state); selectState(STATES[(index + 1) % STATES.length]!.id); }
      }
      const frame = motion.step(dt);
      renderer.render(frame);
      const shadow = element('shadow');
      shadow.style.left = `${(50 + frame.position[0] * 100)}%`;
      shadow.style.top = `${(50 + .432 * .78 * renderer.size * 100 + frame.position[1] * 100)}%`;
      shadow.style.transform = `translate(-50%,-50%) scale(${renderer.size * (1 - frame.body[2] * 4)})`;
      shadow.style.opacity = String(.85 - frame.body[2] * 4);
      frameCount++;
      if (frameCount % 30 === 0) canvas.dataset.frames = String(frameCount);
    }
    requestAnimationFrame(draw);
  }
  window.frondaPreview = {
    selectState,
    snapshot: () => {
      const frame = renderer.stateSnapshot.frame;
      return {
        state: motion.state, time: motion.time, reduced: motion.reduced, paused: motion.paused,
        angles: Array.from(frame?.angles ?? []), tips: Array.from(frame?.tips ?? []),
        bends: Array.from(frame?.bends ?? []), growth: Array.from(frame?.growth ?? []),
        blooms: Array.from(frame?.blooms ?? []), filaments: Array.from(frame?.filaments ?? []),
        branches: Array.from({ length: 5 }, (_, index) => renderer.pointOnBranch(index)),
        color: Array.from(frame?.color ?? []), body: Array.from(frame?.body ?? []),
        offset: { ...motion.interaction.offset }, ready: renderer.ready,
      };
    },
  };
  requestAnimationFrame(draw);
}

start().catch(error => {
  element('loading').hidden = true;
  element('render-error').hidden = false;
  element('render-error').textContent = error instanceof Error ? error.message : 'Não foi possível abrir a prévia.';
  console.error(error);
});
