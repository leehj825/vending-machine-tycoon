/* global THREE */
// The person: a low-poly figure of 13 bones, each a group in the hierarchy below, with boxes
// hung on them. The same body as the Flutter version (vexmarch's civilian figure).
import { CONFIG } from './config.js';

const PARENT = [-1, 0, 1, 1, 1, 3, 4, 5, 6, 0, 0, 9, 10];
// Every body part is a blocky box: one shared unit cube, stretched to the part's size, with a
// dark shell behind it for the outline, as in the bright cartoon style.
const BODY = new THREE.BoxGeometry(1, 1, 1);
const OUTLINE_FILL = new THREE.MeshBasicMaterial({ color: 0x1d1412, side: THREE.BackSide });
const EYE = 0x1d1412;
// A soft shadow on the ground under each person.
const SHADOW = new THREE.CircleGeometry(0.6, 20);
const SHADOW_MATERIAL = new THREE.MeshBasicMaterial({ color: 0x000000, transparent: true, opacity: 0.2, depthWrite: false });
// Each bone's offset from its parent at rest. The hips sit above the legs at rest.
// The clips were made for hips at 0.9; the hips here rest at 0.68, so their heights are scaled.
const CLIP_HIP_HEIGHT = 0.9;
const HIP_HEIGHT = 0.68;
const HIP_SCALE = HIP_HEIGHT / CLIP_HIP_HEIGHT;
const OFFSET = [
  [0, HIP_HEIGHT, 0], [0, 0.37, 0], [0, 0.13, 0], [-0.36, -0.01, 0], [0.36, -0.01, 0],
  [0, -0.32, 0], [0, -0.32, 0], [0, -0.32, 0], [0, -0.32, 0],
  [-0.13, -0.04, 0], [0.13, -0.04, 0], [0, -0.36, 0], [0, -0.36, 0],
];
const HIPS = 0;
const SHOULDER_L = 3;
const SHOULDER_R = 4;
const HIP_L = 9;
const HIP_R = 10;
const ELBOW_L = 5;
const ELBOW_R = 6;
const KNEE_L = 11;
const KNEE_R = 12;
const HEAD = 2;
const SPINE = 1;

const SKIN = 0xe2b88e;
const PANTS = 0x4b4036;
const BOOT = 0x2e241c;
const GLASSES = 0x263238;
export const FIGURE_SCALE = 0.15;

// Rest position of each bone, in figure space: the sum of its offsets down the hierarchy.
function restPositions() {
  const rest = [];
  for (let b = 0; b < PARENT.length; b++) {
    const o = OFFSET[b];
    const p = PARENT[b] < 0 ? [0, 0, 0] : rest[PARENT[b]];
    rest.push([p[0] + o[0], p[1] + o[1], p[2] + o[2]]);
  }
  return rest;
}

// The head is a cube centred at y 1.5, half 0.32, so its top is at 1.82. Each hair piece is a
// block hung on the head bone: [HEAD, centre, half size, colour, shape, flat]. `flat` pieces are
// drawn without an outline shell.
const hair = (centre, half, colour) => [HEAD, centre, half, colour];
const detail = (centre, half, colour) => [HEAD, centre, half, colour, BODY, true];

// The cap of hair over the top, a fringe of height h across the forehead, a panel down the back
// for len, and panels down the sides for len.
const top = (colour, thick = 0.04) => hair([0, 1.84, -0.01], [0.33, thick, 0.33], colour);
const fringe = (colour, h) => hair([0, 1.82 - h + 0.0, 0.31], [0.33, h, 0.02], colour);
const back = (colour, len) => hair([0, 1.84 - len / 2, -0.3], [0.33, len / 2, 0.04], colour);
const sides = (colour, len, out = 0.015) => [-1, 1].map((side) => hair([side * (0.31 + out), 1.82 - len / 2, -0.02], [out, len / 2, 0.29], colour));

