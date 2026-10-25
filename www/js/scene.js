// The low-poly city, drawn the way the original game drew it: asphalt with lane markings and
// kerbs, grass, pavements, buildings with their own shapes for each zone, street lamps and trees,
// vending machines on the front corner of their building, and the markers over buildings.
import { MeshBuilder, turnPoint, turnTransform } from './lowpoly.js';
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
const BODIES = {
  shop: [0.1, 0.12, 0.9, 0.88, 0.55],
  school: [0.1, 0.12, 0.9, 0.88, 0.5],
  gym: [0.08, 0.1, 0.92, 0.9, 0.7],
  office: [0.2, 0.2, 0.8, 0.8, 1.5],
  subway: [0.1, 0.14, 0.9, 0.86, 0.32],
  hospital: [0.1, 0.1, 0.9, 0.9, 0.9],
  university: [0.1, 0.14, 0.9, 0.86, 0.72],
};

const OFFICE_BODIES = [0x8fb8de, 0xb0bec5, 0x9fd3c7, 0xc9b6e4];
const AWNINGS = [0xe4572e, 0x2e7d32, 0x1565c0, 0xf9a825];

function lerpHex(a, b, t) {
  const ch = (h, s) => (h >> s) & 255;
  const mix = (s) => Math.round(ch(a, s) + (ch(b, s) - ch(a, s)) * t);
  return (mix(16) << 16) | (mix(8) << 8) | mix(0);
}

// Deterministic 0..1 value per cell, so grass varies without flickering.
function cellNoise(x, y) {
  return (((x * 73 + y * 151 + x * y * 31) % 97) / 96);
}

