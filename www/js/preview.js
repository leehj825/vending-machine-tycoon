/* global THREE */
// Plays each motion clip on the figure, so the motions can be looked at and chosen.
import { createFigure, poseFigure } from './figure.js';
import { newPose, samplePose } from './locomotion.js';

THREE.ColorManagement.enabled = false;

const LOOK = { shirt: 0xffeb3b, hat: 0xffffff };
const $ = (id) => document.getElementById(id);
const view = $('view');

const renderer = new THREE.WebGLRenderer({ antialias: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
renderer.outputColorSpace = THREE.LinearSRGBColorSpace;
view.appendChild(renderer.domElement);
const scene = new THREE.Scene();
scene.background = new THREE.Color(0xa7d8f2);
scene.add(new THREE.AmbientLight(0xffffff, 0.6));
const sun = new THREE.DirectionalLight(0xffffff, 0.7);
sun.position.set(-0.6, 1, 0.4);
scene.add(sun);
const camera = new THREE.PerspectiveCamera(30, 1, 0.05, 50);
// The figure is about 0.25 units tall in the city, but this view is for looking, so it is drawn
// bigger: scaled up so the figure is about 1.8 units tall.
const figure = createFigure(LOOK);
figure.root.scale.setScalar(1);
scene.add(figure.root);
camera.position.set(0.9, 1.2, 5.2);
camera.lookAt(0, 0.95, 0);

function resize() {
  const w = view.clientWidth || 1;
  const h = view.clientHeight || 1;
  renderer.setSize(w, h, false);
  camera.aspect = w / h;
  camera.updateProjectionMatrix();
}
window.addEventListener('resize', resize);
resize();

const data = await fetch('assets/motions.json').then((r) => r.json());
const names = [...new Set([...Object.keys(data.motions), ...Object.keys(data.aliases)])].sort();
const resolve = (name) => data.motions[name] || data.motions[data.aliases[name]];
const pick = $('pick');
for (const name of names) {
  const option = document.createElement('option');
  option.value = name;
  option.textContent = name;
  pick.appendChild(option);
}

let current = null;
let playing = true;
let time = 0;
const pose = newPose();

function select(name) {
  current = resolve(name);
  $('name').textContent = name;
  $('info').textContent = `${current.frames} frames, ${current.d.toFixed(2)} s${current.loop ? '' : ', not a loop'}`;
  time = 0;
}

pick.addEventListener('change', () => select(pick.value));
$('play').addEventListener('click', () => {
  playing = !playing;
  $('play').textContent = playing ? 'Pause' : 'Play';
});

let last = performance.now();
function frame(now) {
  const dt = Math.min(0.1, (now - last) / 1000);
  last = now;
  if (playing && current) time += dt * Number($('speed').value);
  if (current) {
    // One cycle of the clip is its duration; phase is in cycles.
    samplePose(current, time / current.d, pose);
    poseFigure(figure, 0, 0, 0, pose);
    figure.root.position.set(0, 0, 0);
  }
  renderer.render(scene, camera);
  requestAnimationFrame(frame);
}

select(names[0]);
pick.value = names[0];
requestAnimationFrame(frame);
