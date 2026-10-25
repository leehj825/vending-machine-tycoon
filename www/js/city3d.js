/* global THREE */
// The city in three.js: the map with its streets, buildings and machines, the people on it, and
// the camera. Map view: taps pick a cell, drags turn the view, pinch and wheel zoom. Walk view:
// a camera behind the player, drags turn the player, pinch zooms.
import { ZONES } from './products.js';
import { WAREHOUSE_CELL, cellAt } from './world.js';
import { createFigure, poseFigure } from './figure.js';

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
const WALK_DISTANCE = { start: 3.2, near: 1.4, far: 9 };
const MAP_DISTANCE = { start: 20, near: 6, far: 40 };

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
  const figureGroup = new THREE.Group();
  const vehicleGroup = new THREE.Group();
  scene.add(cityGroup, machineGroup, pickGroup, figureGroup, vehicleGroup);

  // The map view and the walk view share one camera: yaw and the target are common, the
  // distance and pitch belong to the mode.
  const cam = { target: new THREE.Vector3(7, 0, 7), yaw: 0.8, pitch: 0.9, distance: MAP_DISTANCE.start };
  const walk = { on: false, follow: null, distance: WALK_DISTANCE.start };
  let city = null;
  let selected = null;
  let selectMesh = null;
  const figures = new Map();
  const vehicles = new Map();

  const material = (color) => new THREE.MeshLambertMaterial({ color, flatShading: true });
  const box = (w, h, d, color, x, y, z) => {
    const mesh = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), material(color));
    mesh.position.set(x, y, z);
    return mesh;
  };

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
    if (cellAt(grid, WAREHOUSE_CELL.x, WAREHOUSE_CELL.y)) {
      cityGroup.add(box(0.5, 0.4, 0.5, COLORS.warehouse, WAREHOUSE_CELL.x + 0.5, 0.25, WAREHOUSE_CELL.y + 0.5));
    }
    selectMesh = new THREE.Mesh(
      new THREE.PlaneGeometry(1, 1),
      new THREE.MeshBasicMaterial({ color: COLORS.select, transparent: true, opacity: 0.55, depthWrite: false }),
    );
    selectMesh.rotation.x = -Math.PI / 2;
    selectMesh.position.y = 0.13;
    selectMesh.visible = false;
    cityGroup.add(selectMesh);
    cam.target.set(grid.length / 2, 0, grid.length / 2);
  }

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

  function update(state) {
    if (state.city !== city) {
      city = state.city;
      buildCity(city);
      setSelected(selected);
    }
    drawMachines(state);
  }

  // The people: one figure per key, placed and posed each frame, and removed when they leave.
  // people is a list of { key, x, z, yaw, pose, look }.
  function drawPeople(people) {
    const seen = new Set();
    for (const person of people) {
      seen.add(person.key);
      let figure = figures.get(person.key);
      if (!figure) {
        figure = createFigure(person.look);
        figures.set(person.key, figure);
        figureGroup.add(figure.root);
      }
      poseFigure(figure, person.x, person.z, person.yaw, person.pose);
    }
    for (const [key, figure] of figures) {
      if (seen.has(key)) continue;
      figureGroup.remove(figure.root);
      figure.dispose();
      figures.delete(key);
    }
  }

  // Trucks on the road: a box per truck, turned to its heading. positions is a list of
  // { key, x, z, yaw }.
  function drawVehicles(positions) {
    const seen = new Set();
    for (const p of positions) {
      seen.add(p.key);
      let mesh = vehicles.get(p.key);
      if (!mesh) {
        mesh = box(0.42, 0.28, 0.6, COLORS.warehouse, 0, 0.2, 0);
        vehicles.set(p.key, mesh);
        vehicleGroup.add(mesh);
      }
      mesh.position.set(p.x, 0.2, p.z);
      mesh.rotation.y = p.yaw;
    }
    for (const [key, mesh] of vehicles) {
      if (seen.has(key)) continue;
      vehicleGroup.remove(mesh);
      mesh.geometry.dispose();
      mesh.material.dispose();
      vehicles.delete(key);
    }
  }

  // Walk view: the camera follows the player's spot, with the player's own facing.
  function setWalking(on) {
    walk.on = on;
    if (on) {
      walk.distance = WALK_DISTANCE.start;
      cam.pitch = 0.5;
    } else {
      cam.distance = MAP_DISTANCE.start;
      cam.pitch = 0.9;
      cam.target.set(city ? city.length / 2 : 7, 0, city ? city.length / 2 : 7);
    }
  }

  function follow(x, z) {
    walk.follow = { x, z };
  }

  // The facing a player takes from the camera: straight away from it.
  function walkFacing() {
    return cam.yaw - Math.PI;
  }

  function cameraYaw() {
    return cam.yaw;
  }

  function applyCamera() {
    const cp = Math.cos(cam.pitch);
    camera.position.set(
      cam.target.x + cam.distance * Math.sin(cam.yaw) * cp,
      cam.target.y + cam.distance * Math.sin(cam.pitch),
      cam.target.z + cam.distance * Math.cos(cam.yaw) * cp,
    );
    camera.lookAt(cam.target);
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

  // Pointers: one drags the view (in walk view it turns the player), two pinch the zoom, and a
  // short press picks a cell (map view only).
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
      cam.yaw -= (e.clientX - prev.x) * 0.008;
      if (!walk.on) cam.pitch = Math.min(1.45, Math.max(0.35, cam.pitch + (e.clientY - prev.y) * 0.006));
    } else if (pointers.size === 2 && pinch) {
      const now = distance();
      if (now > 0) zoom(pinch / now);
      pinch = now;
      moved = true;
    }
  });

  const release = (e) => {
    const wasTap = pointers.size === 1 && !moved && downAt && !walk.on;
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
    if (walk.on) {
      walk.distance = Math.min(WALK_DISTANCE.far, Math.max(WALK_DISTANCE.near, walk.distance * factor));
    } else {
      cam.distance = Math.min(MAP_DISTANCE.far, Math.max(MAP_DISTANCE.near, cam.distance * factor));
    }
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

  // Frame loop: the walk camera eases toward the player's spot, and the scene draws each frame.
  let last = performance.now();
  function frame(now) {
    const dt = Math.min(0.1, (now - last) / 1000);
    last = now;
    if (walk.on && walk.follow) {
      const k = 1 - Math.exp(-dt * 12);
      cam.target.x += (walk.follow.x - cam.target.x) * k;
      cam.target.z += (walk.follow.z - cam.target.z) * k;
      cam.distance += (walk.distance - cam.distance) * k;
    }
    applyCamera();
    renderer.render(scene, camera);
    requestAnimationFrame(frame);
  }

  window.addEventListener('resize', resize);
  resize();
  requestAnimationFrame(frame);

  return {
    update,
    setSelected,
    drawPeople,
    drawVehicles,
    setWalking,
    follow,
    walkFacing,
    cameraYaw,
  };
}