function variant(palette, x, y) {
  return palette[(x * 7 + y * 13 + x * y) % palette.length];
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

function groundTile(m, grid, x, y, cell) {
  if (cell.type === 'road') {
    roadTile(m, grid, x, y);
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
function building(m, x, y, zone) {
  const body = BODIES[zone];
  const [bx0, bz0, bx1, bz1, top] = body;
  m.box(x + bx0 - 0.015, 0, y + bz0 - 0.015, x + bx1 + 0.015, 0.06, y + bz1 + 0.015, PLINTH);
  switch (zone) {
    case 'shop':
      m.box(x + 0.1, 0, y + 0.12, x + 0.9, 0.55, y + 0.88, 0xf2c14e, { top: 0x8d6e63 });
      m.windows(x + 0.1, y + 0.12, x + 0.9, y + 0.88, 0.12, 0.42, { cols: 3, rows: 1, glass: GLASS, frame: TRIM, lit: WARM });
      m.box(x + 0.44, 0, y + 0.88, x + 0.56, 0.34, y + 0.93, BROWN);
      m.box(x + 0.06, 0.42, y + 0.84, x + 0.94, 0.52, y + 0.94, 0xe4572e);
      for (const sx of [0.16, 0.44, 0.72]) m.box(x + sx, 0.42, y + 0.94, x + sx + 0.1, 0.52, y + 0.955, WHITE);
      m.box(x + 0.3, 0.55, y + 0.84, x + 0.7, 0.66, y + 0.9, 0xfff176);
      m.box(x + 0.12, 0, y + 0.9, x + 0.22, 0.12, y + 0.98, BUSH);
      m.box(x + 0.78, 0, y + 0.9, x + 0.88, 0.12, y + 0.98, BUSH);
      m.box(x + 0.7, 0.55, y + 0.3, x + 0.84, 0.63, y + 0.46, DARK_GREY);
      lamp(m, x + 0.93, y + 0.93);
      break;
    case 'gym':
      m.box(x + 0.06, 0, y + 0.12, x + 0.94, 0.5, y + 0.9, BRICK, { top: 0x6b7280 });
      m.windows(x + 0.06, y + 0.12, x + 0.94, y + 0.9, 0.12, 0.34, { cols: 5, rows: 1, glass: GLASS, frame: TRIM, lit: WARM });
      m.box(x + 0.3, 0, y + 0.62, x + 0.7, 0.86, y + 0.92, 0x37474f, { top: 0x263238 });
      m.box(x + 0.36, 0.2, y + 0.92, x + 0.64, 0.7, y + 0.94, GLASS);
      m.box(x + 0.3, 0.72, y + 0.6, x + 0.7, 0.84, y + 0.94, RED);
      m.box(x + 0.4, 0.76, y + 0.94, x + 0.6, 0.8, y + 0.96, WHITE);
      m.prism(x + 0.25, y + 0.35, 0.1, 6, 0.5, 0.62, 0x90a4ae);
      m.prism(x + 0.7, y + 0.35, 0.1, 6, 0.5, 0.62, 0x90a4ae);
      lamp(m, x + 0.93, y + 0.93);
      break;
    case 'office':
      m.box(x + 0.2, 0, y + 0.2, x + 0.8, 1.5, y + 0.8, variant(OFFICE_BODIES, x, y), { top: 0x3d5a80 });
      m.windows(x + 0.2, y + 0.2, x + 0.8, y + 0.8, 0.12, 1.42, { cols: 3, rows: 6, glass: GLASS, frame: TRIM, lit: WARM });
      m.box(x + 0.3, 1.5, y + 0.3, x + 0.7, 1.62, y + 0.7, 0x3d5a80);
      m.box(x + 0.32, 1.62, y + 0.32, x + 0.44, 1.7, y + 0.44, GREY);
      m.box(x + 0.56, 1.62, y + 0.56, x + 0.6, 1.95, y + 0.6, GREY);
      m.box(x + 0.42, 0, y + 0.8, x + 0.58, 0.24, y + 0.86, GLASS_DARK);
      m.box(x + 0.36, 0.24, y + 0.78, x + 0.64, 0.28, y + 0.9, 0x1f2a44);
      lamp(m, x + 0.93, y + 0.93);
      break;
    case 'school': {
      const cream = 0xf2d6a2;
      const creamTop = 0xe0be85;
      const tower = 0xd9b77e;
      m.box(x + 0.08, 0, y + 0.22, x + 0.92, 0.46, y + 0.88, cream, { top: creamTop });
      m.windows(x + 0.08, y + 0.22, x + 0.92, y + 0.88, 0.1, 0.34, { cols: 6, rows: 1, glass: GLASS, frame: TRIM, lit: WARM });
      m.box(x + 0.38, 0, y + 0.08, x + 0.62, 0.8, y + 0.32, tower, { top: creamTop });
      m.windows(x + 0.38, y + 0.08, x + 0.62, y + 0.32, 0.5, 0.7, { cols: 1, rows: 1, glass: GLASS, frame: TRIM });
      m.roof(x + 0.35, y + 0.05, x + 0.65, y + 0.35, 0.8, 1.0, 0xc0392b);
      m.box(x + 0.44, 0, y + 0.88, x + 0.56, 0.26, y + 0.93, BROWN);
      m.box(x + 0.34, 0.28, y + 0.88, x + 0.66, 0.36, y + 0.93, 0xffd54f);
      m.box(x + 0.2, 0.46, y + 0.5, x + 0.23, 0.9, y + 0.53, GREY);
      m.box(x + 0.23, 0.78, y + 0.5, x + 0.36, 0.86, y + 0.53, RED);
      lamp(m, x + 0.07, y + 0.93);
      break;
    }
    case 'subway':
      m.box(x + 0.1, 0, y + 0.1, x + 0.9, 0.04, y + 0.9, 0xbdbdb5);
      m.box(x + 0.32, 0, y + 0.3, x + 0.68, 0.3, y + 0.7, 0x2e5a80, { top: 0x1f3f5c });
      m.box(x + 0.36, 0.04, y + 0.66, x + 0.64, 0.1, y + 0.72, 0x263238);
      m.box(x + 0.4, 0.1, y + 0.7, x + 0.6, 0.16, y + 0.76, 0x263238);
      m.box(x + 0.28, 0.3, y + 0.26, x + 0.72, 0.34, y + 0.74, GREY, { top: 0x9aa5b1 });
      m.box(x + 0.7, 0, y + 0.5, x + 0.74, 1.05, y + 0.54, DARK_GREY);
      m.prism(x + 0.72, y + 0.52, 0.14, 14, 1.0, 1.12, RED);
      m.box(x + 0.56, 1.04, y + 0.5, x + 0.88, 1.08, y + 0.56, 0x1565c0);
      lamp(m, x + 0.07, y + 0.93);
      break;
    case 'hospital':
      m.box(x + 0.1, 0, y + 0.1, x + 0.9, 0.9, y + 0.9, WHITE, { top: 0xe3e8ef });
      m.windows(x + 0.1, y + 0.1, x + 0.9, y + 0.9, 0.3, 0.86, { cols: 4, rows: 2, glass: GLASS, frame: TRIM, lit: WARM });
      m.box(x + 0.34, 0.24, y + 0.9, x + 0.66, 0.3, y + 0.99, 0x26a69a);
      m.box(x + 0.42, 0, y + 0.9, x + 0.58, 0.24, y + 0.94, GLASS_DARK);
      m.box(x + 0.42, 0.9, y + 0.28, x + 0.58, 0.94, y + 0.72, RED);
      m.box(x + 0.28, 0.9, y + 0.42, x + 0.72, 0.94, y + 0.58, RED);
      lamp(m, x + 0.93, y + 0.93);
      break;
    case 'university': {
      const stone = 0xd8c3a5;
      const stoneTop = 0xb89f82;
      const dome = 0x3f51b5;
      m.box(x + 0.1, 0, y + 0.16, x + 0.9, 0.7, y + 0.8, stone, { top: stoneTop });
      m.windows(x + 0.1, y + 0.16, x + 0.9, y + 0.8, 0.12, 0.5, { cols: 6, rows: 2, glass: GLASS, frame: TRIM, lit: WARM });
      m.box(x + 0.22, 0, y + 0.8, x + 0.78, 0.06, y + 0.95, 0xeee6d8);
      m.box(x + 0.24, 0.6, y + 0.78, x + 0.76, 0.68, y + 0.92, 0xeee6d8);
      m.roof(x + 0.22, y + 0.76, x + 0.78, y + 0.92, 0.68, 0.8, 0xe8dcc8);
      m.box(x + 0.36, 0.7, y + 0.36, x + 0.64, 0.82, y + 0.64, stone, { top: stoneTop });
      m.prism(x + 0.5, y + 0.5, 0.2, 10, 0.82, 0.92, dome);
      m.cone(x + 0.5, y + 0.5, 0.2, 10, 0.92, 1.08, dome);
      for (const cx of [0.27, 0.4, 0.6, 0.73]) m.box(x + cx - 0.03, 0.06, y + 0.82, x + cx + 0.03, 0.6, y + 0.88, WHITE);
      lamp(m, x + 0.07, y + 0.93);
      break;
    }
    default:
      break;
  }
  // Cornice rim under the roof: the outer ring only, so the roof stays visible.
  m.box(x + bx0 - 0.02, top, y + bz0 - 0.02, x + bx1 + 0.02, top + 0.04, y + bz0, TRIM);
  m.box(x + bx0 - 0.02, top, y + bz1, x + bx1 + 0.02, top + 0.04, y + bz1 + 0.02, TRIM);
  m.box(x + bx0 - 0.02, top, y + bz0, x + bx0, top + 0.04, y + bz1, TRIM);
  m.box(x + bx1, top, y + bz0, x + bx1 + 0.02, top + 0.04, y + bz1, TRIM);
  facadeDetail(m, x, y, body);
}

// Corner pillars, a rooftop unit, and an antenna on the taller buildings.
function facadeDetail(m, x, y, body) {
  const [bx0, bz0, bx1, bz1, top] = body;
  for (const [px, pz] of [[bx0, bz0], [bx1, bz0], [bx0, bz1], [bx1, bz1]]) {
    m.box(x + px - 0.03, 0.06, y + pz - 0.03, x + px + 0.03, top, y + pz + 0.03, 0xd7dce1);
  }
  const unitX = bx0 + (bx1 - bx0) * (0.2 + (((x * 3 + y * 5) % 4) * 0.12));
  const unitZ = bz0 + (bz1 - bz0) * 0.3;
  m.box(x + unitX, top + 0.04, y + unitZ, x + unitX + 0.16, top + 0.13, y + unitZ + 0.13, DARK_GREY);
  if (top >= 0.9) {
    const ax = x + (bx0 + bx1) / 2;
    const az = y + (bz0 + bz1) / 2;
    m.box(ax - 0.015, top + 0.04, az - 0.015, ax + 0.015, top + 0.4, az + 0.015, GREY);
    m.box(ax - 0.03, top + 0.4, az - 0.03, ax + 0.03, top + 0.43, az + 0.03, RED);
  }
}

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
      if (isBuildingCell(cell)) {
        const turns = frontTurns(grid, x, y) ?? 0;
        const turned = new MeshBuilder({ brightness, transform: turnTransform(x + 0.5, y + 0.5, turns) });
        building(turned, x, y, cell.zone);
        mergeInto(m, turned);
      }
      streetObjects(m, grid, x, y, cell);
    }
  }
  return m.arrays();
}

