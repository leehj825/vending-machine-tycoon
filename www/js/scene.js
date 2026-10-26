// The low-poly city, drawn the way the original game drew it: asphalt with lane markings and
// kerbs, grass, pavements, buildings with their own shapes for each zone, street lamps and trees,
// vending machines on the front corner of their building, and the markers over buildings.
import { MeshBuilder, turnPoint } from './lowpoly.js';
import { ZONES, PRODUCTS, PRODUCT_IDS } from './products.js';
import { CONFIG } from './config.js';

const EARTH = 0x6b5b45;
const GRASS_A = 0x7cc26a;
const GRASS_B = 0x69b05a;
const ASPHALT = 0x4a4f57;
const LANE = 0xf2f2f2;
const PAVEMENT = 0xbdbdb5;
const PAVEMENT_WIDTH = 0.2;
const TRIM = 0x37474f;
const PLINTH = 0x9e9e94;
const WHITE = 0xf5f7fa;
const GLASS = 0xbfe7f2;
const GLASS_DARK = 0x2c3e50;
const WARM = 0xffe9a8;
const LAMP_LIGHT = 0xfff59d;
const DARK_GREY = 0x4b5563;
const GREY = 0x9aa5b1;
const RED = 0xe53935;
const BROWN = 0x6d4c41;
const BRICK = 0xb5523b;
const FOLIAGE = 0x3f9142;
const TRUNK = 0x7a5230;
const BUSH = 0x4caf50;
const STEEL = 0xb0bec5;
const DARK = 0x2b2f38;
const MACHINE_BASE = 0x3a3f47;
const OWNED_BLUE = 0x1e88e5;
const COIN = 0xc9963a;
const COIN_TOP = 0xf2c94c;
const AFFORDABLE = 0x43a047;
const UNAFFORDABLE = 0xffc107;
const MACHINE_SCALE = 0.13;

// Body footprint and height per zone: x0, z0, x1, z1, and the top of the main body.
export const BODIES = {
  shop: [0.1, 0.12, 0.9, 0.88, 0.55],
  school: [0.1, 0.12, 0.9, 0.88, 0.5],
  gym: [0.08, 0.1, 0.92, 0.9, 0.7],
  office: [0.2, 0.2, 0.8, 0.8, 1.5],
  subway: [0.1, 0.14, 0.9, 0.86, 0.32],
  hospital: [0.1, 0.1, 0.9, 0.9, 0.9],
  university: [0.1, 0.14, 0.9, 0.86, 0.72],
};


function lerpHex(a, b, t) {
  const ch = (h, s) => (h >> s) & 255;
  const mix = (s) => Math.round(ch(a, s) + (ch(b, s) - ch(a, s)) * t);
  return (mix(16) << 16) | (mix(8) << 8) | mix(0);
}

// Deterministic 0..1 value per cell, so grass varies without flickering.
export function cellNoise(x, y) {
  return (((x * 73 + y * 151 + x * y * 31) % 97) / 96);
}


export function isRoad(grid, x, y) {
  if (y < 0 || y >= grid.length || x < 0 || x >= grid[y].length) return false;
  return grid[y][x].type === 'road';
}

// Shop fronts and houses both stand as buildings; only shop fronts get purchase markers.
export function isBuildingCell(cell) {
  return cell.type === 'building' || cell.type === 'house';
}

// Quarter turns that turn a building so its front faces a road next to it. Null with no road.
export function frontTurns(grid, x, y) {
  if (isRoad(grid, x, y + 1)) return 0;
  if (isRoad(grid, x + 1, y)) return 3;
  if (isRoad(grid, x, y - 1)) return 2;
  if (isRoad(grid, x - 1, y)) return 1;
  return null;
}

// Where a machine stands on its tile: the front corner on the road side, in world (x, z).
export function machineAnchor(grid, x, y) {
  const turns = frontTurns(grid, x, y) ?? 0;
  const [dx, dz] = turnPoint(0.8 - 0.5, 0.95 - 0.5, turns);
  return { x: x + 0.5 + dx, z: y + 0.5 + dz, turns };
}

