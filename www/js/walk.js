// The player and the walkers on the streets. Plain data and functions: the screen draws them and
// feeds them input. Time is in seconds, positions in tiles.
import {
  clipName, findPath, machineFront, PLAYER_SPEED, playerWalkable, slideMove, walkerWalkable, WALKER_SPEED,
} from './locomotion.js';

const MOVING_HOLD = 0.3; // seconds a figure keeps its walk after a step
const LANE = 0.2; // walkers keep to the right of the road, this far from its centre

export function newPlayer(spawn) {
  return {
    x: spawn.x + 0.5,
    z: spawn.y + 0.5,
    facing: 0,
    running: false,
    phase: 0,
    clip: 'walk',
    moving: false,
    holdT: 0,
  };
}

// Moves the player by a stick vector (dx, dz, length up to 1) in the world, then reads the step
// against the facing to pick the clip. clips is the parsed clips.json.
export function movePlayer(player, grid, clips, dx, dz, dt) {
  const length = Math.hypot(dx, dz);
  if (length < 0.02) {
    player.holdT = Math.max(0, player.holdT - dt);
    player.moving = player.holdT > 0;
    return;
  }
  const ux = dx / length;
  const uz = dz / length;
  const speed = (player.running ? PLAYER_SPEED.run : PLAYER_SPEED.walk) * Math.min(1, length);
  const next = slideMove(playerWalkable, grid, player.x, player.z, ux * speed * dt, uz * speed * dt);
  const moved = Math.hypot(next.x - player.x, next.z - player.z);
  player.x = next.x;
  player.z = next.z;
  if (moved > 1e-6) {
    const fx = Math.sin(player.facing);
    const fz = Math.cos(player.facing);
    player.clip = clipName(ux * fx + uz * fz, ux * fz - uz * fx, player.running);
    player.phase += moved / clips.clips[player.clip].stride;
    player.holdT = MOVING_HOLD;
  } else {
    player.holdT = Math.max(0, player.holdT - dt);
  }
  player.moving = player.holdT > 0;
}

export function newWalker(id, cell, look, random) {
  const x = cell.x + 0.5;
  const z = cell.y + 0.5;
  return {
    id,
    cell: { x: cell.x, y: cell.y },
    prev: null,
    from: { x, z },
    to: { x, z },
    progress: 1,
    x,
    z,
    facing: 0,
    phase: random() * 0.9,
    look,
    path: [],
    task: null,
  };
}

// Walkers walk the roads, keep to the right, and wander from crossing to crossing unless they
// have a machine to visit.
export function stepWalker(walker, grid, dt, random) {
  if (walker.progress >= 1) {
    if (walker.to.cell) walker.cell = walker.to.cell;
    const step = nextStep(walker, grid, random);
    if (!step) {
      walker.from = { x: walker.cell.x + 0.5, z: walker.cell.y + 0.5 };
      walker.to = walker.from;
      walker.progress = 1;
      return arrival(walker);
    }
    const dirX = step.x - walker.cell.x;
    const dirY = step.y - walker.cell.y;
    const rightX = -dirY * LANE;
    const rightZ = dirX * LANE;
    walker.from = { x: walker.cell.x + 0.5 + rightX, z: walker.cell.y + 0.5 + rightZ };
    walker.to = { x: step.x + 0.5 + rightX, z: step.y + 0.5 + rightZ, cell: step };
    walker.progress = 0;
  }
  const length = Math.hypot(walker.to.x - walker.from.x, walker.to.z - walker.from.z) || 1;
  walker.progress = Math.min(1, walker.progress + (WALKER_SPEED * dt) / length);
  walker.x = walker.from.x + (walker.to.x - walker.from.x) * walker.progress;
  walker.z = walker.from.z + (walker.to.z - walker.from.z) * walker.progress;
  walker.facing = Math.atan2(walker.to.x - walker.from.x, walker.to.z - walker.from.z);
  walker.phase += (WALKER_SPEED * dt) / 0.37;
  return null;
}

// The cell a walker heads for next: the next cell on its task path, else a road neighbour.
function nextStep(walker, grid, random) {
  if (walker.path.length > 0) {
    const cell = walker.path.shift();
    walker.prev = walker.cell;
    return cell;
  }
  if (walker.task) return null;
  const options = [[1, 0], [-1, 0], [0, 1], [0, -1]]
    .map(([dx, dy]) => ({ x: walker.cell.x + dx, y: walker.cell.y + dy }))
    .filter((c) => walkerWalkable(grid, c.x, c.y));
  if (options.length === 0) return null;
  const ahead = options.filter((c) => !walker.prev || c.x !== walker.prev.x || c.y !== walker.prev.y);
  const pool = ahead.length > 0 ? ahead : options;
  walker.prev = walker.cell;
  return pool[Math.floor(random() * pool.length)];
}

// Called when a walker with a task reaches the front of its machine.
function arrival(walker) {
  if (walker.task && walker.path.length === 0) {
    const done = walker.task;
    walker.task = null;
    return done;
  }
  return null;
}

// Sends a walker to a machine's front. Returns false when the walker cannot get there.
export function sendWalker(walker, grid, machine) {
  const front = machineFront(grid, machine.x, machine.y);
  if (!front) return false;
  const path = findPath(grid, walker.cell, front.cell, walkerWalkable);
  if (!path) return false;
  walker.path = path;
  walker.task = { machineId: machine.id };
  return true;
}

// The walkers that start in the city: a few on random roads.
export function spawnWalkers(grid, count, random, looks) {
  const roads = [];
  grid.forEach((row, y) => row.forEach((cell, x) => {
    if (cell.type === 'road') roads.push({ x, y });
  }));
  const walkers = [];
  for (let i = 0; i < count && roads.length > 0; i++) {
    const cell = roads.splice(Math.floor(random() * roads.length), 1)[0];
    walkers.push(newWalker(i + 1, cell, looks[i % looks.length], random));
  }
  return walkers;
}
