import { clamp } from './rig.js';

export class Spring {
  value = 0;
  velocity = 0;

  update(target: number, delta: number, stiffness = 100, damping = 16): number {
    // Small integration steps keep the soft tissue stable at slower frame rates.
    const steps = Math.max(1, Math.ceil(delta / .008));
    const dt = clamp(delta / steps, 0, .008);
    for (let step = 0; step < steps; step++) {
      this.velocity += ((target - this.value) * stiffness - this.velocity * damping) * dt;
      this.value += this.velocity * dt;
    }
    return this.value;
  }

  reset(value: number): number {
    this.value = value;
    this.velocity = 0;
    return value;
  }
}
