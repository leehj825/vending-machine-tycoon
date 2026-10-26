// Starts the game: loads or starts a save, runs the clock, the walk mode, and connects the city
// view to the screens. The game clock runs on its own timer, so it keeps going while a panel is
// open, and the walk mode runs on animation frames.
import { CONFIG } from './config.js';
import { ZONES } from './products.js';
import * as sim from './sim.js';
import { loadSlot, savedAt, saveGame, setActiveSlot } from './save.js';
import { goToMenu, initMenu, pickedSlot } from './menu.js';
import { applyVolumes, playMusic, playSound, unlockAudio } from './audio.js';
import { createCityView } from './city3d.js';
import { createUi } from './ui.js';
import { createWalkMode } from './walkmode.js';
import { createInsideView } from './inside3d.js';
import { summaryHtml } from './summary.js';
import { skipTutorial, tutorialCheck, tutorialEvent, tutorialStep } from './tutorial.js';
import { rewardReadyNow, showRewardAd, startAds, startRewardAds } from './ads.js';
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
  // Real seconds since this game was last saved: the time the app was closed.
  const awaySeconds = savedAt(slot) ? (Date.now() - savedAt(slot)) / 1000 : 0;

  // Runs a game action, saves when it worked, and shows the result.
  function act(run) {
    const result = run();
    if (result.ok) saveGame(state);
    ui.showMessage(result);
    city.update(state);
    return result;
  }

  const ui = createUi({ panel: $('panel'), stats: $('stats'), toast, act, state, guide: (event) => guide(event) });

  // The popup: a tab from the left rail, or a shop front's machine detail. The machine detail can
  // be minimized to a pill at the bottom; a tab cannot. One popup at a time.
  const rail = [...document.querySelectorAll('.rail-btn')];
  // A touch that opens a popup must not carry on into it: the browser sends a click when the touch
  // ends, and it would press whatever button the popup put under the finger. A click only counts
  // for the popup (or its pill) if its touch began there. The map is the other way round: it
  // only takes a tap whose touch began on the map.
  let downInPopup = false;
  document.addEventListener('pointerdown', (e) => {
    downInPopup = Boolean(e.target.closest('#sheet, #machine-pill'));
  }, true);
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
  // A click on the popup or its pill whose touch began elsewhere is the tail of the tap that opened it.
  for (const el of [$('sheet'), $('machine-pill')]) {
    el.addEventListener('click', (e) => {
      if (downInPopup) return;
      e.stopPropagation();
      e.preventDefault();
    }, true);
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

  // The machine whose front is open: a close-up of its inside is drawn over the city, and a bar
  // takes the cash, refills it, or shuts it. The front closes when the player walks away.
  // The end-of-day summary: shown once for each day that closes, with the game paused.
  let summaryShown = state.summary?.day ?? 0;
  function refreshSummary() {
    if (paused || !state.summary || state.summary.day === summaryShown) return;
    summaryShown = state.summary.day;
    $('summary-title').textContent = `Day ${state.summary.day} is over`;
    $('summary-body').innerHTML = summaryHtml(state.summary);
    $('summary-dialog').hidden = false;
    paused = true;
  }
  $('summary-continue').addEventListener('click', () => {
    $('summary-dialog').hidden = true;
    paused = false;
  });

  // The first-day guide: shows the current step, and moves on when the player does it.
  function refreshCoach() {
    tutorialCheck(state);
    const step = tutorialStep(state);
    $('coach').hidden = !step;
    if (!step) return;
    $('coach-text').textContent = step.text;
    $('coach-button').textContent = step.button ?? 'Skip';
  }
  function guide(event) {
    if (tutorialEvent(state, event)) saveGame(state);
    refreshCoach();
  }
  $('coach-button').addEventListener('click', () => {
    skipTutorial(state);
    saveGame(state);
    refreshCoach();
  });
  const closeup = createInsideView($('city'));
  let insideId = null;
  let insideT = 0;
  function openInside(id) {
    insideId = id;
    guide('open');
    closeup.show(state.machines.find((m) => m.id === id));
    $('inside-bar').hidden = false;
    refreshInsideBar();
  }
  function closeInside() {
    insideId = null;
    $('inside-bar').hidden = true;
  }
  // Swings the door toward its target a little each frame.
  function insideFrame(dt) {
    if (insideId !== null && walk.frontMachineId() !== insideId) closeInside();
    const target = insideId === null ? 0 : 1;
    insideT = insideT < target ? Math.min(target, insideT + dt * 1.6) : Math.max(target, insideT - dt * 3);
    closeup.setOpen(insideT);
    closeup.frame(dt);
  }
  function refreshInsideBar() {
    if (insideId === null) return;
    const machine = state.machines.find((m) => m.id === insideId);
    if (!machine) {
      closeInside();
      return;
    }
    closeup.update(machine);
    $('inside-info').textContent = `Stock ${sim.machineTotal(machine)}/${sim.machineCapacity(machine)} · Cash $${machine.cash.toFixed(2)}`;
    $('inside-cash').disabled = machine.cash <= 0;
    $('inside-refill').disabled = sim.warehouseTotal(state) === 0 || sim.machineTotal(machine) >= sim.machineCapacity(machine);
  }
  $('inside-cash').addEventListener('click', () => {
    const result = act(() => sim.collectCash(state, insideId));
    if (result.ok) {
      playSound('coin_collect');
      closeup.takeCash();
      guide('collect');
    }
    refreshInsideBar();
  });
  $('inside-refill').addEventListener('click', () => {
    if (act(() => sim.refillMachine(state, insideId)).ok) guide('refill');
    refreshInsideBar();
  });
  $('inside-close').addEventListener('click', closeInside);

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
    inside: { open: openInside, close: closeInside, isOpen: (id) => insideId === id },
    say: (message) => ui.showMessage({ ok: true, message }),
    buttons: {
      show: (on) => {
        $('walk-ui').hidden = !on;
        $('walk').disabled = on;
        $('rail').hidden = on;
        $('coach').classList.toggle('walking', on);
        if (on) closeSheet();
        else closeInside();
      },
      setTalk: (on) => { $('talk').disabled = !on; },
      setCollect: (on) => { $('collect').disabled = !on; },
      setFix: (on) => { $('fix').disabled = !on; },
      setOpen: (on) => { $('open').disabled = !on; },
      setRun: (on) => { $('run').setAttribute('aria-pressed', String(on)); },
      stick: $('stick'),
      knob: $('knob'),
      talkEl: $('talk'),
      collectEl: $('collect'),
      fixEl: $('fix'),
      attackEl: $('attack'),
      openEl: $('open'),
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
    guide('walk');
  });
  $('to-menu').addEventListener('click', () => pauseGame('Save your game and go back to the main menu?'));
  $('pause-resume').addEventListener('click', resumeGame);
  $('pause-exit').addEventListener('click', () => {
    saveGame(state);
    goToMenu();
  });
  // Going to the background pauses and saves; coming back shows the pause dialog.
  let hiddenAt = 0;
  document.addEventListener('visibilitychange', () => {
    if (!document.hidden) {
      applyOffline((Date.now() - hiddenAt) / 1000);
      return;
    }
    hiddenAt = Date.now();
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
    refreshInsideBar();
    refreshCoach();
    refreshSummary();
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
    insideFrame(dt);
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);

  ui.render(state);
  city.update(state);
  applyOffline(awaySeconds);

  // Welcome back: machines kept selling while the app was closed. A rewarded ad doubles it.
  function applyOffline(seconds) {
    if (seconds < 120 || state.machines.length === 0) return;
    const sold = sim.offlineSales(state, seconds);
    if (sold.items === 0) return;
    saveGame(state);
    city.update(state);
    $('offline-message').textContent = `You were away about ${sold.minutes} minutes. Your machines sold ${sold.items} items for $${sold.money.toFixed(2)}. The cash is waiting in them.`;
    $('offline-double').hidden = !rewardReadyNow();
    $('offline-double').onclick = () => showRewardAd(() => {
      state.cash += sold.money;
      saveGame(state);
      ui.refresh(state);
      $('offline-message').textContent = `Doubled! Another $${sold.money.toFixed(2)} is in your cash.`;
      $('offline-double').hidden = true;
    });
    $('offline-dialog').hidden = false;
    paused = true;
  }
  $('offline-continue').addEventListener('click', () => {
    $('offline-dialog').hidden = true;
    paused = !$('pause-dialog').hidden;
  });
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
