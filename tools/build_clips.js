// Builds www/assets/clips.json: the player's and the walkers' locomotion clips, from Nightfall
// Settlement's raw Mixamo clips (the same 13-bone rig and convention as the city's people).
// Backward clips play the forward clip in reverse, as Nightfall does for an unarmed figure.
//   node tools/build_clips.js <path to Nightfall-Settlement>
import fs from 'node:fs';
import path from 'node:path';

const dir = process.argv[2];
if (!dir) {
  console.error('usage: node tools/build_clips.js <Nightfall-Settlement dir>');
  process.exit(1);
}
const load = (file, name) => new Function(fs.readFileSync(path.join(dir, 'js', file), 'utf8') + `;return ${name}`)();
const MAIN = load('anims.js', 'MIXAMO_CLIPS');
const LIB = load('anims_lib.js', 'MIXAMO_LIB');
const source = (key) => MAIN[key] || LIB[key];

const BONES = ['hips', 'spine', 'head', 'shoulderL', 'shoulderR', 'elbowL', 'elbowR', 'handL', 'handR', 'hipL', 'hipR', 'kneeL', 'kneeR'];
// Tiles per second, as the game moves people: walk 0.36 and run 1.4.
const WALK = 0.36;
const RUN = 1.4;
const CLIPS = {
  walk: { from: 'walk', speed: WALK },
  run: { from: 'run', speed: RUN },
  walkBack: { from: 'walk', speed: WALK, reversed: true },
  runBack: { from: 'run', speed: RUN, reversed: true },
  strafeWalkP: { from: 'strafePW', speed: WALK },
  strafeWalkN: { from: 'strafeNW', speed: WALK },
  strafeRunP: { from: 'strafeP', speed: RUN },
  strafeRunN: { from: 'strafeN', speed: RUN },
};

// Euler XYZ (three.js order) to a quaternion [x, y, z, w].
function quat(x, y, z) {
  const c1 = Math.cos(x / 2), c2 = Math.cos(y / 2), c3 = Math.cos(z / 2);
  const s1 = Math.sin(x / 2), s2 = Math.sin(y / 2), s3 = Math.sin(z / 2);
  return [
    s1 * c2 * c3 + c1 * s2 * s3,
    c1 * s2 * c3 - s1 * c2 * s3,
    c1 * c2 * s3 + s1 * s2 * c3,
    c1 * c2 * c3 - s1 * s2 * s3,
  ];
}
const round = (v) => Math.round(v * 10000) / 10000;

const out = { bones: BONES, clips: {} };
for (const [name, spec] of Object.entries(CLIPS)) {
  const c = source(spec.from);
  const frames = c.n; // the last frame repeats the first in a loop
  const quats = [];
  const hipY = [];
  const hipZ = [];
  for (let i = 0; i < frames; i++) {
    const f = spec.reversed ? frames - 1 - i : i;
    for (const bone of BONES) {
      const [x, y, z] = c.t[bone][f];
      for (const v of quat(x, y, z)) quats.push(round(v));
    }
    hipY.push(round(c.t.hipsY[f]));
    hipZ.push(round(c.t.hipsZ[f]));
  }
  out.clips[name] = {
    frames,
    stride: round(spec.speed * c.d), // tiles covered by one cycle at this speed
    hipY,
    hipZ,
    quats,
  };
}
fs.mkdirSync('www/assets', { recursive: true });
fs.writeFileSync('www/assets/clips.json', JSON.stringify(out));
console.log(`wrote www/assets/clips.json: ${Object.keys(out.clips).length} clips`);
