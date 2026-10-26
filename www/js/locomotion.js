// Movement rules for the player and the walkers: which clip to play, blending between clip
// frames, walkable tiles, sliding along walls, the touch range for Talk and Collect, and paths.
// Pure functions with no browser code, so the tests run them directly.

// Speed of the player's walk and run, in tiles per second.
export const PLAYER_SPEED = { walk: 0.36, run: 1.4 };
export const WALKER_SPEED = 0.4;

// The clip for a movement: forward, backward, or sideways, walking or running. forward and side
// are the movement's parts along the facing: side > 0 is the +X way, as Nightfall's 'p'.
export function clipName(forward, side, running) {
  if (forward > 0.5) return running ? 'run' : 'walk';
  if (forward < -0.5) return running ? 'runBack' : 'walkBack';
  if (side > 0) return running ? 'strafeRunP' : 'strafeWalkP';
  return running ? 'strafeRunN' : 'strafeWalkN';
}

// The bone rotations and hips at a point in a clip's cycle. phase is in cycles; the frames
// between two clip frames are blended by slerp, so motion stays smooth between them.
export function samplePose(clip, phase, out) {
  const cycle = phase - Math.floor(phase);
  const f = cycle * clip.frames;
  const i = Math.floor(f) % clip.frames;
  const j = (i + 1) % clip.frames;
  const t = f - Math.floor(f);
  const bones = clip.quats.length / clip.frames / 4;
  const size = bones * 4;
  for (let b = 0; b < bones; b++) {
    slerp(clip.quats, i * size + b * 4, clip.quats, j * size + b * 4, t, out.quats, b * 4);
  }
  out.hipY = clip.hipY[i] + (clip.hipY[j] - clip.hipY[i]) * t;
  out.hipZ = clip.hipZ[i] + (clip.hipZ[j] - clip.hipZ[i]) * t;
  return out;
}

// Keeps only part of the hips' and spine's rotation, so the body turns less while the arms swing.
const IDENTITY = [0, 0, 0, 1];
// The head keeps less of the clip's own turn than the torso does, so it stops shaking.
const HEAD_KEEP = 0.3;
export function calmTorso(pose, keep) {
  for (const [bone, boneKeep] of [[0, keep], [1, keep], [2, HEAD_KEEP]]) {
    slerp(pose.quats, bone * 4, IDENTITY, 0, 1 - boneKeep, pose.quats, bone * 4);
  }
  return pose;
}

export function newPose(bones = 13) {
  return { quats: new Array(bones * 4).fill(0), hipY: 0.9, hipZ: 0 };
}

// Blends two quaternions stored in arrays, writing the result to out at offset.
function slerp(a, ai, b, bi, t, out, oi) {
  let dot = a[ai] * a[bi] + a[ai + 1] * a[bi + 1] + a[ai + 2] * a[bi + 2] + a[ai + 3] * a[bi + 3];
  let sign = 1;
  if (dot < 0) {
    dot = -dot;
    sign = -1;
  }
  let k0;
  let k1;
  if (dot > 0.9995) {
    k0 = 1 - t;
    k1 = t * sign;
  } else {
    const theta = Math.acos(dot);
    const sin = Math.sin(theta);
    k0 = Math.sin((1 - t) * theta) / sin;
    k1 = (Math.sin(t * theta) / sin) * sign;
  }
  const x = k0 * a[ai] + k1 * b[bi];
  const y = k0 * a[ai + 1] + k1 * b[bi + 1];
  const z = k0 * a[ai + 2] + k1 * b[bi + 2];
  const w = k0 * a[ai + 3] + k1 * b[bi + 3];
  const len = Math.hypot(x, y, z, w) || 1;
  out[oi] = x / len;
  out[oi + 1] = y / len;
  out[oi + 2] = z / len;
  out[oi + 3] = w / len;
}

// Players walk on grass and roads; buildings are solid. Walkers stay on roads.
export function playerWalkable(grid, x, y) {
  const cell = cellAt(grid, x, y);
  return cell !== null && (cell.type === 'road' || cell.type === 'grass' || cell.type === 'park' || cell.type === 'lot' || cell.type === 'gas');
}

export function walkerWalkable(grid, x, y) {
  const cell = cellAt(grid, x, y);
  return cell !== null && cell.type === 'road';
}

function cellAt(grid, x, y) {
  if (y < 0 || y >= grid.length || x < 0 || x >= grid[y].length) return null;
  return grid[y][x];
}

// Moves a point by (dx, dz) with the walls in the way: each axis moves only if its new spot is
// walkable, so the player slides along a building instead of stopping dead.
export function slideMove(walkable, grid, x, z, dx, dz) {
  let nx = x;
  let nz = z;
  if (walkable(grid, Math.floor(x + dx), Math.floor(z))) nx = x + dx;
  if (walkable(grid, Math.floor(nx), Math.floor(z + dz))) nz = z + dz;
  return { x: nx, z: nz };
}

// Whether a target is within reach and in front of the player: within about 60 degrees of the
// way they face. Anything within 0.3 tiles counts as touching, whichever way the player faces.
export function inFront(player, tx, tz, reach) {
  const dx = tx - player.x;
  const dz = tz - player.z;
  const distance = Math.hypot(dx, dz);
  if (distance > reach) return false;
  if (distance < 0.3) return true;
  const fx = Math.sin(player.facing);
  const fz = Math.cos(player.facing);
  return (dx * fx + dz * fz) / distance >= 0.5;
}

// The shortest path over cells that pass `allowed`, from start to goal, without the start cell.
// Null when the goal cannot be reached.
export function findPath(grid, start, goal, allowed) {
  if (start.x === goal.x && start.y === goal.y) return [];
  const key = (c) => `${c.x},${c.y}`;
  const previous = new Map([[key(start), start]]);
  const queue = [start];
  for (let head = 0; head < queue.length; head++) {
    const current = queue[head];
    if (current.x === goal.x && current.y === goal.y) break;
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const next = { x: current.x + dx, y: current.y + dy };
      if (previous.has(key(next)) || !allowed(grid, next.x, next.y)) continue;
      previous.set(key(next), current);
      queue.push(next);
    }
  }
  if (!previous.has(key(goal))) return null;
  const path = [];
  let cell = goal;
  while (!(cell.x === start.x && cell.y === start.y)) {
    path.push(cell);
    cell = previous.get(key(cell));
  }
  return path.reverse();
}

// Where a machine's customers stand: the road tile next to its building, and the anchor point
// just in front of the building that the player must be near to use it.
export function machineFront(grid, x, y) {
  const dirs = [[0, 1], [0, -1], [1, 0], [-1, 0]];
  for (const [dx, dy] of dirs) {
    const cell = cellAt(grid, x + dx, y + dy);
    if (cell && cell.type === 'road') {
      return {
        cell: { x: x + dx, y: y + dy },
        anchor: { x: x + 0.5 + dx * 0.5, z: y + 0.5 + dy * 0.5 },
      };
    }
  }
  return null;
}
