import type { InteractionState, MotionFrame, StateId } from './animation.types.js';
import { clamp } from './rig.js';
import { stateFor } from './states.js';
import { Spring } from './motion-spring.js';
import { OrganicMotion } from './organic-motion.js';

export class MascotMotion {
  state: StateId = 'idle';
  intensity = 1;
  speed = 1;
  paused = false;
  reduced = false;
  time = 0;
  elapsed = 0;
  private readonly tissue = new OrganicMotion();
  private frozenFrame: MotionFrame | null = null;
  private readonly branches = Array.from({ length: 5 }, () => new Spring());
  private readonly crowns = Array.from({ length: 5 }, () => new Spring());
  private readonly pigment = Array.from({ length: 5 }, () => new Spring());
  private readonly colors = Array.from({ length: 3 }, () => new Spring());
  private readonly gazeX = new Spring();
  private readonly gazeY = new Spring();
  private readonly lean = new Spring();
  private readonly scale = new Spring();
  private nextBlink = 2.7;
  private blinkStarted = -10;
  readonly interaction: InteractionState = {
    gaze: { x: 0, y: 0 }, offset: { x: 0, y: 0 }, velocity: { x: 0, y: 0 }, hover: -1, dragging: false, touch: null,
  };

  constructor() { this.colors.forEach((spring, index) => spring.reset(stateFor('idle').color[index]!)); this.scale.reset(1); }

  select(state: StateId): void {
    this.state = state;
    this.tissue.cancelGesture();
    this.elapsed = 0;
    this.interaction.touch = null;
  }

  touch(branch: number): void { this.interaction.touch = { branch, at: this.time }; }

  unfurl(): void { this.tissue.unfurl(this.time); }

