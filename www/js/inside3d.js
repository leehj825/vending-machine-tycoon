/* global THREE */
// The close-up of an open machine: a detailed machine drawn over the dimmed city in its own small
// scene. The camera eases in, the door swings open, and the shelves show the stock as little
// products (a can, a bag, a bar, a cup, a gadget, a sandwich) with the cash in the tray below.
// Taking the cash lifts the notes and coins out of the tray; a refill drops the new products
// onto the shelves, shelf by shelf.
import { PRODUCT_IDS } from './products.js';
import { CONFIG } from './config.js';
import { lit, part, roundedSolid } from './machine3d.js';

const W = 0.9;
const H = 1.7;
const D = 0.6;
const RED = 0xe53935;
const RED_DARK = 0xb71c1c;
const CREAM = 0xfff3e0;
const STEEL = 0xcfd8dc;
const DARK = 0x263238;
const GLASS = 0xcfeef8;
const BILL = 0x66bb6a;
const COIN = 0xf2b632;
// The top of each shelf's plank, from the top shelf down.
const SHELF_Y = [1.3, 0.9, 0.5];
const SHELF_THICK = 0.03;
const TRAY_TOP = 0.09;
const BACK_STEP = 0.04;
// A product shelf holds two products side by side, up to ten items each in two rows of five.
const MAX_ITEMS = 10;
const COLUMNS = 5;
const PER_ITEM = Math.ceil(CONFIG.machinePerProduct / MAX_ITEMS);
// How far the door swings, in radians, a little past a right angle.
const DOOR_ANGLE = 1.85;
// The width the camera fits around the machine and its open door.
const CAMERA_SPAN = 1.9;
const TAN_HALF_FOV = Math.tan((20 * Math.PI) / 180);

const smooth = (v) => {
  const x = Math.min(1, Math.max(0, v));
  return x * x * (3 - 2 * x);
};
// A repeatable pseudo-random number from an index: the same pile looks the same every time.
const rand = (i) => {
  const s = Math.sin(i * 12.9898) * 43758.5453;
  return s - Math.floor(s);
};

const OUTLINE = new THREE.MeshBasicMaterial({ color: 0x1d1412, side: THREE.BackSide });

// A coloured mesh with the game's dark cartoon outline: a shell of the same shape, a fixed
// thickness (edge) bigger on every side, drawn behind it.
function placed(geometry, colour, x, y, z, edge = 0.007) {
  const mesh = new THREE.Mesh(geometry, lit(colour));
  mesh.position.set(x, y, z);
  if (edge > 0) {
    geometry.computeBoundingBox();
    const size = geometry.boundingBox.getSize(new THREE.Vector3());
    const shell = new THREE.Mesh(geometry, OUTLINE);
    shell.scale.set(1 + (2 * edge) / Math.max(size.x, 1e-3), 1 + (2 * edge) / Math.max(size.y, 1e-3), 1 + (2 * edge) / Math.max(size.z, 1e-3));
    mesh.add(shell);
  }
  return mesh;
}
// Shapes that stand on y = 0 (in the item's own space), centred on x and z.
const slab = (w, h, d, colour, x = 0, y = 0, z = 0) => placed(new THREE.BoxGeometry(w, h, d), colour, x, y + h / 2, z);
const cylinder = (rt, rb, h, colour, x = 0, y = 0, z = 0) => placed(new THREE.CylinderGeometry(rt, rb, h, 14), colour, x, y + h / 2, z);
function group(...children) {
  const g = new THREE.Group();
  g.add(...children);
  return g;
}

