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

// The machine is drawn at this share of its model size, so it fits its shop front.
export const MACHINE_SCALE = 0.65;

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
