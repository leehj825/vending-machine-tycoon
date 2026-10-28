/* global THREE */
// The houses in the bright cartoon style: rounded cottages with a gabled roof, a porch,
// shutters and flower boxes. Each stands on its tile, turned to face its road. The shop fronts,
// ground and streets are drawn by scene.js.
import { cellNoise, frontTurns, isBuildingCell } from './scene.js';
import { lit, part, roundedSolid } from './machine3d.js';
import { districtOf } from './world.js';

const GLASS = 0xbfe7f2;
const FRAME = 0xf5f7fa;
const DOOR = 0x6d4c41;
const SHUTTER = 0x2e7d32;
const FLOWERS = 0xf06292;
const STONE = 0xd7ccc8;
// Each district has its own colours and its own mix of house designs: Downtown is cool and modern,
// Eastside warm and homely, Southside plain and dusty, Harbor pastel and seaside.
const DISTRICT_HOUSES = [
  { walls: [0xe3eaf2, 0xcfd8dc, 0xf0f0f0, 0xd6c6e1], roofs: [0x37474f, 0x546e7a, 0x3f51b5], kinds: ['townhouse', 'apartment', 'townhouse'] },
  { walls: [0xf3e9d2, 0xf6d5cf, 0xe0b79a, 0xd7eccb], roofs: [0xe53935, 0x6d4c41, 0xd84315], kinds: ['cottage', 'townhouse', 'cottage'] },
  { walls: [0xbcaaa4, 0xa1887f, 0x90a4ae, 0xcfc8b8], roofs: [0x4e342e, 0x37474f, 0x607d8b], kinds: ['bungalow', 'apartment', 'bungalow'] },
  { walls: [0xbfe0f0, 0xb2dfdb, 0xfff3c4, 0xf8bbd0], roofs: [0x00838f, 0x37474f, 0xe53935], kinds: ['bungalow', 'cottage', 'bungalow'] },
];
const CAR_COLOURS = [0xe53935, 0x1e88e5, 0xfdd835, 0xf5f5f5, 0x43a047, 0x8e24aa];
const PAVING = 0xb0a99a;


function box(w, h, d, colour, x, y, z) {
  const mesh = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), lit(colour));
  mesh.position.set(x, y + h / 2, z);
  return mesh;
}

// A solid bevelled prism from a flat outline, standing on y = 0 and centred on x and z.
function extruded(shape, depth, bevel) {
  const geometry = new THREE.ExtrudeGeometry(shape, {
    depth: Math.max(0.001, depth - 2 * bevel),
    bevelEnabled: true,
    bevelThickness: bevel,
    bevelSize: bevel,
    bevelSegments: 2,
    curveSegments: 2,
  });
  geometry.computeBoundingBox();
  const b = geometry.boundingBox;
  geometry.translate(-(b.min.x + b.max.x) / 2, -(b.min.y + b.max.y) / 2, -(b.min.z + b.max.z) / 2);
  return geometry;
}

// The gabled roof of a house: a triangle along z, running along x for the house's length.
function gableRoof(width, length, height) {
  const shape = new THREE.Shape();
  shape.moveTo(-width / 2, 0);
  shape.lineTo(width / 2, 0);
  shape.lineTo(0, height);
  shape.lineTo(-width / 2, 0);
  const geometry = extruded(shape, length, 0.02);
  geometry.rotateY(Math.PI / 2);
  geometry.computeBoundingBox();
  const b = geometry.boundingBox;
  geometry.translate(0, -b.min.y, 0);
  return geometry;
}

// A window on a face: a white frame, glass, and optional shutters and a flower box.
function windowOn(group, x, y, z, w, h, { shutters = false, flowers = false } = {}) {
  group.add(box(w + 0.03, h + 0.03, 0.02, FRAME, x, y - h / 2 - 0.015, z - 0.01));
  group.add(box(w, h, 0.02, GLASS, x, y - h / 2, z));
  if (shutters) {
    group.add(box(0.03, h, 0.02, SHUTTER, x - w / 2 - 0.035, y - h, z));
    group.add(box(0.03, h, 0.02, SHUTTER, x + w / 2 + 0.035, y - h, z));
  }
  if (flowers) group.add(box(w + 0.02, 0.04, 0.05, FLOWERS, x, y - h - 0.05, z + 0.03));
}

