// Starts the game: loads or starts a save, runs the clock, the walk mode, and connects the city
// view to the screens. The game clock runs on its own timer, so it keeps going while a panel is
// open, and the walk mode runs on animation frames.
import { CONFIG } from './config.js';
import { ZONES } from './products.js';
import * as sim from './sim.js';
import { loadSlot, saveGame, setActiveSlot } from './save.js';
import { goToMenu, initMenu, pickedSlot } from './menu.js';
import { applyVolumes, playMusic, playSound, unlockAudio } from './audio.js';
import { createCityView } from './city3d.js';
import { createUi } from './ui.js';
import { createWalkMode } from './walkmode.js';
import { startAds, startRewardAds } from './ads.js';
import { truckPosition } from './sim.js';

const $ = (id) => document.getElementById(id);
const toastEl = $('toast');

const TAB_TITLES = { city: 'City', warehouse: 'Warehouse', fleet: 'Fleet', hq: 'HQ' };

function machineTitle(state, cell) {
  return `${ZONES[state.city[cell.y][cell.x].zone].name} building`;
}
let toastTimer = null;
// While paused, the clock, the trucks, the attacks and the walkers all stand still.
let paused = false;

function pauseGame(message) {
  paused = true;
  $('pause-message').textContent = message;
  $('pause-dialog').hidden = false;
}

function resumeGame() {
  paused = false;
  $('pause-dialog').hidden = true;
}

function toast(message, ok) {
  toastEl.textContent = message;
  toastEl.className = ok ? 'toast ok' : 'toast bad';
  toastEl.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { toastEl.hidden = true; }, 2500);
}

// Plays the game in a slot: loads its save, or starts a new game if the slot is empty.
async function start(slot) {
  const clips = await fetch('assets/clips.json').then((r) => r.json());
  const state = loadSlot(slot) || sim.newGame(Math.floor(Math.random() * 100000));

  // Runs a game action, saves when it worked, and shows the result.
  function act(run) {
    const result = run();
    if (result.ok) saveGame(state);
    ui.showMessage(result);
    city.update(state);
    return result;
  }

  const ui = createUi({ panel: $('panel'), stats: $('stats'), toast, act, state });

  // The popup: a tab from the left rail, or a shop front's machine detail. The machine detail can
  // be minimized to a pill at the bottom; a tab cannot. One popup at a time.
  const rail = [...document.querySelectorAll('.rail-btn')];
  function showSheet(title, mode, tab = null) {
    $('sheet-title').textContent = title;
    $('sheet-minimize').hidden = mode !== 'machine';
    $('sheet').hidden = false;
    $('machine-pill').hidden = true;
    for (const btn of rail) btn.classList.toggle('on', btn.dataset.tab === tab);
  }

  function closeSheet() {
    $('sheet').hidden = true;
    $('machine-pill').hidden = true;
    for (const btn of rail) btn.classList.remove('on');
    city.setSelected(null);
  }

  for (const btn of rail) {
    btn.addEventListener('click', () => {
      ui.openTab(btn.dataset.tab);
      showSheet(TAB_TITLES[btn.dataset.tab], 'tab', btn.dataset.tab);
    });
  }
  $('sheet-close').addEventListener('click', closeSheet);
  $('sheet-minimize').addEventListener('click', () => {
    $('sheet').hidden = true;
    $('machine-pill').textContent = $('sheet-title').textContent;
    $('machine-pill').hidden = false;
  });
  $('machine-pill').addEventListener('click', () => {
    $('machine-pill').hidden = true;
    $('sheet').hidden = false;
  });

  const city = createCityView($('city'), (cell) => {
    // Only shop fronts open the popup: roads, grass, parks and houses do nothing.
    if (state.city[cell.y][cell.x].type !== 'building') return;
    city.setSelected(cell);
    ui.select(cell);
    showSheet(machineTitle(state, cell), 'machine', 'city');
  });

  const walk = createWalkMode({
    city,
    getState: () => state,
    clips,
    sale: {
      collect: (machineId) => {
        const result = act(() => sim.collectCash(state, machineId));
        if (result.ok) playSound('coin_collect');
        return result;
      },
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
    // A vandal kicking a machine: talking to them stops it; if they kick on, it is vandalized.
    vandal: {
      beginKick: (id) => sim.beginKick(state, id),
      stop: (id) => act(() => sim.stopAttack(state, id)),
      punch: (id) => act(() => sim.punchAttack(state, id)),
      finish: (id) => {
        sim.completeAttack(state, id);
        saveGame(state);
        city.update(state);
      },
    },
    fix: { repair: (id) => act(() => sim.repairMachine(state, id)) },
    stock: { refill: (id) => act(() => sim.refillMachine(state, id)) },
    say: (message) => ui.showMessage({ ok: true, message }),
    buttons: {
      show: (on) => {
        $('walk-ui').hidden = !on;
        $('walk').disabled = on;
        $('rail').hidden = on;
        if (on) closeSheet();
      },
      setTalk: (on) => { $('talk').disabled = !on; },
      setCollect: (on) => { $('collect').disabled = !on; },
      setFix: (on) => { $('fix').disabled = !on; },
      setRefill: (on) => { $('refill').disabled = !on; },
      setRun: (on) => { $('run').setAttribute('aria-pressed', String(on)); },
      stick: $('stick'),
      knob: $('knob'),
      talkEl: $('talk'),
      collectEl: $('collect'),
      fixEl: $('fix'),
      attackEl: $('attack'),
      refillEl: $('refill'),
      runEl: $('run'),
      officeEl: $('office'),
      beaconsEl: $('beacons'),
    },
  });

  // Walking needs the city on screen, so an open panel is minimized first.
  $('walk').addEventListener('click', () => {
    // Walking follows the player: the map's selection highlight goes.
    city.setSelected(null);
    walk.enter();
  });
  $('to-menu').addEventListener('click', () => pauseGame('Save your game and go back to the main menu?'));
  $('pause-resume').addEventListener('click', resumeGame);
  $('pause-exit').addEventListener('click', () => {
    saveGame(state);
    goToMenu();
  });
  // Going to the background pauses and saves; coming back shows the pause dialog.
  document.addEventListener('visibilitychange', () => {
    if (!document.hidden) return;
    saveGame(state);
    pauseGame('The game was paused while the app was in the background.');
  });

  // The clock runs unless the game is paused. Saves when a day closes.
  setInterval(() => {
    if (paused) return;
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
    const dt = paused ? 0 : Math.min(0.1, (now - lastFrame) / 1000);
    lastFrame = now;
    sim.moveTrucks(state, dt);
    sim.advanceAttacks(state, dt);
    city.drawVehicles(state.trucks.filter((t) => t.trip).map((t) => ({ key: `t${t.id}`, ...truckPosition(state, t) })));
    walk.frame(dt);
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);

  ui.render(state);
  city.update(state);
}

// The page opens on the menu, or straight into a game when a slot was picked.
const slot = pickedSlot();
if (slot) {
  setActiveSlot(slot);
  document.getElementById('menu').hidden = true;
  playMusic('game_background');
  start(slot);
} else {
  initMenu();
}
startAds();
startRewardAds();

// Browsers only let sound start after a tap: every tap unlocks sound, and every button makes
// its click.
window.addEventListener('pointerdown', unlockAudio, { capture: true });
document.addEventListener('click', (event) => {
  if (event.target.closest('button')) playSound('button');
});
applyVolumes();
