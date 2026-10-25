import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { CONFIG } from '../www/js/config.js';
import * as sim from '../www/js/sim.js';
import * as loco from '../www/js/locomotion.js';
import * as walk from '../www/js/walk.js';
import { cellAt, generateCity, seededRandom } from '../www/js/world.js';

const clips = JSON.parse(fs.readFileSync(new URL('../www/assets/clips.json', import.meta.url), 'utf8'));

// A small hand-made city: row 1 is grass, row 2 has a building at x=2, road at y=0.
function testCity() {
  const grid = [];
  for (let y = 0; y < 5; y++) {
    const row = [];
    for (let x = 0; x < 5; x++) row.push({ type: y === 0 ? 'road' : 'grass' });
    grid.push(row);
  }
  grid[2][2] = { type: 'building', zone: 'office' };
  return grid;
}

test('clips: each movement picks the matching clip', () => {
  assert.equal(loco.clipName(1, 0, false), 'walk');
  assert.equal(loco.clipName(1, 0, true), 'run');
  assert.equal(loco.clipName(-1, 0, false), 'walkBack');
  assert.equal(loco.clipName(-1, 0, true), 'runBack');
  assert.equal(loco.clipName(0, 1, false), 'strafeWalkP');
  assert.equal(loco.clipName(0, -1, true), 'strafeRunN');
});

test('clips.json holds the eight locomotion clips with a stride for each', () => {
  for (const name of ['walk', 'run', 'walkBack', 'runBack', 'strafeWalkP', 'strafeWalkN', 'strafeRunP', 'strafeRunN']) {
    const clip = clips.clips[name];
    assert.ok(clip, name);
    assert.equal(clip.quats.length, clip.frames * clips.bones.length * 4, `${name} quats`);
    assert.ok(clip.stride > 0.3 && clip.stride < 1.1, `${name} stride ${clip.stride}`);
  }
});

test('a sampled pose is a unit quaternion for every bone', () => {
  const pose = loco.newPose();
  for (const phase of [0, 0.13, 0.5, 0.97]) {
    loco.samplePose(clips.clips.walk, phase, pose);
    for (let b = 0; b < 13; b++) {
      const q = pose.quats.slice(b * 4, b * 4 + 4);
      assert.ok(Math.abs(Math.hypot(...q) - 1) < 1e-3, `bone ${b} at ${phase}`);
    }
  }
});

test('the player walks on grass and roads, but not into a building', () => {
  const grid = testCity();
  const player = walk.newPlayer({ x: 0, y: 1 });
  walk.movePlayer(player, grid, clips, 1, 0, 1);
  assert.ok(player.x > 0.5, 'moved along the grass');
  // The building is at (2,2). Walking straight into it from the left stops at its wall.
  const wall = { x: 1.5, z: 2.5 };
  const stuck = loco.slideMove(loco.playerWalkable, grid, wall.x, wall.z, 1, 0);
  assert.ok(stuck.x < 2, 'stopped by the building');
});

test('the player slides along a wall instead of stopping dead', () => {
  const grid = testCity();
  const slid = loco.slideMove(loco.playerWalkable, grid, 1.5, 2.5, 1, 0.3);
  assert.ok(slid.x < 2, 'x blocked by the building');
  assert.ok(slid.z > 2.5, 'z still moves along the wall');
});

test('a stepping player is read against the way they face', () => {
  const grid = testCity();
  const player = walk.newPlayer({ x: 0, y: 1 });
  player.facing = 0; // facing +z
  walk.movePlayer(player, grid, clips, 0, 1, 0.5);
  assert.equal(player.clip, 'walk');
  player.x = 1.5; player.z = 1.5;
  player.facing = 0;
  walk.movePlayer(player, grid, clips, 0, -1, 0.5);
  assert.equal(player.clip, 'walkBack');
});

test('talk and collect reach: touching and in front only', () => {
  const player = { x: 0.5, z: 0.5, facing: 0 };
  assert.equal(loco.inFront(player, 0.5, 1.0, 0.6), true, 'in front and close');
  assert.equal(loco.inFront(player, 0.5, 1.5, 0.6), false, 'too far');
  assert.equal(loco.inFront(player, 0.5, 0.0, 0.6), false, 'behind');
  assert.equal(loco.inFront(player, 0.5, 0.5, 0.6), true, 'touching');
});

