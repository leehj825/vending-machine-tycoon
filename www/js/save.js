import { CONFIG } from './config.js';
import { migrateState } from './sim.js';

// Saves live in this browser's local storage, in three slots. Every read and write is guarded,
// because some browsers block storage: the game then simply runs without saving.
export const SLOT_COUNT = 3;

let activeSlot = 1;

const keyFor = (slot) => `${CONFIG.saveKey}_slot${slot}`;

// The game being played. saveGame writes to this slot.
export function setActiveSlot(slot) {
  activeSlot = slot;
  migrateOldSave();
}

// The save that was made before there were slots goes into slot 1.
function migrateOldSave() {
  try {
    const old = localStorage.getItem(CONFIG.saveKey);
    if (old && !localStorage.getItem(keyFor(1))) localStorage.setItem(keyFor(1), old);
    if (old) localStorage.removeItem(CONFIG.saveKey);
  } catch {
    // Storage unavailable: nothing to move.
  }
}

// The saved game in a slot, or null when the slot is empty.
export function loadSlot(slot) {
  try {
    const raw = localStorage.getItem(keyFor(slot));
    if (!raw) return null;
    const saved = JSON.parse(raw);
    return migrateState(saved.state ?? saved);
  } catch {
    return null;
  }
}

// What a slot shows on the menu: the day, the cash and when it was saved. Null when empty.
export function slotInfo(slot) {
  try {
    const raw = localStorage.getItem(keyFor(slot));
    if (!raw) return null;
    const saved = JSON.parse(raw);
    const state = saved.state ?? saved;
    return { day: state.day, cash: state.cash, savedAt: saved.savedAt ?? null };
  } catch {
    return null;
  }
}

export function saveGame(state) {
  writeSlot(activeSlot, state);
}

export function writeSlot(slot, state) {
  try {
    localStorage.setItem(keyFor(slot), JSON.stringify({ savedAt: Date.now(), state }));
  } catch {
    // Storage unavailable: keep playing without a save.
  }
}
