import { CONFIG } from './config.js';

// Saves live in this browser's local storage. Every read and write is guarded, because some
// browsers block storage: the game then simply runs without saving.
export function loadGame() {
  try {
    const raw = localStorage.getItem(CONFIG.saveKey);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

export function saveGame(state) {
  try {
    localStorage.setItem(CONFIG.saveKey, JSON.stringify(state));
  } catch {
    // Storage unavailable: keep playing without a save.
  }
}
