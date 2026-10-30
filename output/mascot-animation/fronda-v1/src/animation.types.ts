export type Vec2 = readonly [number, number];
export type Vec3 = readonly [number, number, number];
export type StateId = 'idle' | 'working' | 'attention' | 'success' | 'error' | 'guide';

export interface MascotState {
  id: StateId;
  label: string;
  detail: string;
  color: Vec3;
  pose: readonly number[];
  message: string;
  action: string;
}

export interface MotionFrame {
  angles: Float32Array;
  caps: Float32Array;
  bends: Float32Array;
  growth: Float32Array;
  blooms: Float32Array;
  filaments: Float32Array;
  tips: Float32Array;
  color: Float32Array;
  gaze: Vec2;
  body: readonly [number, number, number, number];
  position: Vec2;
  blink: number;
  time: number;
}

export interface Point { x: number; y: number }
export interface InteractionState {
  gaze: Point;
  offset: Point;
  velocity: Point;
  hover: number;
  dragging: boolean;
  touch: { branch: number; at: number } | null;
}
