/* global THREE */
// The houses in the bright cartoon style: rounded cottages with a gabled roof, a porch,
// shutters and flower boxes. Each stands on its tile, turned to face its road. The shop fronts,
// ground and streets are drawn by scene.js.
import { cellNoise, frontTurns, isBuildingCell } from './scene.js';
import { lit, part, roundedSolid } from './machine3d.js';

const GLASS = 0xbfe7f2;
const FRAME = 0xf5f7fa;
const DOOR = 0x6d4c41;
const SHUTTER = 0x2e7d32;
const FLOWERS = 0xf06292;
const STONE = 0xd7ccc8;
const HOUSE_WALLS = [0xf3e9d2, 0xbfe0f0, 0xd7eccb, 0xf6d5cf];
const HOUSE_ROOFS = [0xe53935, 0x6d4c41, 0x37474f, 0xd84315];


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

// A house: a rounded cottage in a random wall colour, a gabled roof, windows with shutters and
// flower boxes, a porch with posts, and a chimney on some roofs.
function addHouse(group, x, y) {
  const v = cellNoise(x, y);
  const w = cellNoise(y + 3, x + 5);
  const wall = HOUSE_WALLS[Math.floor(v * HOUSE_WALLS.length) % HOUSE_WALLS.length];
  const roof = HOUSE_ROOFS[Math.floor(w * HOUSE_ROOFS.length) % HOUSE_ROOFS.length];
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
  // Window tops: one row on a one-floor house, two rows on a two-floor one.
  for (const top of twoFloors ? [0.36, 0.7] : [0.36]) {
    for (const wx of [-0.16, 0.16]) windowOn(group, wx, top, front + 0.005, 0.1, 0.12, { shutters: true, flowers: true });
  }
  if (w > 0.5) {
    group.add(box(0.08, 0.3, 0.08, 0xb5523b, 0.2, eave + 0.1, -0.12));
    group.add(box(0.1, 0.04, 0.1, 0x9e9e94, 0.2, eave + 0.38, -0.12));
  }
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
