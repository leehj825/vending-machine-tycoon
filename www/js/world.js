import { ZONE_IDS } from './products.js';
import { CONFIG } from './config.js';

// A small seeded random generator, so the same seed always makes the same city.
export function seededRandom(seed) {
  let t = seed >>> 0;
  return () => {
    t = (t + 0x6d2b79f5) >>> 0;
    let r = t;
    r = Math.imul(r ^ (r >>> 15), r | 1);
    r ^= r + Math.imul(r ^ (r >>> 7), r | 61);
    return ((r ^ (r >>> 14)) >>> 0) / 4294967296;
  };
}

// The city: a road every third column, and horizontal roads that cross each strip between two of
// them at rows that come at varying distances. So each block is two tiles wide and two or more
// tiles long, and every tile of a block touches a road. A block becomes a park, a small parking
// lot, a gas station, or a row of buildings with at most two shop fronts.
export function generateCity(size, seed = 7) {
  const random = seededRandom(seed);
  const grid = [];
  for (let y = 0; y < size; y++) {
    const row = [];
    for (let x = 0; x < size; x++) row.push({ type: x % 3 === 0 ? 'road' : 'grass' });
    grid.push(row);
  }
  for (let x0 = 0; x0 + 3 < size; x0 += 3) {
    const rows = roadRows(random, size);
    for (const y of rows) {
      grid[y][x0 + 1] = { type: 'road' };
      grid[y][x0 + 2] = { type: 'road' };
    }
    for (let i = 0; i + 1 < rows.length; i++) {
      const top = rows[i] + 1;
      const bottom = rows[i + 1] - 1;
      if (bottom >= top) fillBlock(grid, random, x0 + 1, top, bottom);
    }
  }
  // The strip at the right edge has no road beyond it, so it is park or grass.
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      if (grid[y][x].type === 'grass' && x >= size - 2) grid[y][x] = { type: random() < 0.4 ? 'park' : 'grass' };
    }
  }
  // A building must have a road beside it, so its front faces the street.
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const type = grid[y][x].type;
      if ((type === 'building' || type === 'house') && !hasRoadBeside(grid, x, y)) grid[y][x] = { type: 'grass' };
    }
  }
  return grid;
}

// The rows of the horizontal roads across one strip: the first and last rows, and rows 3 to 7
// apart in between, so the blocks between them are 2 to 6 tiles long.
function roadRows(random, size) {
  const rows = [0];
  let y = 0;
  for (;;) {
    const gap = 3 + Math.floor(random() * 5);
    if (y + gap >= size - 1) break;
    y += gap;
    rows.push(y);
  }
  rows.push(size - 1);
  return rows;
}

// Fills one block (two tiles wide, from row top to row bottom) with a park, a parking lot, a gas
// station, or buildings. Lots and gas stations take one row of the block, when it is long enough.
function fillBlock(grid, random, x0, top, bottom) {
  const length = bottom - top + 1;
  const tiles = [];
  for (let y = top; y <= bottom; y++) {
    for (const x of [x0, x0 + 1]) tiles.push({ x, y });
  }
  const roll = random();
  if (roll < 0.08) {
    for (const t of tiles) grid[t.y][t.x] = { type: 'park' };
    return;
  }
  let rest = tiles;
  if (length >= 2 && roll < 0.16) {
    for (const t of tiles.filter((t) => t.y === top)) grid[t.y][t.x] = { type: 'lot' };
    rest = tiles.filter((t) => t.y !== top);
  } else if (length >= 2 && roll < 0.22) {
    for (const t of tiles.filter((t) => t.y === bottom)) grid[t.y][t.x] = { type: 'gas' };
    rest = tiles.filter((t) => t.y !== bottom);
  }
  let shops = 0;
  for (const t of rest) {
    // Most of a block is buildings: up to two shop fronts, and houses for the rest. A few tiles are
    // parks or grass.
    const r = random();
    if (r < 0.45 && shops < 2) {
      shops++;
      grid[t.y][t.x] = { type: 'building', zone: ZONE_IDS[Math.floor(random() * ZONE_IDS.length)] };
    } else if (r < 0.9) {
      grid[t.y][t.x] = { type: 'house', zone: ZONE_IDS[Math.floor(random() * ZONE_IDS.length)] };
    } else {
      grid[t.y][t.x] = { type: random() < 0.5 ? 'park' : 'grass' };
    }
  }
}

function hasRoadBeside(grid, x, y) {
  return [[0, 1], [0, -1], [1, 0], [-1, 0]].some(([dx, dy]) => {
    const cell = cellAt(grid, x + dx, y + dy);
    return cell !== null && cell.type === 'road';
  });
}

export function cellAt(city, x, y) {
  if (y < 0 || y >= city.length || x < 0 || x >= city[y].length) return null;
  return city[y][x];
}

// Where the warehouse stands: the first road crossing, at the top left.
// The district a tile is in: 0 north-west (with the warehouse), 1 north-east, 2 south-west, 3 south-east.
export function districtOf(x, y) {
  return (x >= CONFIG.districtSplit ? 1 : 0) + (y >= CONFIG.districtSplit ? 2 : 0);
}

// The tiles a district covers, as x0, y0, x1, y1 (the end exclusive), in a map of the given size.
export function districtBounds(id, size) {
  const split = CONFIG.districtSplit;
  return {
    x0: id % 2 === 0 ? 0 : split,
    x1: id % 2 === 0 ? split : size,
    y0: id < 2 ? 0 : split,
    y1: id < 2 ? split : size,
  };
}

export const WAREHOUSE_CELL = { x: 0, y: 0 };
