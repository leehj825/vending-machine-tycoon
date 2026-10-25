// Starts the game: loads or starts a save, runs the clock, and connects the city view to the
// screens. The game clock runs on its own timer, so it keeps going while a panel is open.
import { CONFIG } from './config.js';
import * as sim from './sim.js';
import { loadGame, saveGame } from './save.js';
import { createCityView } from './city3d.js';
import { createUi } from './ui.js';

const state = loadGame() || sim.newGame(Math.floor(Math.random() * 100000));
let paused = false;
let speeds = [1, 2, 4];
let speedIndex = 0;

const $ = (id) => document.getElementById(id);
const toastEl = $('toast');
let toastTimer = null;

function toast(message, ok) {
  toastEl.textContent = message;
  toastEl.className = ok ? 'toast ok' : 'toast bad';
  toastEl.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { toastEl.hidden = true; }, 2500);
}

// Runs a game action, saves when it worked, and shows the result.
function act(run) {
  const result = run();
  if (result.ok) saveGame(state);
  ui.showMessage(result);
  city.update(state);
  return result;
}

const ui = createUi({ panel: $('panel'), stats: $('stats'), toast, act, state });

const city = createCityView($('city'), (cell) => {
  city.setSelected(cell);
  ui.select(cell);
});

$('pause').addEventListener('click', () => {
  paused = !paused;
  $('pause').textContent = paused ? '▶' : '❚❚';
});
$('speed').addEventListener('click', () => {
  speedIndex = (speedIndex + 1) % speeds.length;
  $('speed').textContent = `${speeds[speedIndex]}×`;
});

// The clock: a few ticks per interval at higher speeds. Saves when a day closes.
setInterval(() => {
  if (paused) return;
  const day = state.day;
  for (let i = 0; i < speeds[speedIndex]; i++) sim.tick(state);
  if (state.day !== day) saveGame(state);
}, CONFIG.tickMs);

setInterval(() => {
  ui.refresh(state);
  city.update(state);
}, 500);

setInterval(() => saveGame(state), 30000);
window.addEventListener('pagehide', () => saveGame(state));

ui.render(state);
city.update(state);
