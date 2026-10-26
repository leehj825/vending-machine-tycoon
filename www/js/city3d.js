/* global THREE */
// The city view in three.js, drawn like the original game: the low-poly map from scene.js, the
// machines and markers over it, the trucks and the people. Map view: taps pick a cell, drags turn
// the view, pinch and wheel zoom. Walk view: a camera behind the player, drags turn the player.
import { buildMachine, buildMarkers, buildStaticScene, buildTruck } from './scene.js';
import { createFigure, poseFigure } from './figure.js';

// The colours in scene.js are final sRGB values, so three.js must not convert them.
THREE.ColorManagement.enabled = false;

const SKY = 0xa7d8f2;
const TAP_SLOP = 8;
const LANE_OFFSET = 0.15;
// The dark outline on the map's models, as in the bright cartoon style.
const OUTLINE_MATERIAL = new THREE.LineBasicMaterial({ color: 0x1d1412 });
const WALK_DISTANCE = { start: 3.2, near: 1.4, far: 9 };
const MAP_DISTANCE = { near: 6, far: 40 };
// The original game's default view: a three-quarter view looking down on the whole grid.
const MAP_VIEW = { yaw: Math.PI / 4, pitch: 0.85 };
// How far the view can tilt: the map looks down from above, the walk camera from behind.
const PITCH = { map: [0.35, 1.45], walk: [0.15, 1.2] };
// Walk camera: a building this tall or taller blocks the view when the camera's line crosses it.
const BUILDING_TOP = 2.6;
// The share of the screen height the walk view moves the picture down, so the player sits low
// while the camera still looks at them.
const WALK_SCREEN_SHIFT = 0.28;

// Pushes the colours a little brighter and richer, for the bright cartoon look.
function vivid(colors) {
  for (let i = 0; i < colors.length; i += 3) {
    const mean = (colors[i] + colors[i + 1] + colors[i + 2]) / 3;
    for (let k = 0; k < 3; k++) {
      const boosted = (mean + (colors[i + k] - mean) * 1.25) * 1.1;
      colors[i + k] = Math.min(1, Math.max(0, boosted));
    }
  }
  return colors;
}

function geometryFrom({ positions, colors }) {
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
  geometry.setAttribute('color', new THREE.BufferAttribute(vivid(colors), 3));
  return geometry;
}

// The dark edges of a model: the lines where its faces meet at a clear angle.
function outlineOf(geometry) {
  return new THREE.LineSegments(new THREE.EdgesGeometry(geometry, 30), OUTLINE_MATERIAL);
}