// One little product each, about the size a hand would hold, standing on its shelf.
const ITEMS = {
  soda: () => group(
    cylinder(0.035, 0.035, 0.1, 0xe53935),
    cylinder(0.0365, 0.0365, 0.035, 0xffffff, 0, 0.03),
    cylinder(0.03, 0.035, 0.012, 0xeceff1, 0, 0.1),
  ),
  chips: () => group(
    slab(0.075, 0.12, 0.03, 0xfdd835),
    slab(0.08, 0.016, 0.034, 0xf9a825, 0, 0.12),
    slab(0.08, 0.016, 0.034, 0xf9a825),
    slab(0.05, 0.05, 0.004, 0xe53935, 0, 0.035, 0.016),
  ),
  proteinBar: () => group(
    slab(0.05, 0.11, 0.02, 0x6d4c41),
    slab(0.052, 0.03, 0.022, 0xffb300, 0, 0.04),
  ),
  coffee: () => group(
    placed(new THREE.CylinderGeometry(0.04, 0.03, 0.09, 14), 0x5d4037, 0, 0.045, 0),
    cylinder(0.043, 0.043, 0.014, 0xffffff, 0, 0.09),
    cylinder(0.0385, 0.0335, 0.03, 0xbcaaa4, 0, 0.03),
  ),
  techGadget: () => group(
    slab(0.07, 0.1, 0.026, 0x42a5f5),
    slab(0.056, 0.07, 0.005, 0x263238, 0, 0.018, 0.0135),
    cylinder(0.008, 0.008, 0.004, 0xeceff1, 0, 0.006, 0.0135),
  ),
  sandwich: () => group(
    slab(0.07, 0.016, 0.075, 0xd7a86e),
    slab(0.074, 0.01, 0.079, 0x66bb6a, 0, 0.016),
    slab(0.07, 0.01, 0.075, 0xe53935, 0, 0.026),
    slab(0.07, 0.008, 0.075, 0xfdd835, 0, 0.036),
    slab(0.07, 0.022, 0.075, 0xd7a86e, 0, 0.044),
  ),
};
const TAGS = {
  soda: 0xe53935,
  chips: 0xfdd835,
  proteinBar: 0x8d6e63,
  coffee: 0x5d4037,
  techGadget: 0x42a5f5,
  sandwich: 0xffb74d,
};

// The machine: cabinet, interior with shelves and lamp, the cash tray, and the hinged door.
function buildCabinet() {
  const root = new THREE.Group();
  root.add(part(roundedSolid(W, 0.06, D, 0.03, 0.01), RED_DARK, 0, 0, 0));
  root.add(part(roundedSolid(W, 0.06, D, 0.03, 0.01), RED_DARK, 0, H, 0));
  root.add(part(roundedSolid(0.05, H, D, 0.02, 0.008), RED, -(W / 2 - 0.025), 0, 0));
  root.add(part(roundedSolid(0.05, H, D, 0.02, 0.008), RED, W / 2 - 0.025, 0, 0));
  root.add(placed(new THREE.BoxGeometry(W - 0.1, H, 0.03), CREAM, 0, H / 2, -(D / 2 - 0.015)));
  for (const side of [-1, 1]) root.add(placed(new THREE.BoxGeometry(0.012, H, D - 0.05), CREAM, side * (W / 2 - 0.056), H / 2, 0));
  for (const y of SHELF_Y) {
    root.add(part(roundedSolid(W - 0.12, SHELF_THICK, D - 0.08, 0.01, 0.004), STEEL, 0, y, 0, { outline: false }));
    // The shelf's price strip along its front edge, one tag colour per product.
  }
  SHELF_Y.forEach((y, shelf) => {
    for (const side of [-1, 1]) {
      const product = PRODUCT_IDS[shelf * 2 + (side < 0 ? 0 : 1)];
      if (!product) continue;
      root.add(slab(0.36, 0.016, 0.006, TAGS[product], side * 0.21, y + 0.005, D / 2 - 0.045));
    }
  });
  // A low step behind the front row on each shelf side, so the back row shows over it.
  for (const y of SHELF_Y) {
    for (const side of [-1, 1]) root.add(slab(0.4, BACK_STEP, 0.17, STEEL, side * 0.21, y + SHELF_THICK, -0.08));
  }
  // The lamp under the top, so the inside is lit.
  root.add(slab(0.7, 0.02, 0.3, 0xffffff, 0, H - 0.04, 0));

  // The cash tray at the bottom: a dark pan with a low rim.
  root.add(slab(0.72, 0.03, 0.42, 0x37474f, 0, 0.06, 0.04));
  root.add(slab(0.72, 0.05, 0.02, 0x455a64, 0, TRAY_TOP - 0.02, 0.24));
  root.add(slab(0.02, 0.05, 0.42, 0x455a64, -0.35, TRAY_TOP - 0.02, 0.04));
  root.add(slab(0.02, 0.05, 0.42, 0x455a64, 0.35, TRAY_TOP - 0.02, 0.04));

  // The door hinges on the front's left edge.
  const door = new THREE.Group();
  door.position.set(-W / 2, 0, D / 2);
  door.add(part(roundedSolid(W, H, 0.05, 0.05, 0.02), RED, W / 2, 0, 0.0));
  door.add(part(roundedSolid(0.52, 0.8, 0.02, 0.04, 0.008), GLASS, W / 2 - 0.1, 0.62, 0.04, { outline: false }));
  door.add(part(roundedSolid(0.3, 0.12, 0.02, 0.02, 0.008), DARK, W / 2, 1.45, 0.04));
  door.add(slab(0.06, 0.1, 0.02, STEEL, W - 0.1, 0.62, 0.05));
  door.add(slab(0.14, 0.04, 0.02, DARK, W / 2, 0.14, 0.04));
  root.add(door);
  return { root, door };
}

