/* global THREE */
// The person: a low-poly figure of 13 bones, each a group in the hierarchy below, with boxes
// hung on them. The same body as the Flutter version (vexmarch's civilian figure).
const PARENT = [-1, 0, 1, 1, 1, 3, 4, 5, 6, 0, 0, 9, 10];
// The dark outline that every figure part carries, as in the bright cartoon style.
const OUTLINE_MATERIAL = new THREE.LineBasicMaterial({ color: 0x1d1412 });
// Each bone's offset from its parent at rest. The hips sit above the legs at rest.
const OFFSET = [
  [0, 0.9, 0], [0, 0.05, 0], [0, 0.66, 0], [-0.34, 0.58, 0], [0.34, 0.58, 0],
  [0, -0.3, 0], [0, -0.3, 0], [0, -0.3, 0], [0, -0.3, 0],
  [-0.14, -0.04, 0], [0.14, -0.04, 0], [0, -0.45, 0], [0, -0.45, 0],
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
const SLEEVE = 0xffffff;
const BAG = 0x3e2723;
export const FIGURE_SCALE = 0.13;

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
  const parts = [
    [HIPS, [0, 0.9, 0], [0.19, 0.1, 0.11], PANTS],
    [SPINE, [0, 1.3, 0], [0.25, 0.3, 0.135], look.shirt],
    [HEAD, [0, 1.78, 0], [0.105, 0.115, 0.105], SKIN],
    [HEAD, [0, 1.9, -0.01], [0.12, 0.04, 0.12], look.hat],
    [SPINE, [0, 1.3, -0.19], [0.2, 0.24, 0.055], BAG],
  ];
  for (const [shoulder, elbow, hip, knee] of [
    [SHOULDER_L, ELBOW_L, HIP_L, KNEE_L],
    [SHOULDER_R, ELBOW_R, HIP_R, KNEE_R],
  ]) {
    const sx = rest[shoulder][0];
    const hx = rest[hip][0];
    parts.push(
      [shoulder, [sx, 1.39, 0], [0.07, 0.155, 0.07], SLEEVE],
      [elbow, [sx, 1.05, 0], [0.0575, 0.19, 0.0575], SKIN],
      [hip, [hx, 0.64, 0], [0.09, 0.23, 0.1], PANTS],
      [knee, [hx, 0.2, 0], [0.0775, 0.21, 0.085], PANTS],
      [knee, [hx, 0.04, 0.045], [0.085, 0.05, 0.14], BOOT],
    );
  }
  return parts;
}

// A figure in the scene. Its root sits on the ground at its position, turned by yaw.
export function createFigure(look) {
  const rest = restPositions();
  const root = new THREE.Group();
  root.scale.setScalar(FIGURE_SCALE);
  const bones = [];
  for (let b = 0; b < PARENT.length; b++) {
    const group = new THREE.Group();
    group.position.set(OFFSET[b][0], OFFSET[b][1], OFFSET[b][2]);
    (PARENT[b] < 0 ? root : bones[PARENT[b]]).add(group);
    bones.push(group);
  }
  const geometries = [];
  for (const [bone, centre, half, colour] of bodyParts(rest, look)) {
    const geometry = new THREE.BoxGeometry(half[0] * 2, half[1] * 2, half[2] * 2);
    geometries.push(geometry);
    const mesh = new THREE.Mesh(geometry, new THREE.MeshLambertMaterial({ color: colour, emissive: colour, emissiveIntensity: 0.35, flatShading: true }));
    const edges = new THREE.EdgesGeometry(geometry, 30);
    geometries.push(edges);
    mesh.add(new THREE.LineSegments(edges, OUTLINE_MATERIAL));
    mesh.position.set(centre[0] - rest[bone][0], centre[1] - rest[bone][1], centre[2] - rest[bone][2]);
    bones[bone].add(mesh);
  }
  return {
    root,
    bones,
    dispose() {
      for (const g of geometries) g.dispose();
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
  figure.bones[HIPS].position.set(OFFSET[HIPS][0], pose.hipY, pose.hipZ);
}
