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

// The city is a grid of roads every fourth row and column, with blocks between them. Each
// block tile is a building of some zone, or a patch of grass. Only some buildings are shop
// fronts, where a machine can go; the rest are houses, which are just for looking at.
export function generateCity(size, seed = 7) {
  const random = seededRandom(seed);
  const grid = [];
  for (let y = 0; y < size; y++) {
    const row = [];
    for (let x = 0; x < size; x++) {
      if (x % 4 === 0 || y % 4 === 0) {
        row.push({ type: 'road' });
      } else if (random() < 0.25) {
        row.push({ type: random() < 0.4 ? 'park' : 'grass' });
      } else {
        const zone = ZONE_IDS[Math.floor(random() * ZONE_IDS.length)];
        const roll = random();
        if (roll < CONFIG.shopFrontShare) row.push({ type: 'building', zone });
        else if (roll < CONFIG.shopFrontShare + CONFIG.houseShare) row.push({ type: 'house', zone });
        else row.push({ type: random() < 0.4 ? 'park' : 'grass' });
      }
    }
    grid.push(row);
  }
  // A building must have a road beside it, so its front faces the street. A block's middle tile
  // has no road beside it, so it is grass instead.
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const type = grid[y][x].type;
      if ((type === 'building' || type === 'house') && !hasRoadBeside(grid, x, y)) grid[y][x] = { type: 'grass' };
    }
  }
  return grid;
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
export const WAREHOUSE_CELL = { x: 0, y: 0 };
