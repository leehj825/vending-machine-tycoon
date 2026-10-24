// The 3D city. Flutter sends the static scene once, then a frame of moving people and
// vehicles on every update. Taps are reported back through the CityTap channel.
(function () {
  'use strict';

  // Colours are already the final values from the Dart builders, so skip three.js's
  // conversion to linear light, which would make them paler.
  THREE.ColorManagement.enabled = false;
  // The colours are already sRGB, so the output must not encode them a second time.

  const TAP_SLOP = 10; // pixels a finger may move and still count as a tap
  const TAP_MS = 350;
  const GLIDE_MS = 450;
  const ORBIT_YAW = 0.008; // radians per pixel
  const ORBIT_PITCH = 0.006;
  const FIGURE_SKIN = '#E2B88E';
  const FIGURE_PANTS = '#4B4036';
  const FIGURE_BOOT = '#2E241C';
  const FIGURE_SLEEVE = '#FFFFFF';

  const host = document.getElementById('host');
  const renderer = new THREE.WebGLRenderer({ antialias: true });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  renderer.outputColorSpace = THREE.LinearSRGBColorSpace;
  host.appendChild(renderer.domElement);
  const dom = renderer.domElement;

  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(30, 1, 0.5, 400);
  scene.add(new THREE.AmbientLight(0xffffff, 0.6));
  const sun = new THREE.DirectionalLight(0xffffff, 0.7);
  sun.position.set(-0.6, 1, 0.4);
  scene.add(sun);

  const staticGroup = new THREE.Group();
  const dynamicGroup = new THREE.Group();
  scene.add(staticGroup, dynamicGroup);

  // Camera: orbits `target` at `distance`, looking down at `pitch`.
  const home = { target: new THREE.Vector3(7.5, 0, 7.5), yaw: Math.PI / 4, pitch: 0.85, distance: 20 };
  const cam = { target: home.target.clone(), yaw: home.yaw, pitch: home.pitch, distance: home.distance };
  let minDistance = 6;
  let maxDistance = 60;
  let zoomFloor = 6;
  let glide = null;

  let rig = null; // { rest, parts } from the Dart rig
  const walkers = new Map(); // key -> { group, mesh, pad, geometry, role colours }
  let soups = [];

  function applyCamera() {
    const cp = Math.cos(cam.pitch);
    camera.position.set(
      cam.target.x + cam.distance * Math.sin(cam.yaw) * cp,
      cam.target.y + cam.distance * Math.sin(cam.pitch),
      cam.target.z + cam.distance * Math.cos(cam.yaw) * cp,
    );
    camera.lookAt(cam.target);
  }

  function clamp(v, lo, hi) {
    return Math.min(hi, Math.max(lo, v));
  }

  function zoomBy(factor) {
    cam.distance = clamp(cam.distance * factor, zoomFloor, maxDistance);
  }

  function glideTo(goal, ms) {
    glide = {
      from: { target: cam.target.clone(), yaw: cam.yaw, pitch: cam.pitch, distance: cam.distance },
      goal,
      start: performance.now(),
      ms,
    };
  }

  function stepGlide(now) {
    if (!glide) return;
    const t = Math.min(1, (now - glide.start) / glide.ms);
    const e = t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
    const { from, goal } = glide;
    cam.target.set(
      from.target.x + (goal.target.x - from.target.x) * e,
      from.target.y + (goal.target.y - from.target.y) * e,
      from.target.z + (goal.target.z - from.target.z) * e,
    );
    cam.yaw = from.yaw + (goal.yaw - from.yaw) * e;
    cam.pitch = from.pitch + (goal.pitch - from.pitch) * e;
    cam.distance = from.distance + (goal.distance - from.distance) * e;
    if (t >= 1) glide = null;
  }

  // Touch: one finger orbits, two fingers pinch, a short still press picks.
  const pointers = new Map();
  let tapCandidate = false;
  let downAt = null;
  let downTime = 0;
  let pinchSpan = null;
  let lastMid = null;

  function span() {
    if (pointers.size < 2) return null;
    const [a, b] = [...pointers.values()];
    return Math.hypot(a.x - b.x, a.y - b.y);
  }

  // Midpoint of two fingers, or null with fewer than two.
  function midpoint() {
    if (pointers.size < 2) return null;
    const [a, b] = [...pointers.values()];
    return { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 };
  }

  // Two fingers pan the view: the scene under the fingers moves with them. The ground
  // distance per pixel follows the camera's view height, so a pan keeps pace at any zoom.
  const VIEW_HEIGHT_PER_DISTANCE = 2 * Math.tan((30 * Math.PI) / 360);
  function panBy(dx, dy) {
    const perPixel = (VIEW_HEIGHT_PER_DISTANCE * cam.distance) / Math.max(1, window.innerHeight);
    const right = { x: Math.cos(cam.yaw), z: -Math.sin(cam.yaw) };
    const forward = { x: -Math.sin(cam.yaw), z: -Math.cos(cam.yaw) };
    // Fingers moving right move the scene right, so the target moves left.
    cam.target.x += (-right.x * dx + forward.x * dy) * perPixel;
    cam.target.z += (-right.z * dx + forward.z * dy) * perPixel;
  }

  dom.addEventListener('pointerdown', (e) => {
    glide = null;
    pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
    if (pointers.size === 1) {
      downAt = { x: e.clientX, y: e.clientY };
      downTime = performance.now();
      tapCandidate = true;
    } else {
      tapCandidate = false;
    }
    pinchSpan = span();
    lastMid = midpoint();
  });

  dom.addEventListener('pointermove', (e) => {
    const prev = pointers.get(e.pointerId);
    if (!prev) return;
    pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
    if (pointers.size === 1) {
      if (downAt && Math.hypot(e.clientX - downAt.x, e.clientY - downAt.y) > TAP_SLOP) {
        tapCandidate = false;
      }
      cam.yaw -= (e.clientX - prev.x) * ORBIT_YAW;
      cam.pitch = clamp(cam.pitch + (e.clientY - prev.y) * ORBIT_PITCH, 0.2, 1.45);
      return;
    }
    tapCandidate = false;
    const s = span();
    if (s != null && pinchSpan != null && pinchSpan > 0) zoomBy(pinchSpan / s);
    pinchSpan = s;
    const mid = midpoint();
    if (mid && lastMid) panBy(mid.x - lastMid.x, mid.y - lastMid.y);
    lastMid = mid;
  });

  function endPointer(e, cancelled) {
    const wasSingle = pointers.size === 1;
    const isTap = !cancelled && wasSingle && tapCandidate && performance.now() - downTime < TAP_MS;
    pointers.delete(e.pointerId);
    pinchSpan = span();
    lastMid = midpoint();
    if (cancelled) {
      tapCandidate = false;
      return;
    }
    if (isTap) {
      tapCandidate = false;
      pick(e.clientX, e.clientY);
    }
  }
  dom.addEventListener('pointerup', (e) => endPointer(e, false));
  dom.addEventListener('pointercancel', (e) => endPointer(e, true));

  dom.addEventListener('wheel', (e) => {
    e.preventDefault();
    zoomBy(Math.exp(e.deltaY * 0.001));
  }, { passive: false });

  const raycaster = new THREE.Raycaster();
  const ndc = new THREE.Vector2();

  function post(message) {
    if (window.CityTap) window.CityTap.postMessage(JSON.stringify(message));
  }

  function pick(clientX, clientY) {
    const r = dom.getBoundingClientRect();
    ndc.x = ((clientX - r.left) / r.width) * 2 - 1;
    ndc.y = -((clientY - r.top) / r.height) * 2 + 1;
    raycaster.setFromCamera(ndc, camera);
    // Hits come back nearest first, so the first target is what the finger is on.
    for (const hit of raycaster.intersectObjects(scene.children, true)) {
      const target = hit.object.userData.pick;
      if (target) {
        post(target);
        return;
      }
    }
  }

  function disposeGroup(group) {
    for (const child of [...group.children]) {
      group.remove(child);
      if (child.geometry) child.geometry.dispose();
      if (child.material) child.material.dispose();
    }
  }

  function colourOf(hex) {
    return new THREE.Color(hex);
  }

  // Figure faces: four corner indices per box face, as the Dart rig lists them.
  const FACES = [
    [1, 5, 7, 3],
    [0, 2, 6, 4],
    [2, 6, 7, 3],
    [0, 1, 5, 4],
    [4, 5, 7, 6],
    [0, 1, 3, 2],
  ];

  function makeWalker(key, message) {
    const parts = rig.parts;
    const count = parts.length * 36;
    const geometry = new THREE.BufferGeometry();
    const position = new THREE.BufferAttribute(new Float32Array(count * 3), 3);
    const colour = new THREE.BufferAttribute(new Float32Array(count * 3), 3);
    geometry.setAttribute('position', position);
    geometry.setAttribute('color', colour);
    const shirt = colourOf(message.shirt);
    const cap = colourOf(message.cap);
    const fixed = {
      skin: colourOf(FIGURE_SKIN),
      pants: colourOf(FIGURE_PANTS),
      boot: colourOf(FIGURE_BOOT),
      sleeve: colourOf(FIGURE_SLEEVE),
    };
    let v = 0;
    for (const part of parts) {
      const c = part.role === 'shirt' ? shirt : part.role === 'cap' ? cap : fixed[part.role];
      for (let i = 0; i < 36; i++) {
        colour.setXYZ(v + i, c.r, c.g, c.b);
      }
      v += 36;
    }
    const material = new THREE.MeshLambertMaterial({ vertexColors: true, flatShading: true, side: THREE.DoubleSide });
    const mesh = new THREE.Mesh(geometry, material);
    const padMaterial = new THREE.MeshBasicMaterial({ transparent: true, opacity: 0, depthWrite: false });
    const pad = new THREE.Mesh(new THREE.BoxGeometry(0.3, 0.4, 0.3), padMaterial);
    const group = new THREE.Group();
    group.add(mesh, pad);
    pad.userData.pick = { kind: 'pedestrian', key };
    mesh.userData.pick = { kind: 'pedestrian', key };
    dynamicGroup.add(group);
    return { group, mesh, pad, geometry, position, corners: new Array(8) };
  }

  // Walks the figure's boxes through the bone transforms, then turns and moves them to
  // the person's place. Matches the Dart rig's toWorld.
  function updateWalker(walker, message) {
    const s = message.scale;
    const cy = Math.cos(message.yaw);
    const sy = Math.sin(message.yaw);
    const bones = message.bones;
    const out = walker.position.array;
    const corners = walker.corners;
    const toWorld = (px, py, pz) => {
      const sx = px * s;
      const sz = pz * s;
      return [message.x + sx * cy + sz * sy, py * s, message.z - sx * sy + sz * cy];
    };
    let v = 0;
    for (const part of rig.parts) {
      const b = part.bone;
      const o = b * 12;
      const rest = rig.rest[b];
      for (let c = 0; c < 8; c++) {
        const hx = c & 1 ? 1 : -1;
        const hy = c & 2 ? 1 : -1;
        const hz = c & 4 ? 1 : -1;
        const lx = part.c[0] + hx * part.h[0] - rest[0];
        const ly = part.c[1] + hy * part.h[1] - rest[1];
        const lz = part.c[2] + hz * part.h[2] - rest[2];
        const wx = bones[o] * lx + bones[o + 1] * ly + bones[o + 2] * lz + bones[o + 9];
        const wy = bones[o + 3] * lx + bones[o + 4] * ly + bones[o + 5] * lz + bones[o + 10];
        const wz = bones[o + 6] * lx + bones[o + 7] * ly + bones[o + 8] * lz + bones[o + 11];
        corners[c] = toWorld(wx, wy, wz);
      }
      for (const f of FACES) {
        const a = corners[f[0]];
        const bb = corners[f[1]];
        const cc = corners[f[2]];
        const d = corners[f[3]];
        for (const p of [a, bb, cc, a, cc, d]) {
          out[v++] = p[0];
          out[v++] = p[1];
          out[v++] = p[2];
        }
      }
    }
    walker.position.needsUpdate = true;
    walker.geometry.computeBoundingSphere();
    walker.mesh.material.color.setScalar(message.brightness);
    // The pad sits over the figure, so a finger can hit a figure that is only a few pixels.
    walker.pad.position.set(message.x, 0.2, message.z);
  }

  function buildSoup(item) {
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute('position', new THREE.Float32BufferAttribute(item.p, 3));
    geometry.setAttribute('color', new THREE.Float32BufferAttribute(item.c, 3));
    const mesh = new THREE.Mesh(
      geometry,
      new THREE.MeshBasicMaterial({ vertexColors: true, side: THREE.DoubleSide }),
    );
    if (item.pick) mesh.userData.pick = item.pick;
    return mesh;
  }

  let hasScene = false;

  window.city = {
    setScene(message) {
      // Only a new map, or the first scene, moves the camera. Machines change often, and
      // a scene resent for them must not undo the player's view.
      const moveCamera = !hasScene || message.resetCamera;
      hasScene = true;
      renderer.setClearColor(new THREE.Color(message.sky));
      rig = message.rig;
      minDistance = message.minDistance;
      maxDistance = message.maxDistance;
      zoomFloor = minDistance;
      home.target.set(message.home.target[0], message.home.target[1], message.home.target[2]);
      home.yaw = message.home.yaw;
      home.pitch = message.home.pitch;
      home.distance = message.home.distance;
      if (moveCamera) {
        glide = null;
        cam.target.copy(home.target);
        cam.yaw = home.yaw;
        cam.pitch = home.pitch;
        cam.distance = home.distance;
      }

      disposeGroup(staticGroup);
      for (const walker of walkers.values()) {
        walker.geometry.dispose();
      }
      walkers.clear();
      disposeGroup(dynamicGroup);
      soups = [];

      for (const item of message.objects) {
        const geometry = new THREE.BufferGeometry();
        geometry.setAttribute('position', new THREE.Float32BufferAttribute(item.p, 3));
        geometry.setAttribute('color', new THREE.Float32BufferAttribute(item.c, 3));
        const mesh = new THREE.Mesh(
          geometry,
          new THREE.MeshBasicMaterial({ vertexColors: true, side: THREE.DoubleSide }),
        );
        if (item.pick) mesh.userData.pick = item.pick;
        staticGroup.add(mesh);
      }
      applyCamera();
    },

    setFrame(message) {
      // Moving vehicles and markers are rebuilt from triangles every frame.
      for (const mesh of soups) {
        dynamicGroup.remove(mesh);
        mesh.geometry.dispose();
        mesh.material.dispose();
      }
      soups = [];
      for (const item of message.soups) {
        const mesh = buildSoup(item);
        soups.push(mesh);
        dynamicGroup.add(mesh);
      }

      // People: one mesh per person, kept between frames and dropped when they leave.
      const seen = new Set();
      if (rig) {
        for (const person of message.walkers) {
          seen.add(person.key);
          let walker = walkers.get(person.key);
          if (!walker) {
            walker = makeWalker(person.key, person);
            walkers.set(person.key, walker);
          }
          updateWalker(walker, person);
        }
      }
      for (const [key, walker] of walkers) {
        if (!seen.has(key)) {
          dynamicGroup.remove(walker.group);
          walker.geometry.dispose();
          walker.mesh.material.dispose();
          walker.pad.material.dispose();
          walker.pad.geometry.dispose();
          walkers.delete(key);
        }
      }
    },

    focus(x, y, z, distance, pitch) {
      zoomFloor = Math.min(minDistance, distance);
      glideTo({ target: new THREE.Vector3(x, y, z), yaw: cam.yaw, pitch, distance }, GLIDE_MS);
    },

    reset() {
      zoomFloor = minDistance;
      glideTo(home, GLIDE_MS);
    },

    zoom(factor) {
      zoomBy(factor);
    },
  };

  function resize() {
    const w = window.innerWidth;
    const h = window.innerHeight;
    renderer.setSize(w, h);
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
  }
  window.addEventListener('resize', resize);
  resize();

  function frame(now) {
    stepGlide(now);
    applyCamera();
    renderer.render(scene, camera);
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
})();