// Each hair style, as the pieces it is made of. c is the hair colour, a the accent colour (a cap,
// or a band or tie in the hair).
const HAIR = {
  crop: (c) => [top(c), fringe(c, 0.07), back(c, 0.3), ...sides(c, 0.28)],
  sidePart: (c) => [
    top(c, 0.05), hair([-0.1, 1.75, 0.31], [0.23, 0.07, 0.02], c), hair([0.2, 1.79, 0.31], [0.13, 0.03, 0.02], c),
    back(c, 0.34), ...sides(c, 0.3),
  ],
  buzz: (c) => [hair([0, 1.83, -0.01], [0.325, 0.025, 0.325], c), back(c, 0.2), ...sides(c, 0.18)],
  spiky: (c) => [
    top(c), fringe(c, 0.05), back(c, 0.3), ...sides(c, 0.26),
    ...[-2, -1, 0, 1, 2].map((i) => hair([i * 0.13, 1.93 + (i === 0 ? 0.06 : Math.abs(i) === 1 ? 0.03 : 0), 0], [0.04, 0.08 + (i === 0 ? 0.04 : 0), 0.04], c)),
  ],
  bald: (c) => [hair([0, 1.42, -0.3], [0.33, 0.08, 0.04], c), ...[-1, 1].map((side) => hair([side * 0.325, 1.42, -0.02], [0.015, 0.08, 0.29], c))],
  cap: (c, a) => [
    hair([0, 1.85, 0], [0.34, 0.06, 0.34], a), hair([0, 1.79, 0.4], [0.3, 0.02, 0.1], a),
    back(c, 0.3), ...sides(c, 0.22),
  ],
  ponytail: (c, a) => [
    top(c), fringe(c, 0.07), back(c, 0.45), ...sides(c, 0.3),
    hair([0, 1.66, -0.36], [0.06, 0.04, 0.04], a), hair([0, 1.5, -0.44], [0.07, 0.18, 0.06], c),
  ],
  long: (c) => [top(c), fringe(c, 0.07), back(c, 0.62), ...sides(c, 0.55)],
  bob: (c) => [top(c), fringe(c, 0.09), back(c, 0.5), ...sides(c, 0.5, 0.045)],
  bun: (c) => [top(c), fringe(c, 0.07), back(c, 0.3), ...sides(c, 0.3), hair([0, 1.97, -0.18], [0.1, 0.1, 0.1], c)],
  braids: (c, a) => [
    top(c), fringe(c, 0.07), back(c, 0.36), ...sides(c, 0.3),
    ...[-1, 1].flatMap((side) => [hair([side * 0.22, 1.3, -0.3], [0.05, 0.2, 0.05], c), hair([side * 0.22, 1.08, -0.3], [0.06, 0.03, 0.06], a)]),
  ],
  curly: (c) => [
    hair([0, 1.93, 0], [0.37, 0.11, 0.36], c), fringe(c, 0.05),
    ...[-1, 1].map((side) => hair([side * 0.38, 1.62, -0.02], [0.06, 0.2, 0.3], c)),
    hair([0, 1.55, -0.38], [0.37, 0.3, 0.07], c),
  ],
  pigtails: (c, a) => [
    top(c), fringe(c, 0.07), back(c, 0.3), ...sides(c, 0.3),
    ...[-1, 1].flatMap((side) => [hair([side * 0.42, 1.5, 0], [0.06, 0.2, 0.06], c), hair([side * 0.42, 1.68, 0], [0.07, 0.03, 0.07], a)]),
  ],
  bowl: (c) => [top(c, 0.045), fringe(c, 0.1), back(c, 0.4), ...sides(c, 0.35)],
};

// The extras on the face and chest: glasses, a beard, a moustache, a tie, a stripe on the shirt.
function extras(look) {
  const parts = [];
  if (look.glasses) {
    for (const sx of [-0.11, 0.11]) {
      parts.push(
        detail([sx, 1.575, 0.335], [0.075, 0.012, 0.01], GLASSES),
        detail([sx, 1.465, 0.335], [0.075, 0.012, 0.01], GLASSES),
        detail([sx * 1.68, 1.52, 0.335], [0.012, 0.05, 0.01], GLASSES),
        detail([sx * 0.32, 1.52, 0.335], [0.012, 0.05, 0.01], GLASSES),
      );
    }
  }
  if (look.beard) parts.push([HEAD, [0, 1.3, 0.31], [0.26, 0.13, 0.04], look.hair, BODY, true]);
  if (look.moustache) parts.push(detail([0, 1.405, 0.33], [0.13, 0.03, 0.015], look.hair));
  if (look.tie) {
    parts.push([SPINE, [0, 1.05, 0.155], [0.045, 0.15, 0.012], look.tie, BODY, true], [SPINE, [0, 1.19, 0.155], [0.055, 0.03, 0.015], look.tie, BODY, true]);
  }
  if (look.stripe) parts.push([SPINE, [0, 0.94, 0.152], [0.27, 0.035, 0.004], 0xffffff, BODY, true]);
  return parts;
}