export function createInsideView(container) {
  const canvas = document.createElement('canvas');
  canvas.className = 'inside-canvas';
  canvas.style.display = 'none';
  // Behind the walk buttons, over the city.
  container.insertBefore(canvas, container.firstChild);
  const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  renderer.outputColorSpace = THREE.LinearSRGBColorSpace;
  renderer.setClearColor(0x000000, 0);

  const scene = new THREE.Scene();
  scene.add(new THREE.AmbientLight(0xffffff, 0.75));
  const sun = new THREE.DirectionalLight(0xffffff, 0.55);
  sun.position.set(1.5, 3, 4);
  scene.add(sun);
  const camera = new THREE.PerspectiveCamera(40, 1, 0.1, 50);

  const cabinet = buildCabinet();
  scene.add(cabinet.root);
  const contents = new THREE.Group();
  const flyGroup = new THREE.Group();
  scene.add(contents, flyGroup);

  let openAmount = 0;
  let fitDistance = 4;
  let signature = '';
  let previous = null; // the items shown per product on the last rebuild, to animate the new ones in
  const cashPieces = [];
  const drops = [];
  const flying = [];

  function resize() {
    const w = Math.max(1, container.clientWidth);
    const h = Math.max(1, container.clientHeight);
    renderer.setSize(w, h, false);
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
    fitDistance = Math.max(2.8, CAMERA_SPAN / (2 * TAN_HALF_FOV * camera.aspect));
  }
  resize();
  if (typeof ResizeObserver !== 'undefined') new ResizeObserver(resize).observe(container);

  function clearContents() {
    for (const child of [...contents.children]) contents.remove(child);
    cashPieces.length = 0;
    drops.length = 0;
  }

  // Draws the stock and the cash. Products added since the last drawing drop in.
  function rebuild(machine) {
    clearContents();
    const counts = {};
    PRODUCT_IDS.forEach((product, i) => {
      const shelf = Math.min(SHELF_Y.length - 1, Math.floor(i / 2));
      const side = i % 2 === 0 ? -1 : 1;
      const count = Math.min(MAX_ITEMS, Math.ceil((machine.stock[product] ?? 0) / PER_ITEM));
      counts[product] = count;
      const had = previous ? previous[product] ?? 0 : count;
      for (let k = 0; k < MAX_ITEMS; k++) {
        const col = k % COLUMNS;
        const row = Math.floor(k / COLUMNS);
        const x = side * 0.21 + (col - 2) * 0.075;
        const z = 0.12 - row * 0.2;
        const y = SHELF_Y[shelf] + SHELF_THICK + (row === 0 ? 0 : BACK_STEP);
        if (k < count) {
          const item = ITEMS[product]();
          item.position.set(x, y, z);
          contents.add(item);
          if (previous && k >= had) {
            item.visible = false;
            drops.push({ mesh: item, y, delay: shelf * 0.25 + (k - had) * 0.07, t: 0 });
          }
        } else if (row === 0) {
          // An empty place: a faint square on the shelf.
          const ghost = new THREE.Mesh(
            new THREE.BoxGeometry(0.055, 0.004, 0.055),
            new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.35 }),
          );
          ghost.position.set(x, y + 0.002, z);
          contents.add(ghost);
        }
      }
    });
    previous = counts;

    // Cash: stacks of notes at the back of the tray, stacks of coins at the front.
    const notes = machine.cash > 0 ? Math.min(24, Math.ceil(machine.cash / 10)) : 0;
    const coins = machine.cash > 0 ? Math.min(15, Math.ceil(machine.cash / 4)) : 0;
    for (let j = 0; j < notes; j++) {
      const stack = j % 3;
      const level = Math.floor(j / 3);
      const note = placed(new THREE.BoxGeometry(0.2, 0.008, 0.09), BILL, -0.22 + stack * 0.22 + (rand(j) - 0.5) * 0.03, TRAY_TOP + 0.004 + level * 0.009, -0.04 + (rand(j + 50) - 0.5) * 0.03);
      note.rotation.y = (rand(j + 9) - 0.5) * 0.4;
      contents.add(note);
      cashPieces.push(note);
    }
    for (let j = 0; j < coins; j++) {
      const coin = placed(new THREE.CylinderGeometry(0.035, 0.035, 0.008, 16), COIN, -0.2 + (j % 5) * 0.1, TRAY_TOP + 0.004 + Math.floor(j / 5) * 0.009, 0.14);
      contents.add(coin);
      cashPieces.push(coin);
    }
  }

  // Shows the machine's inside. The first drawing has nothing dropping in.
  function show(machine) {
    previous = null;
    signature = '';
    update(machine);
  }

  // Redraws when the machine's stock or cash changed.
  function update(machine) {
    const next = `${machine.cash}|${PRODUCT_IDS.map((p) => machine.stock[p] ?? 0).join(',')}`;
    if (next === signature) return;
    signature = next;
    rebuild(machine);
  }

  // How far the front is open, from 0 (not shown) to 1 (wide open, camera close).
  function setOpen(value) {
    openAmount = value;
    const shown = value > 0;
    canvas.style.display = shown ? '' : 'none';
    canvas.style.opacity = String(Math.min(1, value * 2.5));
    if (!shown && flying.length > 0) {
      for (const f of flying) flyGroup.remove(f.mesh);
      flying.length = 0;
    }
  }

  // Lifts the cash out of the tray: the notes and coins fly up toward the viewer, one after another.
  function takeCash() {
    const target = new THREE.Vector3(0.6, 2.2, 1.4);
    cashPieces.forEach((piece, i) => {
      contents.remove(piece);
      flyGroup.add(piece);
      const to = target.clone().add(new THREE.Vector3((rand(i) - 0.5) * 0.5, (rand(i + 3) - 0.5) * 0.3, 0));
      flying.push({ mesh: piece, from: piece.position.clone(), to, delay: i * 0.03, t: 0, spin: (rand(i + 7) - 0.5) * 10 });
    });
    cashPieces.length = 0;
  }

  function frame(dt) {
    if (openAmount <= 0) return;
    for (let i = drops.length - 1; i >= 0; i--) {
      const d = drops[i];
      d.t += dt;
      if (d.t < d.delay) continue;
      const p = Math.min(1, (d.t - d.delay) / 0.35);
      d.mesh.visible = true;
      d.mesh.position.y = d.y + (1 - smooth(p)) * 0.35;
      if (p >= 1) drops.splice(i, 1);
    }
    for (let i = flying.length - 1; i >= 0; i--) {
      const f = flying[i];
      f.t += dt;
      if (f.t < f.delay) continue;
      const p = Math.min(1, (f.t - f.delay) / 0.8);
      const e = smooth(p);
      f.mesh.position.lerpVectors(f.from, f.to, e);
      f.mesh.position.y += Math.sin(Math.PI * e) * 0.25;
      f.mesh.rotation.x += dt * f.spin;
      f.mesh.scale.setScalar(1 - 0.7 * e);
      if (p >= 1) {
        flyGroup.remove(f.mesh);
        flying.splice(i, 1);
      }
    }
    cabinet.door.rotation.y = -DOOR_ANGLE * smooth((openAmount - 0.25) / 0.75);
    const distance = fitDistance * (1.7 - 0.7 * smooth(openAmount));
    camera.position.set(0.1, 1.2, distance);
    camera.lookAt(0, 0.8, 0);
    renderer.render(scene, camera);
  }

  return { show, update, setOpen, takeCash, frame };
}
