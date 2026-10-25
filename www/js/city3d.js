/* global THREE */
// The city in three.js: a low-poly map with roads, grass, buildings and machines. Taps report
// the grid cell that was touched; one-finger drags turn the view; pinch and wheel zoom.
import { ZONES } from './products.js';
import { WAREHOUSE_CELL, cellAt } from './world.js';
import { machineAt } from './sim.js';

const COLORS = {
  road: 0x3a3d44,
  pavement: 0xb9b4a8,
  grass: 0x6cbf5a,
  machine: 0x2d7ff9,
  cash: 0xffc107,
  warehouse: 0xe57c23,
  select: 0xffd54f,
};
const TAP_SLOP = 8;

export function createCityView(container, onTap) {
  const renderer = new THREE.WebGLRenderer({ antialias: true });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  container.appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  scene.background = new THREE.Color(0xa7d8f2);
  scene.add(new THREE.HemisphereLight(0xffffff, 0x556070, 0.9));
  const sun = new THREE.DirectionalLight(0xffffff, 0.8);
  sun.position.set(-6, 12, 8);
  scene.add(sun);

  const camera = new THREE.PerspectiveCamera(40, 1, 0.1, 200);
  const cityGroup = new THREE.Group();
  const machineGroup = new THREE.Group();
  const pickGroup = new THREE.Group();
  scene.add(cityGroup, machineGroup, pickGroup);

  const view = { target: new THREE.Vector3(7, 0, 7), yaw: 0.8, pitch: 0.9, distance: 20 };
  const limits = { near: 6, far: 40 };
  let city = null;
  let selected = null;
  let selectMesh = null;

  const material = (color) => new THREE.MeshLambertMaterial({ color, flatShading: true });
  const box = (w, h, d, color, x, y, z) => {
    const mesh = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), material(color));
    mesh.position.set(x, y, z);
    return mesh;
  };

  // Builds the static parts of a city: streets, grass, buildings, and the pick plates.
  function buildCity(grid) {
    clear(cityGroup);
    clear(pickGroup);
    grid.forEach((row, y) => row.forEach((cell, x) => {
      const cx = x + 0.5;
      const cz = y + 0.5;
      if (cell.type === 'road') {
        cityGroup.add(box(1, 0.05, 1, COLORS.road, cx, 0.025, cz));
      } else if (cell.type === 'grass') {
        cityGroup.add(box(1, 0.08, 1, COLORS.grass, cx, 0.04, cz));
      } else {
        cityGroup.add(box(1, 0.08, 1, COLORS.pavement, cx, 0.04, cz));
        const zone = ZONES[cell.zone];
        cityGroup.add(box(0.8, zone.height, 0.8, zone.color, cx, zone.height / 2, cz));
      }
      const plate = new THREE.Mesh(
        new THREE.PlaneGeometry(1, 1),
        new THREE.MeshBasicMaterial({ transparent: true, opacity: 0, depthWrite: false }),
      );
      plate.rotation.x = -Math.PI / 2;
      plate.position.set(cx, 0.12, cz);
      plate.userData.cell = { x, y };
      pickGroup.add(plate);
    }));
    const depot = cellAt(grid, WAREHOUSE_CELL.x, WAREHOUSE_CELL.y);
    if (depot) cityGroup.add(box(0.5, 0.4, 0.5, COLORS.warehouse, WAREHOUSE_CELL.x + 0.5, 0.25, WAREHOUSE_CELL.y + 0.5));
    selectMesh = new THREE.Mesh(
      new THREE.PlaneGeometry(1, 1),
      new THREE.MeshBasicMaterial({ color: COLORS.select, transparent: true, opacity: 0.55, depthWrite: false }),
    );
    selectMesh.rotation.x = -Math.PI / 2;
    selectMesh.position.y = 0.13;
    selectMesh.visible = false;
    cityGroup.add(selectMesh);
    view.target.set(grid.length / 2, 0, grid.length / 2);
  }

  // Machines and their takings, drawn on the building's front. Rebuilt when the machines change.
  function drawMachines(state) {
    clear(machineGroup);
    for (const m of state.machines) {
      const zone = ZONES[m.zone];
      const x = m.x + 0.5;
      const z = m.y + 0.5;
      machineGroup.add(box(0.36, 0.5, 0.2, COLORS.machine, x, zone.height + 0.25, z + 0.35));
      if (m.cash > 0) machineGroup.add(box(0.14, 0.14, 0.14, COLORS.cash, x, zone.height + 0.65, z + 0.35));
    }
  }

  function clear(group) {
    while (group.children.length) {
      const child = group.children.pop();
      child.geometry?.dispose();
      child.material?.dispose();
    }
  }

  function setSelected(cell) {
    selected = cell;
    if (!selectMesh) return;
    selectMesh.visible = Boolean(cell);
    if (cell) selectMesh.position.set(cell.x + 0.5, 0.13, cell.y + 0.5);
  }

  // Redraws the city when its map changes, and the machines when they change.
  function update(state) {
    if (state.city !== city) {
      city = state.city;
      buildCity(city);
      setSelected(selected);
    }
    drawMachines(state);
  }

  // Camera: orbit around the target, zoomed by distance, and clamped to a sensible range.
  function applyCamera() {
    const cp = Math.cos(view.pitch);
    camera.position.set(
      view.target.x + view.distance * Math.sin(view.yaw) * cp,
      view.target.y + view.distance * Math.sin(view.pitch),
      view.target.z + view.distance * Math.cos(view.yaw) * cp,
    );
    camera.lookAt(view.target);
  }

  function resize() {
    const w = container.clientWidth || 1;
    const h = container.clientHeight || 1;
    renderer.setSize(w, h, false);
    renderer.domElement.style.width = `${w}px`;
    renderer.domElement.style.height = `${h}px`;
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
  }

  // Touch and mouse: one pointer drags the view, two pinch the zoom, and a short press picks.
  const pointers = new Map();
  let downAt = null;
  let moved = false;
  let pinch = null;
  const canvas = renderer.domElement;

  canvas.addEventListener('pointerdown', (e) => {
    canvas.setPointerCapture(e.pointerId);
    pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
    if (pointers.size === 1) {
      downAt = { x: e.clientX, y: e.clientY };
      moved = false;
    }
    pinch = pointers.size === 2 ? distance() : null;
  });

  canvas.addEventListener('pointermove', (e) => {
    const prev = pointers.get(e.pointerId);
    if (!prev) return;
    pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
    if (pointers.size === 1) {
      if (downAt && Math.hypot(e.clientX - downAt.x, e.clientY - downAt.y) > TAP_SLOP) moved = true;
      view.yaw -= (e.clientX - prev.x) * 0.008;
      view.pitch = Math.min(1.45, Math.max(0.35, view.pitch + (e.clientY - prev.y) * 0.006));
    } else if (pointers.size === 2 && pinch) {
      const now = distance();
      if (now > 0) zoom(pinch / now);
      pinch = now;
      moved = true;
    }
  });

  const release = (e) => {
    const wasTap = pointers.size === 1 && !moved && downAt;
    pointers.delete(e.pointerId);
    pinch = null;
    if (wasTap && e.type === 'pointerup') pick(e.clientX, e.clientY);
    if (pointers.size === 0) downAt = null;
  };
  canvas.addEventListener('pointerup', release);
  canvas.addEventListener('pointercancel', release);
  canvas.addEventListener('wheel', (e) => {
    e.preventDefault();
    zoom(Math.exp(e.deltaY * 0.001));
  }, { passive: false });

  function distance() {
    const [a, b] = [...pointers.values()];
    return a && b ? Math.hypot(a.x - b.x, a.y - b.y) : 0;
  }

  function zoom(factor) {
    view.distance = Math.min(limits.far, Math.max(limits.near, view.distance * factor));
  }

  const raycaster = new THREE.Raycaster();
  const ndc = new THREE.Vector2();
  function pick(clientX, clientY) {
    const rect = canvas.getBoundingClientRect();
    ndc.set(((clientX - rect.left) / rect.width) * 2 - 1, -((clientY - rect.top) / rect.height) * 2 + 1);
    raycaster.setFromCamera(ndc, camera);
    const hit = raycaster.intersectObjects(pickGroup.children, false)[0];
    if (hit) onTap(hit.object.userData.cell);
  }

  window.addEventListener('resize', resize);
  resize();
  function frame() {
    applyCamera();
    renderer.render(scene, camera);
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);

  return {
    update,
    setSelected,
    machineAt: (state, cell) => machineAt(state, cell.x, cell.y),
  };
}