function mergeInto(target, source) {
  target.positions.push(...source.positions);
  target.colors.push(...source.colors);
}

// The vending machine on its building's front corner, turned to face the road.
export function buildMachine(machine, grid) {
  const zone = ZONES[machine.zone];
  const anchor = machineAnchor(grid, machine.x, machine.y);
  // The model is built about 2 units tall, then scaled to the tile and turned to face the road.
  const turn = (4 - anchor.turns) % 4;
  const transform = (v, isDirection) => {
    const x = v[0] * MACHINE_SCALE;
    const y = v[1] * MACHINE_SCALE;
    const z = v[2] * MACHINE_SCALE;
    const [rx, rz] = turnPoint(x, z, turn);
    if (isDirection) return [rx, y, rz];
    return [anchor.x + rx, y, anchor.z + rz];
  };
  const m = new MeshBuilder({ transform });
  const accent = zone.color;
  const sign = lerpHex(accent, 0xffffff, 0.25);
  const cabinetTop = lerpHex(accent, 0x000000, 0.2);
  const cabinetSide = lerpHex(accent, 0x000000, 0.12);
  const cash = machine.cash > 0 ? 0x43a047 : 0x9e9e9e;
  m.box(-0.52, 0, -0.4, 0.52, 0.12, 0.4, MACHINE_BASE);
  m.box(-0.5, 0.12, -0.38, 0.5, 1.85, 0.38, accent, { top: cabinetTop });
  m.box(-0.5, 1.85, -0.38, 0.5, 2.0, 0.38, sign);
  m.box(-0.46, 1.8, 0.38, 0.46, 1.84, 0.41, LAMP_LIGHT);
  m.box(0.5, 0.2, -0.3, 0.53, 1.2, 0.3, cabinetSide);
  m.box(-0.4, 0.46, 0.38, 0.38, 1.7, 0.4, STEEL);
  m.box(-0.36, 0.5, 0.38, 0.34, 1.65, 0.42, 0x203040);
  // Twelve product slots in a 4 by 3 grid, coloured by product and dimmed when empty.
  PRODUCT_IDS.forEach((product, i) => {
    const row = Math.floor(i / 3);
    const col = i % 3;
    const x0 = -0.32 + col * 0.22;
    const y1 = 1.6 - row * 0.27;
    const stock = machine.stock[product] ?? 0;
    const colour = stock > 0 ? slotColour(product) : lerpHex(slotColour(product), DARK, 0.7);
    m.box(x0, y1 - 0.22, 0.4, x0 + 0.18, y1, 0.45, colour);
    m.box(x0 + 0.02, y1 - 0.04, 0.44, x0 + 0.16, y1, 0.47, lerpHex(colour, 0xffffff, 0.2));
  });
  m.box(0.37, 0.5, 0.38, 0.46, 1.3, 0.42, DARK);
  m.box(0.39, 1.36, 0.41, 0.44, 1.5, 0.44, cash);
  m.box(0.39, 0.6, 0.41, 0.44, 0.7, 0.44, 0xcfd8dc);
  m.box(0.39, 0.78, 0.41, 0.44, 0.84, 0.45, 0x12161d);
  return m.arrays();
}

const SLOT_COLOURS = {
  soda: 0xe53935,
  chips: 0xfdd835,
  proteinBar: 0x8d6e63,
  coffee: 0x5d4037,
  techGadget: 0x42a5f5,
  sandwich: 0xffb74d,
};

function slotColour(product) {
  return SLOT_COLOURS[product] ?? GREY;
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
