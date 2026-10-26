/* global THREE */
// The map's markers in the bright cartoon style: a bright ball over each shop front that can take a
// machine (green when the cash covers it, yellow when not), a blue plate on a shop with a machine,
// and a round gold coin over a machine that holds cash. Each has a dark outline.
import { CONFIG } from './config.js';
import { districtOf } from './world.js';
import { machineAnchor, markerHeight } from './scene.js';
import { lit, MACHINE_SCALE } from './machine3d.js';

const AFFORDABLE = 0x00e676;
const UNAFFORDABLE = 0xffea00;
const OWNED = 0x1e88e5;
const COIN = 0xf2b632;
const OUTLINE = new THREE.MeshBasicMaterial({ color: 0x1d1412, side: THREE.BackSide });
// The coin floats just above the machine's top.
const COIN_HEIGHT = 1.0 * MACHINE_SCALE + 0.12;

const HEAD = new THREE.SphereGeometry(0.2, 16, 12);
const COIN_DISC = new THREE.CylinderGeometry(0.15, 0.15, 0.06, 18);
const PLATE = new THREE.BoxGeometry(0.22, 0.06, 0.22);

// A mesh with its dark outline: the same shape, a little larger, drawn behind.
function outlined(geometry, colour) {
  const group = new THREE.Group();
  group.add(new THREE.Mesh(geometry, lit(colour)));
  const shell = new THREE.Mesh(geometry, OUTLINE);
  shell.scale.setScalar(1.12);
  group.add(shell);
  return group;
}

// A bright ball hovering above a shop front that can take a machine, clear of the roof.
function pin(x, h, z, colour) {
  const group = new THREE.Group();
  group.position.set(x, h, z);
  const ball = outlined(HEAD, colour);
  ball.position.y = 0.32;
  group.add(ball);
  return group;
}

// The blue plate on a shop front that has a machine.
function plate(x, h, z) {
  const group = new THREE.Group();
  group.position.set(x, h + 0.03, z);
  group.add(outlined(PLATE, OWNED));
  return group;
}

// A round gold coin above a machine that holds cash.
function coin(x, y, z) {
  const group = new THREE.Group();
  group.position.set(x, y, z);
  group.add(outlined(COIN_DISC, COIN));
  return group;
}

// Every marker for the state, as one group.
export function buildMarkers3d(state) {
  const root = new THREE.Group();
  const machineAt = new Set(state.machines.map((m) => `${m.x},${m.y}`));
  const affordable = state.cash >= CONFIG.machinePrice;
  state.city.forEach((row, y) => row.forEach((cell, x) => {
    if (cell.type !== 'building') return;
    // A district without its permit has no purchase markers.
    if (!(state.districts?.[districtOf(x, y)] ?? true)) return;
    const h = markerHeight(cell.zone);
    if (machineAt.has(`${x},${y}`)) root.add(plate(x + 0.5, h, y + 0.5));
    else root.add(pin(x + 0.5, h, y + 0.5, affordable ? AFFORDABLE : UNAFFORDABLE));
  }));
  for (const machine of state.machines) {
    if (machine.cash <= 0) continue;
    const anchor = machineAnchor(state.city, machine.x, machine.y);
    root.add(coin(anchor.x, COIN_HEIGHT, anchor.z));
  }
  return root;
}
