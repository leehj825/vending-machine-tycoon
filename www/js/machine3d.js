/* global THREE */
// The vending machine in the bright cartoon style: a rounded red cabinet with a dark outline, a
// display on top, a glass front with the products, and a coin slot. Built about its foot, on the
// road-side corner of its building, and turned to face the road.
import { PRODUCT_IDS } from './products.js';

const RED = 0xe53935;
const RED_DARK = 0xb71c1c;
const GLASS = 0xcfeef8;
const STEEL = 0xcfd8dc;
const DARK = 0x263238;
const EMPTY_SLOT = 0x7b8790;
const CASH_GREEN = 0x43a047;
const CASH_NONE = 0x9e9e9e;
const SLOT_COLOURS = {
  soda: 0xe53935,
  chips: 0xfdd835,
  proteinBar: 0x8d6e63,
  coffee: 0x5d4037,
  techGadget: 0x42a5f5,
  sandwich: 0xffb74d,
};

const OUTLINE = new THREE.MeshBasicMaterial({ color: 0x1d1412, side: THREE.BackSide });

// The machine is drawn at this share of its model size. Its height is 1.2 times a person's and
// lower than a building's.
export const MACHINE_SCALE = 0.34;

// A lit colour that keeps its brightness on the shaded faces, as the bright style does.
export function lit(colour) {
  return new THREE.MeshLambertMaterial({ color: colour, emissive: colour, emissiveIntensity: 0.4 });
}

// A rounded rectangle path in the x and y of a shape.
function roundedRect(shape, w, d, r) {
  const x = -w / 2;
  const y = -d / 2;
  shape.moveTo(x + r, y);
  shape.lineTo(x + w - r, y);
  shape.quadraticCurveTo(x + w, y, x + w, y + r);
  shape.lineTo(x + w, y + d - r);
  shape.quadraticCurveTo(x + w, y + d, x + w - r, y + d);
  shape.lineTo(x + r, y + d);
  shape.quadraticCurveTo(x, y + d, x, y + d - r);
  shape.lineTo(x, y + r);
  shape.quadraticCurveTo(x, y, x + r, y);
}

// A solid with rounded edges, standing on y = 0 and centred on x and z.
export function roundedSolid(w, h, d, radius, bevel) {
  const shape = new THREE.Shape();
  roundedRect(shape, w - 2 * bevel, d - 2 * bevel, Math.max(0.001, radius - bevel));
  const geometry = new THREE.ExtrudeGeometry(shape, {
    depth: Math.max(0.001, h - 2 * bevel),
    bevelEnabled: true,
    bevelThickness: bevel,
    bevelSize: bevel,
    bevelSegments: 3,
    curveSegments: 6,
  });
  geometry.rotateX(-Math.PI / 2);
  geometry.computeBoundingBox();
  const b = geometry.boundingBox;
  geometry.translate(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2);
  return geometry;
}

// A rounded part with its outline: a dark shell slightly larger, behind the colour.
export function part(geometry, colour, x, y, z, { outline = true } = {}) {
  const group = new THREE.Group();
  group.position.set(x, y, z);
  const mesh = new THREE.Mesh(geometry, lit(colour));
  group.add(mesh);
  if (outline) {
    const shell = new THREE.Mesh(geometry, OUTLINE);
    shell.scale.setScalar(1.05);
    group.add(shell);
  }
  return group;
}

