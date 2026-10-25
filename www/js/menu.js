// The main menu: start a new game or load one of three saved games from a slot, and set the
// master, music and sound volumes. A slot reloads the page into that game, so each game starts
// with its own city, clock and panels.
import { loadSlot, slotInfo, writeSlot } from './save.js';
import { newGame } from './sim.js';
import { getSettings, setSetting } from './settings.js';
import { applyVolumes, playMusic } from './audio.js';

const SETTINGS = ['master', 'music', 'sound'];

// The slot picked in the address, as #play=2, or null on the menu.
export function pickedSlot() {
  const match = /^#play=([1-3])$/.exec(location.hash);
  return match ? Number(match[1]) : null;
}

// Opens the game in a slot. The page reloads with the slot in its address.
export function playSlot(slot) {
  location.hash = `play=${slot}`;
  location.reload();
}

// Leaves the game for the menu: the page reloads without a slot.
export function goToMenu() {
  history.replaceState(null, '', location.pathname + location.search);
  location.reload();
}

function slotLabel(slot) {
  const info = slotInfo(slot);
  if (!info) return `Slot ${slot}: empty`;
  const cash = Math.round(info.cash).toLocaleString();
  const saved = info.savedAt ? ` · saved ${new Date(info.savedAt).toLocaleString([], { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })}` : '';
  return `Slot ${slot}: day ${info.day}, $${cash}${saved}`;
}

export function initMenu() {
  const menu = document.getElementById('menu');
  menu.hidden = false;

  function show(name) {
    for (const screen of menu.querySelectorAll('[data-screen]')) {
      screen.hidden = screen.dataset.screen !== name;
    }
    if (name === 'start' || name === 'load') refreshSlots(name);
  }

  // Each slot button shows what is saved in it. Load is off for an empty slot.
  function refreshSlots(mode) {
    for (const button of menu.querySelectorAll(`[data-mode="${mode}"][data-slot]`)) {
      const slot = Number(button.dataset.slot);
      button.textContent = slotLabel(slot);
      if (mode === 'load') button.disabled = !slotInfo(slot);
    }
  }

  menu.addEventListener('click', (event) => {
    const go = event.target.closest('[data-go]');
    if (go) {
      show(go.dataset.go);
      return;
    }
    const slotButton = event.target.closest('[data-slot]');
    if (!slotButton || slotButton.disabled) return;
    const slot = Number(slotButton.dataset.slot);
    if (slotButton.dataset.mode === 'start') {
      if (slotInfo(slot) && !confirm(`Replace the game in slot ${slot} with a new one?`)) return;
      writeSlot(slot, newGame(Math.floor(Math.random() * 100000)));
    }
    if (loadSlot(slot)) playSlot(slot);
  });

  for (const name of SETTINGS) {
    const input = menu.querySelector(`[data-setting="${name}"]`);
    const output = menu.querySelector(`[data-out="${name}"]`);
    input.value = getSettings()[name];
    output.textContent = input.value;
    input.addEventListener('input', () => {
      setSetting(name, Number(input.value));
      output.textContent = input.value;
      applyVolumes();
    });
  }

  playMusic('game_menu');
  show('main');
}
