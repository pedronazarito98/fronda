import type { MotionFrame, Vec2 } from './animation.types.js';
import { clamp, CROWNS, PIVOTS, rotate } from './rig.js';

// Mirrors the vertex shader for hit targets, so growing branches stay clickable.
export function branchCrown(branch: number, frame: MotionFrame): Vec2 {
  const pivot = PIVOTS[branch]!, crown = CROWNS[branch]!;
  const dx = crown[0] - pivot[0], dy = crown[1] - pivot[1];
  const length = Math.hypot(dx, dy), axis: Vec2 = [dx / length, dy / length];
  const bend = frame.bends[branch]!;
  const growth = 1 + frame.growth[branch]!;
  const along = Math.abs(bend) < .0001 ? length : length * Math.sin(bend) / bend;
  const across = Math.abs(bend) < .0001 ? 0 : length * (1 - Math.cos(bend)) / bend;
  const point: Vec2 = [pivot[0] + (axis[0] * along - axis[1] * across) * growth, pivot[1] + (axis[1] * along + axis[0] * across) * growth];
  return rotate(point, pivot, frame.angles[branch]!);
}

export function worldPoint(point: Vec2, frame: MotionFrame, scale: number): Vec2 {
  let transformed: Vec2 = [.50 + (point[0] - .50) * (1 - (frame.body[1] - 1) * .32), .932 + (point[1] - .932) * frame.body[1]];
  transformed = rotate(transformed, [.50, .932], frame.body[0]);
  return [(transformed[0] - .5) * scale + .5 + frame.position[0], (transformed[1] - .5 - frame.body[2] - frame.body[3]) * scale + .5 + frame.position[1]];
}

export function safeOffset(size: number): number {
  // Reserve room for expanding crowns and the trailing tentacles.
  return clamp(.5 - size * .50, .04, .36);
}