// The machine for a machine record, at its anchor on the road-side corner. The front faces +z
// before turning, and the turn follows the building's (anchor.turns quarter turns).
export function buildMachine3d(machine, anchor) {
  const root = new THREE.Group();
  root.position.set(anchor.x, 0, anchor.z);
  root.scale.setScalar(MACHINE_SCALE);
  root.rotation.y = -(anchor.turns % 4) * (Math.PI / 2);

  const cabinet = roundedSolid(0.46, 0.92, 0.4, 0.1, 0.03);
  root.add(part(cabinet, RED, 0, 0, 0));
  root.add(part(roundedSolid(0.5, 0.08, 0.44, 0.05, 0.02), RED_DARK, 0, 0.92, 0));

  // The display on top of the front, lit green when the machine holds cash.
  root.add(part(roundedSolid(0.32, 0.12, 0.03, 0.02, 0.01), DARK, 0, 0.72, 0.2));
  const screen = new THREE.Mesh(new THREE.BoxGeometry(0.26, 0.06, 0.01), new THREE.MeshBasicMaterial({ color: machine.cash > 0 ? CASH_GREEN : CASH_NONE }));
  screen.position.set(0, 0.72, 0.215);
  root.add(screen);

  // The glass front, with a product in each slot: coloured when stocked, grey when empty.
  root.add(part(roundedSolid(0.34, 0.5, 0.02, 0.03, 0.005), GLASS, 0, 0.2, 0.2, { outline: false }));
  PRODUCT_IDS.forEach((product, i) => {
    const col = i % 2;
    const row = Math.floor(i / 2);
    const stocked = (machine.stock[product] ?? 0) > 0;
    const slot = new THREE.Mesh(new THREE.BoxGeometry(0.12, 0.1, 0.02), new THREE.MeshLambertMaterial({ color: stocked ? SLOT_COLOURS[product] : EMPTY_SLOT }));
    slot.position.set(-0.08 + col * 0.16, 0.27 + row * 0.15, 0.225);
    root.add(slot);
  });

  // The coin slot and the dispensing tray.
  const coins = new THREE.Mesh(new THREE.BoxGeometry(0.08, 0.1, 0.02), new THREE.MeshLambertMaterial({ color: STEEL }));
  coins.position.set(0.15, 0.56, 0.215);
  root.add(coins);
  const tray = new THREE.Mesh(new THREE.BoxGeometry(0.26, 0.06, 0.02), new THREE.MeshLambertMaterial({ color: DARK }));
  tray.position.set(0, 0.07, 0.215);
  root.add(tray);
  return root;
}

const OPEN_INSIDE = 0xf7f1e3;
const OPEN_SHELF = 0xa1887f;
const OPEN_COIN = 0xf2b632;
const SHELF_HEIGHTS = [0.28, 0.53, 0.78];
// How far the door swings, in radians: a little past a right angle.
export const DOOR_OPEN_ANGLE = 2.1;

// The machine with its front open: a red cabinet around a cream interior, three shelves with the
// stock on them, and the cash tray with its coins. The door hinges on the left of the front; its
// rotation is set by the caller (door.rotation.y = -DOOR_OPEN_ANGLE * t) to open it.
export function buildOpenMachine(machine, anchor) {
  const root = new THREE.Group();
  root.position.set(anchor.x, 0, anchor.z);
  root.scale.setScalar(MACHINE_SCALE);
  root.rotation.y = -(anchor.turns % 4) * (Math.PI / 2);
  const box = (group, w, h, d, x, y, z, colour) => {
    const mesh = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), lit(colour));
    mesh.position.set(x, y, z);
    group.add(mesh);
  };

  box(root, 0.46, 0.92, 0.02, 0, 0.46, -0.19, OPEN_INSIDE);
  box(root, 0.02, 0.92, 0.4, -0.23, 0.46, 0, RED);
  box(root, 0.02, 0.92, 0.4, 0.23, 0.46, 0, RED);
  box(root, 0.48, 0.04, 0.42, 0, 0.92, 0, RED_DARK);
  box(root, 0.48, 0.04, 0.42, 0, 0.02, 0, RED);
  for (const y of SHELF_HEIGHTS) box(root, 0.44, 0.025, 0.38, 0, y, 0, OPEN_SHELF);

  // Each product sits on its shelf: up to three items, one column for each of two products a shelf.
  PRODUCT_IDS.forEach((product, i) => {
    const shelfY = SHELF_HEIGHTS[Math.min(SHELF_HEIGHTS.length - 1, Math.floor(i / 2))];
    const count = Math.min(3, Math.ceil((machine.stock[product] ?? 0) / 7));
    const columnX = i % 2 === 0 ? -0.11 : 0.11;
    for (let k = 0; k < count; k++) {
      box(root, 0.06, 0.1, 0.1, columnX + (k - (count - 1) / 2) * 0.07, shelfY + 0.0625, 0, SLOT_COLOURS[product]);
    }
  });

  // The cash tray at the bottom right: a coin for every five dollars, up to ten.
  const coins = machine.cash > 0 ? Math.min(10, Math.ceil(machine.cash / 5)) : 0;
  for (let k = 0; k < coins; k++) {
    const coin = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.06, 0.02, 16), lit(OPEN_COIN));
    coin.position.set(0.12, 0.05 + k * 0.02, 0);
    root.add(coin);
  }

  // The door: a red panel with a window, hinged at the front's left edge.
  const door = new THREE.Group();
  door.position.set(-0.23, 0, 0.2);
  box(door, 0.46, 0.92, 0.03, 0.23, 0.46, 0, RED);
  box(door, 0.3, 0.5, 0.01, 0.23, 0.5, 0.02, GLASS);
  root.add(door);
  return { root, door };
}
