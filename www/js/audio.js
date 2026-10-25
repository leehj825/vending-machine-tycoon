// Music and sound effects, with the same sound files and levels as the Flutter app. Web Audio
// plays them. The browser only lets sound start after a tap, so the music starts on the first tap.
import { getSettings } from './settings.js';

// The base level of each track and sound, from the Flutter app's config.
const MUSIC = {
  game_menu: 0.5,
  game_background: 0.2,
};
const SOUNDS = {
  button: 1.0,
  coin_collect: 2.0,
  truck: 0.3,
};

// The slider's level, shaped like the Flutter app: a quiet start, and full at the top.
const curve = (slider) => (slider / 100) ** 2.5;

let ctx = null;
let masterBus = null;
let musicBus = null;
let soundBus = null;
let wanted = null;
let playing = null;
const buffers = new Map();

function context() {
  if (ctx) return ctx;
  const AudioCtx = window.AudioContext || window.webkitAudioContext;
  if (!AudioCtx) return null;
  ctx = new AudioCtx();
  masterBus = ctx.createGain();
  masterBus.connect(ctx.destination);
  musicBus = ctx.createGain();
  musicBus.connect(masterBus);
  soundBus = ctx.createGain();
  soundBus.connect(masterBus);
  applyVolumes();
  return ctx;
}

// Sets the three buses from the saved settings. Called whenever a slider moves.
export function applyVolumes() {
  if (!ctx) return;
  const { master, music, sound } = getSettings();
  masterBus.gain.value = curve(master);
  musicBus.gain.value = curve(music);
  soundBus.gain.value = curve(sound);
}

// The decoded sound file, fetched once.
async function bufferFor(name) {
  if (!buffers.has(name)) {
    buffers.set(name, fetch(`assets/sound/${name}.m4a`)
      .then((response) => response.arrayBuffer())
      .then((data) => ctx.decodeAudioData(data)));
  }
  return buffers.get(name);
}

function stopMusic() {
  if (!playing) return;
  playing.source.stop();
  playing = null;
}

async function startMusic() {
  if (!ctx || ctx.state !== 'running' || !wanted) return;
  if (playing?.name === wanted) return;
  const name = wanted;
  const data = await bufferFor(name);
  if (wanted !== name) return; // another track was asked for while this one loaded
  stopMusic();
  const source = ctx.createBufferSource();
  source.buffer = data;
  source.loop = true;
  const gain = ctx.createGain();
  gain.gain.value = MUSIC[name];
  source.connect(gain);
  gain.connect(musicBus);
  source.start();
  playing = { name, source };
}

// Chooses the music to play: game_menu on the menu, game_background in a game.
export function playMusic(name) {
  wanted = name;
  startMusic();
}

// Called on taps: sound starts after the first tap, then the music that was asked for plays.
export function unlockAudio() {
  const audio = context();
  if (!audio) return;
  if (audio.state !== 'running') audio.resume().then(startMusic);
  else startMusic();
}

// Plays one sound effect, such as a button click or a coin. Louder sounds take a bigger level.
export async function playSound(name) {
  const audio = context();
  if (!audio || audio.state !== 'running') return;
  const data = await bufferFor(name);
  const source = audio.createBufferSource();
  source.buffer = data;
  const gain = audio.createGain();
  gain.gain.value = SOUNDS[name];
  source.connect(gain);
  gain.connect(soundBus);
  source.start();
}
