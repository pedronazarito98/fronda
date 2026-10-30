import type { Point } from './animation.types.js';
import { MascotMotion } from './motion.js';
import { MascotRenderer } from './renderer.js';
import { safeOffset } from './branch-deformation.js';
import { BASE_SCALE, clamp } from './rig.js';

export function connectInteractions(canvas: HTMLCanvasElement, motion: MascotMotion, renderer: MascotRenderer, openActions: () => void): void {
  let pressed: { point: Point; offset: Point; previous: Point; stamp: number; moved: boolean; branch: number } | null = null;
  function relative(event: PointerEvent): Point {
    const rect = canvas.getBoundingClientRect();
    return { x: (event.clientX - rect.left) / rect.width, y: (event.clientY - rect.top) / rect.height };
  }
  function branchAt(point: Point): number {
    let selected = -1, nearest = .105 * renderer.size;
    for (let i = 0; i < 5; i++) {
      const [x, y] = renderer.pointOnBranch(i), distance = Math.hypot(point.x - x, point.y - y);
      if (distance < nearest) { selected = i; nearest = distance; }
    }
    return selected;
  }
  canvas.addEventListener('pointermove', event => {
    const point = relative(event), state = motion.interaction;
    state.gaze = { x: clamp((point.x - .5 - state.offset.x) * 3, -1, 1), y: clamp((point.y - .5 - state.offset.y) * 3, -1, 1) };
    state.hover = branchAt(point);
    if (!pressed) { canvas.style.cursor = state.hover >= 0 ? 'pointer' : renderer.hitsBody([point.x, point.y]) ? 'grab' : 'default'; return; }
    const dx = point.x - pressed.point.x, dy = point.y - pressed.point.y;
    if (Math.hypot(dx, dy) > .008) pressed.moved = true;
    if (pressed.moved) {
      state.dragging = true;
      const bound = safeOffset(BASE_SCALE * renderer.size);
      state.offset = { x: clamp(pressed.offset.x + dx, -bound, bound), y: clamp(pressed.offset.y + dy, -bound, bound) };
      const dt = Math.max(.008, (event.timeStamp - pressed.stamp) / 1000);
      state.velocity = { x: clamp((point.x - pressed.previous.x) / dt, -2, 2), y: clamp((point.y - pressed.previous.y) / dt, -2, 2) };
      canvas.style.cursor = 'grabbing';
    }
    pressed.previous = point;
    pressed.stamp = event.timeStamp;
  });
  canvas.addEventListener('pointerdown', event => {
    if (event.button !== 0) return;
    const point = relative(event);
    const branch = branchAt(point);
    if (branch < 0 && !renderer.hitsBody([point.x, point.y])) return;
    canvas.setPointerCapture(event.pointerId);
    pressed = { point, previous: point, offset: { ...motion.interaction.offset }, stamp: event.timeStamp, moved: false, branch };
  });
  canvas.addEventListener('pointerup', event => {
    if (!pressed) return;
    if (!pressed.moved) { if (pressed.branch >= 0) motion.touch(pressed.branch); else openActions(); }
    motion.interaction.dragging = false;
    pressed = null;
    if (canvas.hasPointerCapture(event.pointerId)) canvas.releasePointerCapture(event.pointerId);
    canvas.style.cursor = 'grab';
  });
  const cancel = (): void => { pressed = null; motion.interaction.dragging = false; motion.interaction.hover = -1; motion.interaction.gaze = { x: 0, y: 0 }; };
  canvas.addEventListener('pointercancel', cancel);
  canvas.addEventListener('lostpointercapture', () => { pressed = null; motion.interaction.dragging = false; });
  canvas.addEventListener('pointerleave', () => { if (!pressed) cancel(); });
  canvas.addEventListener('keydown', event => {
    const offsets: Record<string, Point> = { ArrowLeft: { x: -.018, y: 0 }, ArrowRight: { x: .018, y: 0 }, ArrowUp: { x: 0, y: -.018 }, ArrowDown: { x: 0, y: .018 } };
    if (offsets[event.key]) {
      event.preventDefault();
      const direction = offsets[event.key]!, offset = motion.interaction.offset;
      offset.x = clamp(offset.x + direction.x, -.10, .10); offset.y = clamp(offset.y + direction.y, -.10, .10);
    } else if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); openActions(); }
    else if (event.key === 'Escape') { motion.interaction.offset = { x: 0, y: 0 }; }
  });
}
