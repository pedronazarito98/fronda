import type { Vec2 } from './animation.types.js';
import { clamp } from './rig.js';

interface Filament {
  branch: number;
  root: Vec2;
  length: number;
  radius: number;
  phase: number;
}

// Each hanging tooth has its own root. The cap stays attached while the tip curls.
const GROUPS: readonly (readonly (readonly [number, number, number, number])[])[] = [
  [[.657,.198,.071,.020], [.681,.205,.100,.020], [.715,.212,.110,.020], [.748,.220,.101,.019], [.781,.232,.077,.019], [.810,.239,.045,.017]],
  [[.134,.320,.064,.019], [.165,.325,.087,.020], [.198,.338,.089,.021], [.231,.342,.076,.020], [.260,.346,.057,.019]],
  [[.157,.560,.063,.018], [.186,.566,.095,.021], [.216,.572,.102,.021], [.247,.574,.089,.020], [.275,.571,.065,.019]],
  [[.801,.500,.061,.018], [.830,.511,.083,.020], [.858,.516,.097,.020], [.886,.519,.088,.020], [.916,.513,.072,.018]],
  [[.691,.692,.062,.018], [.716,.708,.067,.020], [.740,.710,.095,.021], [.770,.713,.079,.020], [.798,.714,.065,.019]],
];

const FILAMENTS: readonly Filament[] = GROUPS.flatMap((group, branch) => group.map(([x, y, length, radius], index) => ({
  branch, root: [x, y] as const, length, radius, phase: index * 1.17 + branch * 1.71,
})));

export function filamentBinding(point: Vec2): readonly [number, number, number, number, number] {
  let selected: Filament | null = null;
  let influence = 0;
  for (const filament of FILAMENTS) {
    const progress = (point[1] - filament.root[1]) / filament.length;
    if (progress <= 0 || progress > 1.4) continue;
    const across = Math.abs(point[0] - filament.root[0]) / filament.radius;
    const falloff = 1 - clamp((across - .8) / .8, 0, 1);
    const attachment = clamp(progress / .65, 0, 1);
    const weight = falloff * falloff * (3 - 2 * falloff) * attachment * attachment * (3 - 2 * attachment);
    if (weight > influence) { influence = weight; selected = filament; }
  }
  return selected ? [selected.root[0], selected.root[1], influence, selected.phase, selected.branch] : [0, 0, 0, 0, -1];
}
