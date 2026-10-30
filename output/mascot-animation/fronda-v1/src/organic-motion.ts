import type { InteractionState, MotionFrame, StateId } from './animation.types.js';
import { Spring } from './motion-spring.js';
import { clamp } from './rig.js';

interface TissueProfile {
  length: number;
  spread: number;
  pulse: number;
  pace: number;
  curl: number;
}

const PROFILES: Record<StateId, TissueProfile> = {
  idle: { length: .01, spread: .01, pulse: .075, pace: .80, curl: .025 },
  working: { length: .025, spread: .025, pulse: .095, pace: 1.12, curl: .07 },
  attention: { length: .025, spread: .025, pulse: .055, pace: .92, curl: .10 },
  success: { length: .055, spread: .09, pulse: .07, pace: .94, curl: -.04 },
  error: { length: -.135, spread: -.11, pulse: .035, pace: .63, curl: .26 },
  guide: { length: .015, spread: .025, pulse: .065, pace: .86, curl: .055 },
};

interface TissueInput {
  state: StateId;
  time: number;
  age: number;
  delta: number;
  intensity: number;
  paused: boolean;
  reduced: boolean;
  interaction: InteractionState;
  angularVelocity: readonly number[];
}

export class OrganicMotion {
  private readonly lengths = Array.from({ length: 5 }, () => new Spring());
  private readonly curves = Array.from({ length: 5 }, () => new Spring());
  private readonly blooms = Array.from({ length: 5 }, () => new Spring());
  private readonly curls = Array.from({ length: 5 }, () => new Spring());
  private readonly extensions = Array.from({ length: 5 }, () => new Spring());
  private gestureStarted = -20;

  cancelGesture(): void { this.gestureStarted = -20; }

  unfurl(time: number): void { this.gestureStarted = time; }

  apply(frame: MotionFrame, input: TissueInput): void {
    const { state, time, age, intensity, interaction, reduced, paused } = input;
    const profile = PROFILES[state];
    const animate = !paused && !reduced;
    const update = (spring: Spring, target: number, stiffness: number, damping: number): number => {
      if (reduced) return spring.reset(target);
      return paused ? spring.value : spring.update(target, input.delta, stiffness, damping);
    };

    for (let branch = 0; branch < 5; branch++) {
      const side = branch === 1 || branch === 2 ? -1 : 1;
      const phase = time * profile.pace - branch * 1.18;
      const pulse = animate ? Math.sin(phase) * .73 + Math.sin(phase * .47 + branch * .83) * .27 : 0;
      const gestureAge = time - this.gestureStarted - branch * .14;
      // A slow swell travels outwards; the tissue then contracts and settles.
      const unfurl = animate && gestureAge > 0 && gestureAge < 5.4
        ? Math.sin(gestureAge / 5.4 * Math.PI * 2) * Math.sin(gestureAge / 5.4 * Math.PI) : 0;
      const arrival = animate && state === 'success' && age < 2.8 ? Math.sin(age / 2.8 * Math.PI) : 0;
      let touch = 0;
      if (animate && interaction.touch) {
        const local = time - interaction.touch.at - Math.abs(branch - interaction.touch.branch) * .14;
        if (local > 0 && local < 3) touch = Math.sin(local * 8.5) * Math.exp(-local * 1.65);
      }
      const hover = animate && interaction.hover === branch ? .038 : 0;
      const dragCompression = animate ? clamp(interaction.velocity.y * .045, -.05, .05) : 0;
      const guiding = state === 'guide' && branch === 3 ? .065 : 0;
      const lengthTarget = clamp((profile.length + pulse * profile.pulse + unfurl * .27 + arrival * .075 + touch * .09 + hover + guiding - dragCompression) * intensity, -.23, .23);
      const spreadTarget = clamp((profile.spread + pulse * .058 + unfurl * .19 + touch * .085) * intensity, -.18, .18);
      const curveTarget = reduced ? side * profile.curl * .28 : clamp((Math.sin(phase - .8) * .16 + unfurl * side * .22 + touch * side * .18 + profile.curl * side) * intensity, -.36, .36);
      const velocity = input.angularVelocity[branch] ?? 0;
      const dragLag = animate ? clamp(interaction.velocity.x * -.16, -.20, .20) : 0;
      const curlTarget = (profile.curl * side + (animate ? Math.sin(phase - 1.3) * .065 - velocity * .075 + touch * .23 + dragLag : 0)) * intensity;
      const extensionTarget = clamp((profile.length * .45 + pulse * .08 + unfurl * .19 + touch * .09) * intensity, -.16, .18);

      const stiffness = branch === 0 ? 19 : branch < 3 ? 24 : 29;
      frame.growth[branch] = update(this.lengths[branch]!, lengthTarget, stiffness, 9);
      frame.bends[branch] = update(this.curves[branch]!, curveTarget, 30, 10);
      frame.blooms[branch] = update(this.blooms[branch]!, spreadTarget, 20, 9);
      frame.filaments[branch * 4] = update(this.curls[branch]!, curlTarget, 35, 8);
      frame.filaments[branch * 4 + 1] = update(this.extensions[branch]!, extensionTarget, 18, 8);
      frame.filaments[branch * 4 + 2] = frame.blooms[branch]! * .75;
      frame.filaments[branch * 4 + 3] = reduced ? 0 : intensity * (state === 'working' ? .15 : state === 'error' ? .075 : .12);
    }
  }
}
