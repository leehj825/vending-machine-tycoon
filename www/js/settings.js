// The volume settings: master, music and sound, each 0 to 100. Kept in this browser.
const KEY = 'vending_tycoon_settings';
const DEFAULTS = { master: 80, music: 60, sound: 80 };

export function getSettings() {
  try {
    return { ...DEFAULTS, ...JSON.parse(localStorage.getItem(KEY) || '{}') };
  } catch {
    return { ...DEFAULTS };
  }
}

export function setSetting(name, value) {
  const settings = getSettings();
  settings[name] = value;
  try {
    localStorage.setItem(KEY, JSON.stringify(settings));
  } catch {
    // Storage unavailable: the setting lasts for this visit only.
  }
  return settings;
}