test('a path runs around a building and avoids it', () => {
  const grid = testCity();
  const path = loco.findPath(grid, { x: 1, y: 1 }, { x: 3, y: 3 }, loco.playerWalkable);
  assert.ok(path && path.length > 0);
  assert.ok(path.every((c) => !(c.x === 2 && c.y === 2)), 'no step into the building');
  assert.equal(loco.findPath(grid, { x: 1, y: 1 }, { x: 2, y: 2 }, loco.playerWalkable), null);
});

test('a machine\'s front is the road beside its building, and buildings without one take no machine', () => {
  const grid = generateCity(CONFIG.gridSize, 7);
  const state = sim.newGame(7);
  let withFront = 0;
  let withoutFront = 0;
  grid.forEach((row, y) => row.forEach((cell, x) => {
    if (cell.type !== 'building') return;
    const front = loco.machineFront(grid, x, y);
    if (front) {
      assert.equal(cellAt(grid, front.cell.x, front.cell.y).type, 'road');
      withFront++;
    } else {
      assert.equal(sim.buyMachine(state, x, y).ok, false);
      withoutFront++;
    }
  }));
  assert.ok(withFront > 0);
  assert.ok(withoutFront >= 0);
});

test('walkers stay on roads and wander the streets', () => {
  const grid = generateCity(CONFIG.gridSize, 7);
  const random = seededRandom(3);
  const walkers = walk.spawnWalkers(grid, 6, random, [{}]);
  assert.equal(walkers.length, 6);
  for (let i = 0; i < 2000; i++) {
    for (const w of walkers) walk.stepWalker(w, grid, 0.05, random);
    for (const w of walkers) {
      const cx = Math.floor(w.x), cy = Math.floor(w.z);
      assert.ok(cellAt(grid, cx, cy)?.type === 'road' || cellAt(grid, w.cell.x, w.cell.y).type === 'road', 'on a road');
    }
  }
});

test('a walker sent to a machine arrives at its front and makes the sale', () => {
  const grid = generateCity(CONFIG.gridSize, 7);
  const state = sim.newGame(7);
  let spot = null;
  grid.forEach((row, y) => row.forEach((cell, x) => { if (!spot && cell.type === 'building') spot = { x, y }; }));
  sim.buyMachine(state, spot.x, spot.y);
  const machine = state.machines[0];
  for (const p of Object.keys(machine.stock)) machine.stock[p] = 5;
  const random = seededRandom(9);
  const walker = walk.spawnWalkers(grid, 1, random, [{}])[0];
  assert.equal(walk.sendWalker(walker, grid, machine), true);
  let arrived = null;
  for (let i = 0; i < 20000 && !arrived; i++) arrived = walk.stepWalker(walker, grid, 0.05, random);
  assert.deepEqual(arrived, { machineId: machine.id });
  assert.equal(sim.sellToWalker(state, arrived.machineId).ok, true);
});

test('every building has a road beside it, and the middle of a block is never a building', () => {
  for (const seed of [1, 7, 42, 99]) {
    const grid = generateCity(CONFIG.gridSize, seed);
    grid.forEach((row, y) => row.forEach((cell, x) => {
      if (cell.type !== 'building') return;
      const front = loco.machineFront(grid, x, y);
      assert.ok(front, `building ${x},${y} in city ${seed} has road access`);
    }));
  }
});

test('a building\'s front turns toward a road beside it', () => {
  const dirs = { 0: [0, 1], 1: [-1, 0], 2: [0, -1], 3: [1, 0] };
  const grid = generateCity(CONFIG.gridSize, 7);
  let checked = 0;
  grid.forEach((row, y) => row.forEach((cell, x) => {
    if (cell.type !== 'building') return;
    const turns = [0, 3, 2, 1].find((t) => {
      const [dx, dy] = dirs[t];
      return cellAt(grid, x + dx, y + dy)?.type === 'road';
    });
    // The front starts facing +z (south, toward y + 1); a quarter turn moves it one way round.
    const [fx, fz] = turnFront(0, 1, turns);
    assert.equal(cellAt(grid, x + Math.round(fx), y + Math.round(fz))?.type, 'road');
    checked++;
  }));
  assert.ok(checked > 0);
});

// The front after quarter turns, using the same turn as the scene.
function turnFront(x, z, turns) {
  let fx = x;
  let fz = z;
  for (let i = 0; i < turns % 4; i++) {
    const t = fx;
    fx = -fz;
    fz = t;
  }
  return [fx, fz];
}