export function createCityView(container, onTap) {
  const renderer = new THREE.WebGLRenderer({ antialias: true });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  renderer.outputColorSpace = THREE.LinearSRGBColorSpace;
  container.appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  scene.background = new THREE.Color(SKY);
  // The figures are lit; the map is already lit, baked into its colours.
  scene.add(new THREE.AmbientLight(0xffffff, 0.6));
  const sun = new THREE.DirectionalLight(0xffffff, 0.7);
  sun.position.set(-0.6, 1, 0.4);
  scene.add(sun);

  const camera = new THREE.PerspectiveCamera(30, 1, 0.5, 400);
  const cityGroup = new THREE.Group();
  const machineGroup = new THREE.Group();
  const markerGroup = new THREE.Group();
  const pickGroup = new THREE.Group();
  const figureGroup = new THREE.Group();
  const vehicleGroup = new THREE.Group();
  scene.add(cityGroup, machineGroup, markerGroup, pickGroup, figureGroup, vehicleGroup);

  const vertexMaterial = new THREE.MeshBasicMaterial({ vertexColors: true, side: THREE.DoubleSide });
  const cam = { target: new THREE.Vector3(7.5, 0, 7.5), yaw: MAP_VIEW.yaw, pitch: MAP_VIEW.pitch, distance: 16.5 };
  const walk = { on: false, follow: null, distance: WALK_DISTANCE.start };
  const view = { w: 1, h: 1 };
  let city = null;
  let selected = null;
  let selectMesh = null;
  let machineSignature = '';
  let markerSignature = '';
  let machineMesh = null;
  const markerMeshes = [];
  const figures = new Map();
  const vehicles = new Map();
  let truckGeometry = null;
  let truckEdges = null;
  const truckMaterial = new THREE.MeshLambertMaterial({ vertexColors: true, flatShading: true });

  // The map is built once per city: ground, streets and buildings, then the pick plates.
  function buildCity(grid) {
    clear(cityGroup);
    clear(pickGroup);
    const ground = geometryFrom(buildStaticScene(grid));
    cityGroup.add(new THREE.Mesh(ground, vertexMaterial), outlineOf(ground));
    grid.forEach((row, y) => row.forEach((_cell, x) => {
      const plate = new THREE.Mesh(
        new THREE.PlaneGeometry(1, 1),
        new THREE.MeshBasicMaterial({ transparent: true, opacity: 0, depthWrite: false }),
      );
      plate.rotation.x = -Math.PI / 2;
      plate.position.set(x + 0.5, 0.12, y + 0.5);
      plate.userData.cell = { x, y };
      pickGroup.add(plate);
    }));
    selectMesh = new THREE.Mesh(
      new THREE.PlaneGeometry(1, 1),
      new THREE.MeshBasicMaterial({ color: 0xffd54f, transparent: true, opacity: 0.55, depthWrite: false }),
    );
    selectMesh.rotation.x = -Math.PI / 2;
    selectMesh.position.y = 0.13;
    selectMesh.visible = false;
    cityGroup.add(selectMesh);
    cam.target.set(grid.length / 2, 0, grid.length / 2);
    cam.yaw = MAP_VIEW.yaw;
    cam.pitch = MAP_VIEW.pitch;
    cam.distance = grid.length * 1.1;
    truckGeometry = geometryFrom(buildTruck());
    truckEdges = new THREE.EdgesGeometry(truckGeometry, 30);
  }

  // The machines, merged into one mesh. Rebuilt when the set of machines changes.
  function drawMachines(state) {
    const signature = state.machines.map((m) => `${m.id}:${m.zone}:${m.cash > 0}:${Object.values(m.stock).join(',')}`).join('|');
    if (signature === machineSignature) return;
    machineSignature = signature;
    clear(machineGroup);
    machineMesh = null;
    if (state.machines.length === 0) return;
    const positions = [];
    const colors = [];
    for (const machine of state.machines) {
      const part = buildMachine(machine, state.city);
      for (const v of part.positions) positions.push(v);
      for (const v of part.colors) colors.push(v);
    }
    const machines = geometryFrom({ positions: new Float32Array(positions), colors: new Float32Array(colors) });
    machineGroup.add(new THREE.Mesh(machines, vertexMaterial), outlineOf(machines));
  }

  // Purchase arrows, owned plates and coins. The group bobs gently, as the original's did.
  function drawMarkers(state, time) {
    const signature = `${state.cash >= 400}|${state.machines.map((m) => `${m.x},${m.y},${m.cash > 0}`).join('|')}`;
    if (signature !== markerSignature) {
      markerSignature = signature;
      clear(markerGroup);
      const parts = buildMarkers(state);
      for (const part of [parts.arrows, parts.owned, parts.coins]) {
        if (part.positions.length === 0) continue;
        const geometry = geometryFrom(part);
        markerGroup.add(new THREE.Mesh(geometry, vertexMaterial), outlineOf(geometry));
      }
    }
    markerGroup.position.y = Math.sin(time * 2.2) * 0.05;
  }

  function clear(group) {
    while (group.children.length) {
      const child = group.children.pop();
      child.geometry?.dispose();
      child.material?.dispose?.();
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
    drawMarkers(state, performance.now() / 1000);
  }

  // The people: one figure per key, placed and posed each frame, and removed when they leave.
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

  // Trucks on the road, each in its lane: 0.15 to the right of its heading. positions is a list of
  // { key, x, z, yaw } for the centre of the truck's cell, with its heading.
  function drawVehicles(positions) {
    const seen = new Set();
    for (const p of positions) {
      seen.add(p.key);
      let mesh = vehicles.get(p.key);
      if (!mesh) {
        mesh = new THREE.Mesh(truckGeometry, truckMaterial);
        mesh.add(new THREE.LineSegments(truckEdges, OUTLINE_MATERIAL));
        vehicles.set(p.key, mesh);
        vehicleGroup.add(mesh);
      }
      const fx = Math.sin(p.yaw);
      const fz = Math.cos(p.yaw);
      mesh.position.set(p.x - fz * LANE_OFFSET, 0, p.z + fx * LANE_OFFSET);
      mesh.rotation.y = p.yaw;
    }
    for (const [key, mesh] of vehicles) {
      if (seen.has(key)) continue;
      vehicleGroup.remove(mesh);
      vehicles.delete(key);
    }
  }

  function setWalking(on) {
    walk.on = on;
    if (on) {
      walk.distance = WALK_DISTANCE.start;
      cam.pitch = 0.5;
    } else {
      cam.distance = city ? city.length * 1.1 : 16.5;
      cam.pitch = MAP_VIEW.pitch;
      cam.target.set(city ? city.length / 2 : 7.5, 0, city ? city.length / 2 : 7.5);
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
    if (walk.on) camera.setViewOffset(view.w, view.h, 0, -view.h * WALK_SCREEN_SHIFT, view.w, view.h);
    else camera.clearViewOffset();
  }

  function resize() {
    const w = container.clientWidth || 1;
    const h = container.clientHeight || 1;
    view.w = w;
    view.h = h;
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
    const before = midpoint();
    pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
    if (pointers.size === 1) {
      if (downAt && Math.hypot(e.clientX - downAt.x, e.clientY - downAt.y) > TAP_SLOP) moved = true;
      cam.yaw -= (e.clientX - prev.x) * 0.008;
      const [low, high] = walk.on ? PITCH.walk : PITCH.map;
      cam.pitch = Math.min(high, Math.max(low, cam.pitch + (e.clientY - prev.y) * 0.006));
    } else if (pointers.size === 2 && pinch) {
      const now = distance();
      if (now > 0) zoom(pinch / now);
      pinch = now;
      moved = true;
      if (!walk.on && before) {
        const after = midpoint();
        panMap(after.x - before.x, after.y - before.y);
      }
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

  function midpoint() {
    const [a, b] = [...pointers.values()];
    return a && b ? { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 } : null;
  }

  // Two fingers slide the map view across the town: the map moves with the fingers.
  function panMap(dx, dy) {
    const scale = cam.distance * 0.0016;
    const rightX = Math.cos(cam.yaw);
    const rightZ = -Math.sin(cam.yaw);
    const forwardX = -Math.sin(cam.yaw);
    const forwardZ = -Math.cos(cam.yaw);
    const size = city ? city.length : 15;
    const x = cam.target.x + (forwardX * dy - rightX * dx) * scale;
    const z = cam.target.z + (forwardZ * dy - rightZ * dx) * scale;
    cam.target.x = Math.min(size + 2, Math.max(-2, x));
    cam.target.z = Math.min(size + 2, Math.max(-2, z));
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

  // How far the walk camera can sit from the player: the wanted distance, or nearer when a
  // building stands on the camera's line, so the view is not blocked.
  function clearDistance() {
    const wanted = walk.distance;
    if (!city) return wanted;
    const cp = Math.cos(cam.pitch);
    const dx = Math.sin(cam.yaw) * cp;
    const dy = Math.sin(cam.pitch);
    const dz = Math.cos(cam.yaw) * cp;
    for (let t = 0.5; t <= wanted; t += 0.1) {
      const x = cam.target.x + dx * t;
      const y = cam.target.y + dy * t;
      const z = cam.target.z + dz * t;
      if (y < BUILDING_TOP && isBuildingAt(x, z)) return Math.max(WALK_DISTANCE.near, t - 0.3);
    }
    return wanted;
  }

  function isBuildingAt(x, z) {
    const cell = city[Math.floor(z)]?.[Math.floor(x)];
    return cell?.type === 'building' || cell?.type === 'house';
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
      cam.distance += (clearDistance() - cam.distance) * k;
    }
    applyCamera();
    renderer.render(scene, camera);
    requestAnimationFrame(frame);
  }

  // The city's size changes when the panel opens or closes, so watch the container itself.
  if (typeof ResizeObserver !== 'undefined') new ResizeObserver(resize).observe(container);
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

