/* global THREE */
// The person: a low-poly figure of 13 bones, each a group in the hierarchy below, with boxes
// hung on them. The same body as the Flutter version (vexmarch's civilian figure).
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
  [0, HIP_HEIGHT, 0], [0, 0.37, 0], [0, 0.07, 0], [-0.36, -0.01, 0], [0.36, -0.01, 0],
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
const BAG = 0x3e2723;
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

// The parts of the body, each with the bone it hangs on, its centre and half size in figure
// space, and its colour role.
function bodyParts(rest, look) {
  // Proportions as in the cartoon style: a cube head as wide as the torso, a box torso, arms
  // that reach the hips, and short legs.
  const parts = [
    [HIPS, [0, 0.7, 0], [0.26, 0.07, 0.15], PANTS],
    [SPINE, [0, 0.92, 0], [0.27, 0.2, 0.15], look.shirt],
    [SPINE, [0, 0.95, -0.2], [0.2, 0.2, 0.05], BAG],
    [HEAD, [0, 1.44, 0], [0.32, 0.32, 0.32], SKIN],
    // Hair: a cap over the top and a fringe, and the back of the head all the way down.
    [HEAD, [0, 1.78, -0.01], [0.33, 0.04, 0.33], look.hat],
    [HEAD, [0, 1.7, 0.31], [0.33, 0.06, 0.02], look.hat],
    [HEAD, [0, 1.44, -0.3], [0.33, 0.34, 0.04], look.hat],
    // The sides of the head, flush with the cube, so they read as hair from the side.
    [HEAD, [-0.325, 1.44, -0.02], [0.015, 0.32, 0.29], look.hat],
    [HEAD, [0.325, 1.44, -0.02], [0.015, 0.32, 0.29], look.hat],
    [HEAD, [-0.11, 1.46, 0.322], [0.02, 0.025, 0.012], EYE],
    [HEAD, [0.11, 1.46, 0.322], [0.02, 0.025, 0.012], EYE],
  ];
  for (const [shoulder, elbow, hip, knee] of [
    [SHOULDER_L, ELBOW_L, HIP_L, KNEE_L],
    [SHOULDER_R, ELBOW_R, HIP_R, KNEE_R],
  ]) {
    const sx = rest[shoulder][0];
    const hx = rest[hip][0];
    parts.push(
      [shoulder, [sx, 0.88, 0], [0.095, 0.16, 0.095], look.shirt],
      [elbow, [sx, 0.56, 0], [0.095, 0.16, 0.095], SKIN],
      [hip, [hx, 0.46, 0], [0.11, 0.18, 0.11], PANTS],
      [knee, [hx, 0.12, 0], [0.11, 0.16, 0.11], PANTS],
      [knee, [hx, 0.05, 0.04], [0.11, 0.05, 0.15], BOOT],
    );
  }
  return parts;
}

// A figure in the scene. Its root sits on the ground at its position, turned by yaw.
export function createFigure(look) {
  const rest = restPositions();
  const root = new THREE.Group();
  root.scale.setScalar(FIGURE_SCALE);
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
  const materials = [];
  for (const [bone, centre, half, colour, shape = BODY] of bodyParts(rest, look)) {
    const material = new THREE.MeshLambertMaterial({ color: colour, emissive: colour, emissiveIntensity: 0.35 });
    materials.push(material);
    const mesh = new THREE.Mesh(shape, material);
    mesh.scale.set(half[0] * 2, half[1] * 2, half[2] * 2);
    if (shape === BODY) {
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
