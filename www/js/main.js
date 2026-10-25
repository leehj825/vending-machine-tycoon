// Starts the game: loads or starts a save, runs the clock, the walk mode, and connects the city
// view to the screens. The game clock runs on its own timer, so it keeps going while a panel is
// open, and the walk mode runs on animation frames.
import { CONFIG } from './config.js';
import * as sim from './sim.js';
import { loadGame, saveGame } from './save.js';
import { createCityView } from './city3d.js';
import { createUi } from './ui.js';
import { createWalkMode } from './walkmode.js';
import { startAds } from './ads.js';
import { truckPosition } from './sim.js';

const $ = (id) => document.getElementById(id);
const toastEl = $('toast');
const dockToggle = $('dock-toggle');

// Shows or hides the panel under the city. Hidden, the city takes the space.
dockToggle.addEventListener('click', () => {
  const hidden = document.body.classList.toggle('panel-hidden');
  dockToggle.setAttribute('aria-expanded', String(!hidden));
  dockToggle.textContent = hidden ? 'Show panel ▴' : 'Hide panel ▾';
});
let toastTimer = null;

function toast(message, ok) {
  toastEl.textContent = message;
  toastEl.className = ok ? 'toast ok' : 'toast bad';
  toastEl.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { toastEl.hidden = true; }, 2500);
}

async function start() {
  const clips = await fetch('assets/clips.json').then((r) => r.json());
  const state = loadGame() || sim.newGame(Math.floor(Math.random() * 100000));

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

  const walk = createWalkMode({
    city,
    getState: () => state,
    clips,
    sale: {
      collect: (machineId) => act(() => sim.collectCash(state, machineId)),
      // A passer-by's purchase saves quietly, without a message for every sale.
      walkerBuys: (machineId) => {
        const result = sim.sellToWalker(state, machineId);
        if (result.ok) {
          saveGame(state);
          city.update(state);
        }
        return result;
      },
    },
    say: (message) => ui.showMessage({ ok: true, message }),
    buttons: {
      show: (on) => { $('walk-ui').hidden = !on; $('walk').disabled = on; },
      setTalk: (on) => { $('talk').disabled = !on; },
      setCollect: (on) => { $('collect').disabled = !on; },
      setRun: (on) => { $('run').setAttribute('aria-pressed', String(on)); },
      stick: $('stick'),
      knob: $('knob'),
      talkEl: $('talk'),
      collectEl: $('collect'),
      runEl: $('run'),
      officeEl: $('office'),
    },
  });

  // Walking needs the city on screen, so an open panel is minimized first.
  $('walk').addEventListener('click', () => {
    if (!document.body.classList.contains('panel-hidden')) dockToggle.click();
    walk.enter();
  });

  // The clock always runs. Saves when a day closes.
  setInterval(() => {
    const day = state.day;
    sim.tick(state);
    if (state.day !== day) saveGame(state);
  }, CONFIG.tickMs);

  setInterval(() => {
    ui.refresh(state);
    city.update(state);
  }, 500);

  setInterval(() => saveGame(state), 30000);
  window.addEventListener('pagehide', () => saveGame(state));

  // Trucks drive along their routes in step with the clock.
  let lastFrame = performance.now();
  function frame(now) {
    const dt = Math.min(0.1, (now - lastFrame) / 1000);
    lastFrame = now;
    sim.moveTrucks(state, dt);
    city.drawVehicles(state.trucks.filter((t) => t.trip).map((t) => ({ key: `t${t.id}`, ...truckPosition(state, t) })));
    walk.frame(dt);
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);

  ui.render(state);
  city.update(state);
}

start();
startAds();