// The parts of the body, each with the bone it hangs on, its centre and half size in figure
// space, and its colour role.
function bodyParts(rest, look) {
  const skin = look.skin ?? SKIN;
  const pants = look.pants ?? PANTS;
  // Proportions as in the cartoon style: a cube head as wide as the torso, a box torso, arms
  // that reach the hips, and short legs.
  const parts = [
    [HIPS, [0, 0.7, 0], [0.26, 0.07, 0.15], pants],
    [SPINE, [0, 0.94, 0], [0.27, 0.24, 0.15], look.shirt],
    [HEAD, [0, 1.5, 0], [0.32, 0.32, 0.32], skin],
    ...(HAIR[look.hairStyle] ?? HAIR.crop)(look.hair, look.cap ?? look.hair),
    [HEAD, [-0.11, 1.52, 0.322], [0.035, 0.04, 0.015], EYE, BODY, true],
    [HEAD, [0.11, 1.52, 0.322], [0.035, 0.04, 0.015], EYE, BODY, true],
    ...extras(look),
  ];
  for (const [shoulder, elbow, hip, knee] of [
    [SHOULDER_L, ELBOW_L, HIP_L, KNEE_L],
    [SHOULDER_R, ELBOW_R, HIP_R, KNEE_R],
  ]) {
    const sx = rest[shoulder][0];
    const hx = rest[hip][0];
    parts.push(
      [shoulder, [sx, 0.9, 0], [0.075, 0.14, 0.075], look.shirt],
      [elbow, [sx, 0.58, 0], [0.075, 0.14, 0.075], skin],
      [hip, [hx, 0.46, 0], [0.13, 0.18, 0.13], pants],
      [knee, [hx, 0.12, 0], [0.13, 0.16, 0.13], pants],
      [knee, [hx, 0.05, 0.04], [0.13, 0.05, 0.15], BOOT],
    );
  }
  return parts;
}

// A figure in the scene. Its root sits on the ground at its position, turned by yaw. Heads are a
// little smaller than the model's, and kids are smaller all over with a head that is large for
// their body.
export function createFigure(look) {
  const rest = restPositions();
  const root = new THREE.Group();
  root.scale.setScalar(FIGURE_SCALE * (look.kid ? CONFIG.kidScale : 1));
  const shadow = new THREE.Mesh(SHADOW, SHADOW_MATERIAL);
  shadow.rotation.x = -Math.PI / 2;
  shadow.position.y = 0.01;
  root.add(shadow);
  const bones = [];
  for (let b = 0; b < PARENT.length; b++) {
    const group = new THREE.Group();
    group.position.set(OFFSET[b][0], OFFSET[b][1], OFFSET[b][2]);
    (PARENT[b] < 0 ? root : bones[PARENT[b]]).add(group);
    bones.push(group);
  }
  // The head bone sits at the neck, so scaling it shrinks the head and its hair toward the neck.
  bones[HEAD].scale.setScalar(look.kid ? CONFIG.kidHeadScale * CONFIG.headScale : CONFIG.headScale);
  const materials = [];
  for (const [bone, centre, half, colour, shape = BODY, flat = false] of bodyParts(rest, look)) {
    const material = new THREE.MeshLambertMaterial({ color: colour, emissive: colour, emissiveIntensity: 0.35 });
    materials.push(material);
    const mesh = new THREE.Mesh(shape, material);
    mesh.scale.set(half[0] * 2, half[1] * 2, half[2] * 2);
    if (shape === BODY && !flat) {
      const shell = new THREE.Mesh(BODY, OUTLINE_FILL);
      shell.scale.setScalar(1.14);
      mesh.add(shell);
    }
    mesh.position.set(centre[0] - rest[bone][0], centre[1] - rest[bone][1], centre[2] - rest[bone][2]);
    bones[bone].add(mesh);
  }
  return {
    root,
    bones,
    dispose() {
      for (const m of materials) m.dispose();
    },
  };
}

// Places the figure and sets its bones from a pose: quats is 13 bones of x, y, z, w, and the
// hips sit at hipY and hipZ.
export function poseFigure(figure, x, z, yaw, pose) {
  figure.root.position.set(x, 0, z);
  figure.root.rotation.y = yaw;
  for (let b = 0; b < figure.bones.length; b++) {
    figure.bones[b].quaternion.set(pose.quats[b * 4], pose.quats[b * 4 + 1], pose.quats[b * 4 + 2], pose.quats[b * 4 + 3]);
  }
  figure.bones[HIPS].position.set(OFFSET[HIPS][0], pose.hipY * HIP_SCALE, pose.hipZ);
}
