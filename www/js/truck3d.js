/* global THREE */
// The delivery truck in the bright cartoon style: a tan cargo box, a white cab with a blue
// windscreen, an orange front, yellow headlights and dark wheels with grey hubs. Built around its
// middle, facing +z, the way it travels.
import { part, roundedSolid } from './machine3d.js';

const CARGO = 0xf2c79a;
const CAB = 0xf7f7f2;
const FRONT = 0xe8542e;
const GLASS = 0x42a5f5;
const LIGHT = 0xffd54f;
const TIRE = 0x263238;
const HUB = 0xcfd8dc;
const CHASSIS = 0x37474f;

const VAN = 0x42a5f5;
const VAN_STRIPE = 0xffffff;

// The box truck (design 0), or a van (design 1): one rounded body in blue with a white stripe, a
// raked windscreen, side windows and a roof rack.
export function buildTruck3d(design = 0) {
  const root = new THREE.Group();
  const add = (geometry, colour, x, y, z, options) => root.add(part(geometry, colour, x, y, z, options));
  if (design === 1) return buildVan(root, add);

  add(roundedSolid(0.28, 0.05, 0.62, 0.02, 0.01), CHASSIS, 0, 0.04, 0);
  add(roundedSolid(0.28, 0.32, 0.36, 0.05, 0.02), CARGO, 0, 0.09, -0.12);
  add(roundedSolid(0.28, 0.14, 0.2, 0.04, 0.02), FRONT, 0, 0.09, 0.2);
  add(roundedSolid(0.26, 0.16, 0.2, 0.05, 0.02), CAB, 0, 0.23, 0.2);
  add(new THREE.BoxGeometry(0.2, 0.08, 0.02), GLASS, 0, 0.25, 0.31, { outline: false });
  add(new THREE.BoxGeometry(0.05, 0.04, 0.02), LIGHT, -0.09, 0.13, 0.33, { outline: false });
  add(new THREE.BoxGeometry(0.05, 0.04, 0.02), LIGHT, 0.09, 0.13, 0.33, { outline: false });
  add(new THREE.BoxGeometry(0.3, 0.04, 0.04), CHASSIS, 0, 0.04, 0.34);

  const wheel = new THREE.CylinderGeometry(0.07, 0.07, 0.05, 12);
  wheel.rotateZ(Math.PI / 2);
  const hub = new THREE.CylinderGeometry(0.035, 0.035, 0.055, 8);
  hub.rotateZ(Math.PI / 2);
  for (const z of [-0.2, 0.2]) {
    for (const x of [-0.15, 0.15]) {
      add(wheel, TIRE, x, 0.07, z);
      add(hub, HUB, x, 0.07, z, { outline: false });
    }
  }
  return root;
}

function buildVan(root, add) {
  add(roundedSolid(0.28, 0.05, 0.58, 0.02, 0.01), CHASSIS, 0, 0.04, 0);
  add(roundedSolid(0.27, 0.26, 0.52, 0.06, 0.02), VAN, 0, 0.09, -0.02);
  add(roundedSolid(0.275, 0.05, 0.4, 0.02, 0.01), VAN_STRIPE, 0, 0.17, -0.06, { outline: false });
  add(new THREE.BoxGeometry(0.2, 0.09, 0.02), GLASS, 0, 0.25, 0.255, { outline: false });
  add(new THREE.BoxGeometry(0.02, 0.07, 0.14), GLASS, -0.14, 0.27, 0.12, { outline: false });
  add(new THREE.BoxGeometry(0.02, 0.07, 0.14), GLASS, 0.14, 0.27, 0.12, { outline: false });
  add(new THREE.BoxGeometry(0.05, 0.04, 0.02), LIGHT, -0.09, 0.14, 0.27, { outline: false });
  add(new THREE.BoxGeometry(0.05, 0.04, 0.02), LIGHT, 0.09, 0.14, 0.27, { outline: false });
  add(new THREE.BoxGeometry(0.22, 0.015, 0.3), CHASSIS, 0, 0.36, -0.1, { outline: false });
  for (const x of [-0.1, 0.1]) add(new THREE.BoxGeometry(0.015, 0.02, 0.3), CHASSIS, x, 0.35, -0.1, { outline: false });
  const wheel = new THREE.CylinderGeometry(0.065, 0.065, 0.05, 12);
  wheel.rotateZ(Math.PI / 2);
  const hub = new THREE.CylinderGeometry(0.03, 0.03, 0.055, 8);
  hub.rotateZ(Math.PI / 2);
  for (const z of [-0.18, 0.17]) {
    for (const x of [-0.14, 0.14]) {
      add(wheel, TIRE, x, 0.065, z);
      add(hub, HUB, x, 0.065, z, { outline: false });
    }
  }
  return root;
}
