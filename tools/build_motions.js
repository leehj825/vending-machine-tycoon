// Builds www/assets/motions.json: every human motion clip from Nightfall Settlement (main and
// library clips) and from Deepward, which are Nightfall's clips mirrored across X and are turned
// back here. Deepward clips that match a Nightfall clip are left out. Each clip keeps its own frames.
//   node tools/build_motions.js <Nightfall-Settlement dir> <Deepward dir>
import fs from 'node:fs';
import path from 'node:path';

const [nf, dw] = process.argv.slice(2);
if (!nf || !dw) {
  console.error('usage: node tools/build_motions.js <Nightfall-Settlement dir> <Deepward dir>');
  process.exit(1);
}
const load = (file, name) => new Function(fs.readFileSync(file, 'utf8') + `;return ${name}`)();
const NF_MAIN = load(path.join(nf, 'js/anims.js'), 'MIXAMO_CLIPS');
const NF_LIB = load(path.join(nf, 'js/anims_lib.js'), 'MIXAMO_LIB');
const DW = new Function(fs.readFileSync(path.join(dw, 'js/anims.js'), 'utf8') + ';return DW_ANIMS')();

const BONES = ['hips', 'spine', 'head', 'shoulderL', 'shoulderR', 'elbowL', 'elbowR', 'handL', 'handR', 'hipL', 'hipR', 'kneeL', 'kneeR'];

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
const r3 = (v) => Math.round(v * 1000) / 1000;

// Converts one source clip. mirror undoes Deepward's mirroring: (x, y, z) to (x, -y, -z).
function convert(c, mirror) {
  const frames = c.n;
  const quats = [];
  const hipY = [];
  const hipZ = [];
  for (let f = 0; f < frames; f++) {
    for (const bone of BONES) {
      let [x, y, z] = c.t[bone][f];
      if (mirror) [y, z] = [-y, -z];
      for (const v of quat(x, y, z)) quats.push(r3(v));
    }
    hipY.push(r3(c.t.hipsY[f]));
    hipZ.push(r3(c.t.hipsZ[f]));
  }
  return { frames, d: c.d, loop: !!c.loop, hipY, hipZ, quats };
}

const fingerprint = (clip) => clip.quats.map((v) => Math.round(v * 20)).join(',');

const motions = {};
const seen = new Map();
const add = (name, clip) => {
  const key = fingerprint(clip);
  if (seen.has(key)) return;
  seen.set(key, name);
  motions[name] = clip;
};

for (const [name, c] of Object.entries(NF_MAIN)) add(name, convert(c, false));
for (const [name, c] of Object.entries(NF_LIB)) add(name, convert(c, false));
for (const [name, c] of Object.entries(DW)) add(`dw_${name}`, convert(c, true));

const out = { bones: BONES, motions };
fs.mkdirSync('www/assets', { recursive: true });
fs.writeFileSync('www/assets/motions.json', JSON.stringify(out));
console.log(`wrote www/assets/motions.json: ${Object.keys(motions).length} motions (${seen.size} unique)`);
