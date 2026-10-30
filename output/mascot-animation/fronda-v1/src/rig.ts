import type { Vec2 } from './animation.types.js';

// Anchors use the transparent master, with a top-left origin.
export const PIVOTS: readonly Vec2[] = [[.443, .54], [.412, .455], [.414, .666], [.566, .665], [.533, .737]];
export const CROWNS: readonly Vec2[] = [[.695, .16], [.245, .265], [.237, .51], [.822, .445], [.722, .647]];
export const TIPS: readonly (readonly [number, number, number, number])[] = [
  [.726, .276, .107, .077], [.192, .375, .10, .072], [.221, .609, .108, .08], [.858, .553, .094, .075], [.747, .752, .086, .072],
];
export const EYES: readonly Vec2[] = [[.503, .559], [.547, .574]];
export const BASE_SCALE = .78;
export const BODY_ANCHOR: Vec2 = [.50, .932];

export const clamp = (value: number, low: number, high: number): number => Math.min(high, Math.max(low, value));
export function rotate(point: Vec2, pivot: Vec2, angle: number): Vec2 {
  const x = point[0] - pivot[0], y = point[1] - pivot[1];
  return [pivot[0] + x * Math.cos(angle) - y * Math.sin(angle), pivot[1] + x * Math.sin(angle) + y * Math.cos(angle)];
}