// A small car, nose along +z, for a driveway.
function parkedCar(group, x, z, colour) {
  group.add(box(0.16, 0.05, 0.3, colour, x, 0.02, z));
  group.add(box(0.13, 0.05, 0.16, colour, x, 0.07, z - 0.02));
  group.add(box(0.14, 0.03, 0.12, GLASS, x, 0.075, z - 0.02));
  for (const wx of [-0.085, 0.085]) for (const wz of [-0.09, 0.09]) group.add(box(0.025, 0.05, 0.05, 0x2b2f38, x + wx, 0, z + wz));
}

// A low white picket fence along the front of the garden, with a gap for the path.
function fence(group, z) {
  for (const [x0, x1] of [[-0.42, -0.1], [0.1, 0.42]]) {
    group.add(box(x1 - x0, 0.015, 0.015, FRAME, (x0 + x1) / 2, 0.09, z));
    for (let x = x0 + 0.02; x < x1; x += 0.06) group.add(box(0.015, 0.11, 0.015, FRAME, x, 0, z));
  }
}

function mailbox(group, x, z) {
  group.add(box(0.015, 0.1, 0.015, 0x6d4c41, x, 0, z));
  group.add(box(0.06, 0.04, 0.04, 0xe53935, x, 0.1, z));
}

// The designs, each standing on a tile with its front toward +z. size is the cottage's width.
const HOUSE_KINDS = {
  // A cottage: rounded walls, a gabled roof, a porch, shutters and flower boxes; sometimes a chimney.
  cottage(group, wall, roof, v, w) {
    const twoFloors = v > 0.6;
    const eave = twoFloors ? 0.8 : 0.5;
    const size = 0.6;
    group.add(part(roundedSolid(size, eave, size, 0.06, 0.02), wall, 0, 0, 0));
    group.add(part(roundedSolid(size + 0.04, 0.05, size + 0.04, 0.02, 0.01), 0xe0d2b4, 0, eave, 0, { outline: false }));
    group.add(part(gableRoof(size + 0.12, size + 0.12, 0.4), roof, 0, eave, 0));
    // The porch: a canopy on two white posts, over the door.
    group.add(box(0.4, 0.04, 0.2, roof, 0, 0.36, size / 2 + 0.1));
    group.add(box(0.03, 0.36, 0.03, FRAME, -0.18, 0, size / 2 + 0.18));
    group.add(box(0.03, 0.36, 0.03, FRAME, 0.18, 0, size / 2 + 0.18));
    group.add(box(0.12, 0.24, 0.02, DOOR, 0, 0, size / 2 + 0.01));
    group.add(box(0.5, 0.04, 0.12, STONE, 0, 0, size / 2 + 0.14));
    const front = size / 2;
    for (const top of twoFloors ? [0.36, 0.7] : [0.36]) {
      for (const wx of [-0.16, 0.16]) windowOn(group, wx, top, front + 0.005, 0.1, 0.12, { shutters: true, flowers: true });
    }
    if (w > 0.5) {
      group.add(box(0.08, 0.3, 0.08, 0xb5523b, 0.2, eave + 0.1, -0.12));
      group.add(box(0.1, 0.04, 0.1, 0x9e9e94, 0.2, eave + 0.38, -0.12));
    }
  },
  // A tall narrow townhouse: three floors, a flat roof with a parapet, a stoop and a balcony.
  townhouse(group, wall, roof, v) {
    group.add(part(roundedSolid(0.46, 0.95, 0.5, 0.04, 0.015), wall, 0, 0, -0.04));
    group.add(part(roundedSolid(0.5, 0.05, 0.54, 0.02, 0.01), roof, 0, 0.95, -0.04));
    group.add(box(0.4, 0.04, 0.2, STONE, 0, 0, 0.26));
    group.add(box(0.12, 0.24, 0.02, DOOR, -0.08, 0.02, 0.22));
    group.add(box(0.2, 0.03, 0.1, roof, -0.08, 0.3, 0.27));
    for (const top of [0.62, 0.9]) {
      for (const wx of [-0.1, 0.1]) windowOn(group, wx, top, 0.22, 0.1, 0.14, { shutters: v > 0.5, flowers: top < 0.7 });
    }
    windowOn(group, 0.1, 0.34, 0.22, 0.1, 0.14, {});
    group.add(box(0.3, 0.025, 0.1, STONE, 0, 0.5, 0.27));
    for (let x = -0.14; x <= 0.15; x += 0.07) group.add(box(0.012, 0.07, 0.012, FRAME, x, 0.525, 0.31));
    group.add(box(0.3, 0.012, 0.012, FRAME, 0, 0.595, 0.31));
    group.add(box(0.1, 0.1, 0.1, 0x9e9e94, 0.1, 1.0, -0.15));
  },
  // A small apartment block: a wide flat-roofed box with a grid of windows and a glass entrance.
  apartment(group, wall, roof, v) {
    group.add(part(roundedSolid(0.66, 1.1, 0.5, 0.03, 0.012), wall, 0, 0, 0));
    group.add(part(roundedSolid(0.7, 0.05, 0.54, 0.02, 0.01), roof, 0, 1.1, 0));
    for (const top of [0.34, 0.62, 0.9]) {
      for (const wx of [-0.2, 0, 0.2]) windowOn(group, wx, top, 0.255, 0.1, 0.13, {});
    }
    group.add(box(0.24, 0.05, 0.12, roof, 0, 0.26, 0.31));
    group.add(box(0.16, 0.2, 0.02, 0x2c3e50, 0, 0, 0.255));
    group.add(box(0.1, 0.1, 0.14, 0x9e9e94, -0.2, 1.15, -0.1));
    group.add(box(0.014, 0.18, 0.014, 0x9aa5b1, 0.22, 1.15, 0.1));
    if (v > 0.5) group.add(box(0.2, 0.04, 0.2, 0x4caf50, 0.17, 1.15, 0.05));
  },
  // A bungalow: long and low, with a gentle roof, a garage and a car on the drive.
  bungalow(group, wall, roof, v) {
    group.add(part(roundedSolid(0.62, 0.38, 0.46, 0.05, 0.02), wall, -0.02, 0, -0.06));
    group.add(part(gableRoof(0.7, 0.54, 0.22), roof, -0.02, 0.38, -0.06));
    group.add(box(0.2, 0.2, 0.02, 0x9aa5b1, 0.17, 0, 0.18));
    for (let gy = 0.04; gy < 0.2; gy += 0.05) group.add(box(0.2, 0.01, 0.022, 0x78909c, 0.17, gy, 0.18));
    group.add(box(0.12, 0.22, 0.02, DOOR, -0.2, 0, 0.18));
    windowOn(group, -0.2, 0.32, 0.185, 0.1, 0.1, { flowers: true });
    group.add(box(0.2, 0.01, 0.3, PAVING, 0.17, 0, 0.32));
    parkedCar(group, 0.17, 0.34, CAR_COLOURS[Math.floor(v * 6) % 6]);
  },
};