  step(delta: number): MotionFrame {
    if (this.paused && !this.reduced && this.frozenFrame) {
      return { ...this.frozenFrame, position: [this.interaction.offset.x, this.interaction.offset.y] };
    }
    const dt = clamp(delta, .001, .032);
    const animate = !this.paused && !this.reduced;
    if (animate) { this.time += dt * this.speed; this.elapsed += dt * this.speed; }
    const t = this.time, age = this.elapsed, state = stateFor(this.state);
    const frame: MotionFrame = {
      angles: new Float32Array(5), caps: new Float32Array(5), tips: new Float32Array(5), color: new Float32Array(3),
      bends: new Float32Array(5), growth: new Float32Array(5), blooms: new Float32Array(5), filaments: new Float32Array(20),
      gaze: [0, 0], body: [0, 1, 0, 0], position: [this.interaction.offset.x, this.interaction.offset.y], blink: 1, time: t,
    };
    let lean = 0, stretch = 1, jump = 0;
    if (this.state === 'success' && animate && age < 1.8) {
      if (age < .28) stretch = 1 - Math.sin(age / .28 * Math.PI / 2) * .07;
      else if (age < 1.1) { jump = Math.sin((age - .28) / .82 * Math.PI) * .092; stretch = 1.045; }
      else stretch = 1 - Math.sin((age - 1.1) / .7 * Math.PI) * .045;
    }
    if (this.state === 'error') stretch = .955;
    if (animate) lean = Math.sin(t * .9) * .012;
    lean += this.interaction.gaze.x * .024;
    if (this.interaction.dragging && !this.reduced) lean += clamp(this.interaction.velocity.x * .14, -.10, .10);
    if (this.state === 'guide') lean -= .02;

    for (let i = 0; i < 5; i++) {
      let angle = state.pose[i]!, tip = .07, cap = 0;
      const phase = t * 1.55 - i * .87;
      if (animate) {
        angle += Math.sin(phase) * (this.state === 'working' ? .07 : .032);
        angle += Math.sin(t * .77 + i * 1.9) * .016;
        cap += Math.sin(phase - .85) * .06;
        if (this.state === 'idle') {
          const stretchCycle = t % 15;
          if (stretchCycle > 8 && stretchCycle < 12) angle += Math.sin((stretchCycle - 8) / 4 * Math.PI) * (i === 0 ? -.26 : i % 2 ? .12 : -.09);
        }
        if (this.state === 'attention' && age < 2.2) angle += Math.sin(age * 8.2) * Math.sin(age / 2.2 * Math.PI) * (i === 0 ? .28 : -.055);
        if (this.state === 'success' && age < 1.8) angle += Math.sin(age / 1.8 * Math.PI) * (i < 3 ? .14 : -.18);
        const touch = this.interaction.touch;
        if (touch) {
          const distance = Math.abs(i - touch.branch), local = t - touch.at - distance * .09;
          if (local > 0 && local < 2) { angle += Math.sin(local * 9) * Math.exp(-local * 2.5) * .20; cap += Math.sin(local * 9 - .9) * Math.exp(-local * 2.2) * .14; }
        }
        if (this.interaction.hover === i) angle += this.interaction.gaze.x * .15 + this.interaction.gaze.y * .06;
        angle -= clamp(this.interaction.velocity.x * .28, -.26, .26) * (i === 0 ? 1 : .65);
      }
      if (this.state === 'working') tip = this.reduced ? .62 : .16 + Math.pow((Math.sin(phase) + 1) / 2, 3) * .77;
      if (this.state === 'attention') tip = i === 0 ? .94 : age < 2.2 ? .74 : .25;
      if (this.state === 'success') tip = .88;
      if (this.state === 'error') tip = .86;
      if (this.state === 'guide') tip = i === 3 ? .95 : .045;
      if (this.interaction.hover === i) tip = Math.max(tip, .80);
      const touch = this.interaction.touch;
      if (touch && animate) {
        const local = t - touch.at - Math.abs(i - touch.branch) * .09;
        if (local > 0 && local < 1) tip = Math.max(tip, .95 * Math.exp(-local * 2));
      }
      if (this.reduced) { frame.angles[i] = this.branches[i]!.reset(state.pose[i]! * this.intensity); frame.caps[i] = this.crowns[i]!.reset(0); }
      else if (this.paused) { frame.angles[i] = this.branches[i]!.value; frame.caps[i] = this.crowns[i]!.value; }
      else { frame.angles[i] = this.branches[i]!.update(angle * this.intensity, dt); frame.caps[i] = this.crowns[i]!.update(cap * this.intensity + frame.angles[i]! * .28, dt, 66, 13); }
      frame.tips[i] = this.reduced ? this.pigment[i]!.reset(tip) : this.paused ? this.pigment[i]!.value : this.pigment[i]!.update(tip, dt, 70, 16);
    }
    this.tissue.apply(frame, {
      state: this.state, time: t, age, delta: dt, intensity: this.intensity,
      paused: this.paused, reduced: this.reduced, interaction: this.interaction,
      angularVelocity: this.branches.map(branch => branch.velocity),
    });
    this.interaction.velocity.x *= Math.exp(-dt * 9);
    this.interaction.velocity.y *= Math.exp(-dt * 9);
    for (let i = 0; i < 3; i++) frame.color[i] = this.colors[i]!.update(state.color[i]!, dt, 64, 16);
    if (animate && t > this.nextBlink) { this.blinkStarted = t; this.nextBlink = t + 3.4 + (Math.sin(t * 3) + 1) * 1.3; }
    const blinkAge = t - this.blinkStarted;
    if (animate && blinkAge < .19) frame.blink = 1 - Math.sin(blinkAge / .19 * Math.PI) * .94;
    frame.gaze = this.reduced ? [0, 0] : [this.gazeX.update(this.interaction.gaze.x, dt, 110, 19), this.gazeY.update(this.interaction.gaze.y, dt, 110, 19)];
    frame.body = this.reduced ? [0, stretch, 0, 0] : [this.lean.update(lean, dt), this.scale.update(stretch + (animate ? Math.sin(t * 1.10) * .015 : 0), dt), jump, this.interaction.dragging ? .012 : 0];
    this.frozenFrame = frame;
    return frame;
  }
}