// Height of the marker over a zone's building: just above its roof.
export function markerHeight(zone) {
  return BODIES[zone][4] + 0.45;
}

// Lane markings and kerbs for a road tile. Lanes run along the road, not across junctions.
function roadTile(m, grid, x, y) {
  const leftOpen = !isRoad(grid, x - 1, y);
  const rightOpen = !isRoad(grid, x + 1, y);
  const backOpen = !isRoad(grid, x, y - 1);
  const frontOpen = !isRoad(grid, x, y + 1);
  const x0 = leftOpen ? PAVEMENT_WIDTH : 0;
  const x1 = rightOpen ? 1 - PAVEMENT_WIDTH : 1;
  const y0 = backOpen ? PAVEMENT_WIDTH : 0;
  const y1 = frontOpen ? 1 - PAVEMENT_WIDTH : 1;
  m.flat(x + x0, y + y0, x + x1, y + y1, 0, ASPHALT);
  if (leftOpen) m.flat(x, y, x + PAVEMENT_WIDTH, y + 1, 0.005, PAVEMENT);
  if (rightOpen) m.flat(x + 1 - PAVEMENT_WIDTH, y, x + 1, y + 1, 0.005, PAVEMENT);
  if (backOpen) m.flat(x, y, x + 1, y + PAVEMENT_WIDTH, 0.005, PAVEMENT);
  if (frontOpen) m.flat(x, y + 1 - PAVEMENT_WIDTH, x + 1, y + 1, 0.005, PAVEMENT);
  const across = isRoad(grid, x - 1, y) || isRoad(grid, x + 1, y);
  const along = isRoad(grid, x, y - 1) || isRoad(grid, x, y + 1);
  if (along && !across) m.flat(x + 0.47, y + 0.1, x + 0.53, y + 0.9, 0.004, LANE);
  else if (across && !along) m.flat(x + 0.1, y + 0.47, x + 0.9, y + 0.53, 0.004, LANE);
}

// A park: a lawn with a path, a pond and a few trees. Nothing to buy here.
function park(m, x, y) {
  m.flat(x, y, x + 1, y + 1, 0, 0x8bd17c);
  m.flat(x + 0.44, y, x + 0.56, y + 1, 0.003, 0xd7ccc8);
  m.flat(x + 0.12, y + 0.12, x + 0.42, y + 0.36, 0.004, 0x4fc3f7);
  for (const [tx, tz] of [[0.72, 0.2], [0.8, 0.7], [0.22, 0.78]]) {
    m.box(x + tx - 0.02, 0, y + tz - 0.02, x + tx + 0.02, 0.22, y + tz + 0.02, TRUNK);
    m.cone(x + tx, y + tz, 0.12, 6, 0.2, 0.6, FOLIAGE);
  }
}

// A gabled roof: two sloping sides meeting at a ridge along x, with a triangle at each end.


// A house: a cottage with a gabled roof, a porch, and windows with frames, shutters and flower
// boxes. Walls, roof, height, chimney, hedges and garden vary from house to house. Only for looking.

function groundTile(m, grid, x, y, cell) {
  if (cell.type === 'road') {
    roadTile(m, grid, x, y);
    return;
  }
  if (cell.type === 'park') {
    park(m, x, y);
    return;
  }
  const grass = lerpHex(GRASS_A, GRASS_B, cellNoise(x, y));
  m.flat(x, y, x + 1, y + 1, 0, grass);
}

// Lamp post on a corner of the tile.
function lamp(m, px, pz) {
  m.box(px - 0.02, 0, pz - 0.02, px + 0.02, 0.42, pz + 0.02, DARK_GREY);
  m.box(px - 0.05, 0.42, pz - 0.05, px + 0.05, 0.48, pz + 0.05, LAMP_LIGHT);
}