// A house: one of the designs for its district, in its colours, with a fence and a mailbox.
function addHouse(group, x, y) {
  const v = cellNoise(x, y);
  const w = cellNoise(y + 3, x + 5);
  const style = DISTRICT_HOUSES[districtOf(x, y)];
  const wall = style.walls[Math.floor(v * style.walls.length) % style.walls.length];
  const roof = style.roofs[Math.floor(w * style.roofs.length) % style.roofs.length];
  const kind = style.kinds[Math.floor(cellNoise(x + 9, y + 2) * style.kinds.length) % style.kinds.length];
  HOUSE_KINDS[kind](group, wall, roof, v, w);
  fence(group, 0.46);
  mailbox(group, 0.36, 0.44);
}

// Every building on the grid, each in a group on its tile and turned to face its road.
export function buildBuildings(grid) {
  const root = new THREE.Group();
  grid.forEach((row, y) => row.forEach((cell, x) => {
    if (cell.type !== 'house') return; // shop fronts are drawn with the static scene
    const turns = frontTurns(grid, x, y) ?? 0;
    const group = new THREE.Group();
    group.position.set(x + 0.5, 0, y + 0.5);
    group.rotation.y = -turns * (Math.PI / 2);
    addHouse(group, x, y);
    root.add(group);
  }));
  return root;
}