// Lamps and street trees on the pavement of tiles beside a road.
function streetObjects(m, grid, x, y, cell) {
  if (cell.type === 'road') return;
  const onRoad = isRoad(grid, x, y - 1) || isRoad(grid, x, y + 1) || isRoad(grid, x - 1, y) || isRoad(grid, x + 1, y);
  if (!onRoad) return;
  if ((x + y) % 2 === 0) {
    lamp(m, x + 0.9, y + 0.1);
  } else {
    const tx = x + 0.12;
    const tz = y + 0.12;
    m.box(tx - 0.02, 0, tz - 0.02, tx + 0.02, 0.14, tz + 0.02, TRUNK);
    m.cone(tx, tz, 0.1, 6, 0.12, 0.42, FOLIAGE);
  }
}

// The building of a zone, in its own shape, with its parts listed back to front.

// Corner pillars, a rooftop unit, and an antenna on the taller buildings.

// The static city: ground, streets, buildings and street trees. Buildings are turned so their
// front faces a road. Returns { positions, colors } for one geometry.
export function buildStaticScene(grid, brightness = 1) {
  const size = grid.length;
  const m = new MeshBuilder({ brightness });
  m.flat(-0.4, -0.4, size + 0.4, size + 0.4, -0.05, EARTH);
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < grid[y].length; x++) {
      const cell = grid[y][x];
      groundTile(m, grid, x, y, cell);
    }
  }
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < grid[y].length; x++) {
      const cell = grid[y][x];
      streetObjects(m, grid, x, y, cell);
    }
  }
  return m.arrays();
}




// Purchase arrows over buildings without a machine: green when the cash covers it, amber when
// not. Owned buildings get a blue plate, and a machine with cash gets a coin above it.
export function buildMarkers(state, bob = 0) {
  const arrows = new MeshBuilder();
  const owned = new MeshBuilder();
  const coins = new MeshBuilder();
  const grid = state.city;
  const machineAt = new Set(state.machines.map((m) => `${m.x},${m.y}`));
  const affordable = state.cash >= CONFIG.machinePrice;
  grid.forEach((row, y) => row.forEach((cell, x) => {
    if (cell.type !== 'building') return;
    const h = markerHeight(cell.zone) + bob;
    if (machineAt.has(`${x},${y}`)) {
      owned.box(x + 0.4, h, y + 0.46, x + 0.6, h + 0.06, y + 0.54, OWNED_BLUE);
      owned.box(x + 0.44, h + 0.06, y + 0.48, x + 0.56, h + 0.07, y + 0.52, WHITE);
    } else {
      arrows.cone(x + 0.5, y + 0.5, 0.22, 6, h + 0.3, h, affordable ? AFFORDABLE : UNAFFORDABLE);
    }
  }));
  for (const machine of state.machines) {
    if (machine.cash <= 0) continue;
    const anchor = machineAnchor(grid, machine.x, machine.y);
    const h = 0.7 + bob;
    coins.prism(anchor.x, anchor.z, 0.12, 12, h, h + 0.05, COIN, { top: COIN_TOP });
  }
  return { arrows: arrows.arrays(), owned: owned.arrays(), coins: coins.arrays() };
}

// A delivery truck, built about its own origin: u runs along its travel, v across it.
export function buildTruck() {
  const m = new MeshBuilder();
  // Parts as (u0, u1, v0, v1, y0, y1, colour, top), with u along z and v along x.
  const part = (u0, u1, v0, v1, y0, y1, colour, top = null) => {
    m.box(v0, y0, u0, v1, y1, u1, colour, { top });
  };
  part(-0.3, 0.08, -0.12, 0.12, 0.08, 0.36, WHITE, 0xdce6f0);
  part(0.08, 0.3, -0.11, 0.11, 0.06, 0.26, 0xd32f2f);
  part(0.27, 0.31, -0.09, 0.09, 0.14, 0.22, GLASS);
  part(-0.22, -0.12, 0.1, 0.14, 0, 0.06, DARK_GREY);
  part(-0.22, -0.12, -0.14, -0.1, 0, 0.06, DARK_GREY);
  part(0.14, 0.24, 0.1, 0.14, 0, 0.06, DARK_GREY);
  part(0.14, 0.24, -0.14, -0.1, 0, 0.06, DARK_GREY);
  return m.arrays();
}
