// The low-poly city, drawn the way the original game drew it: asphalt with lane markings and
// kerbs, grass, pavements, buildings with their own shapes for each zone, street lamps and trees,
// vending machines on the front corner of their building, and the markers over buildings.
import { MeshBuilder, turnPoint, turnTransform } from './lowpoly.js';
import { ZONES, PRODUCTS, PRODUCT_IDS } from './products.js';
import { CONFIG } from './config.js';
import { districtOf } from './world.js';

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

// A park tile: a lawn with a path, and a bench or a tree. Some have a pond. Nothing to buy here.
function park(m, x, y) {
  m.flat(x, y, x + 1, y + 1, 0, 0x8bd17c);
  m.flat(x + 0.44, y, x + 0.56, y + 1, 0.003, 0xd7ccc8);
  const v = cellNoise(x, y);
  if (v < 0.5) {
    bench(m, x, y);
  } else {
    m.box(x + 0.2, 0, y + 0.7, x + 0.24, 0.22, y + 0.74, TRUNK);
    m.cone(x + 0.22, y + 0.72, 0.12, 6, 0.2, 0.6, FOLIAGE);
  }
  if (v > 0.8) m.flat(x + 0.62, y + 0.14, x + 0.9, y + 0.36, 0.004, 0x4fc3f7);
}

// A small bench beside the path: a brown seat and back on two legs.
function bench(m, x, y) {
  m.box(x + 0.6, 0.12, y + 0.28, x + 0.92, 0.17, y + 0.4, BROWN);
  m.box(x + 0.6, 0.17, y + 0.26, x + 0.92, 0.23, y + 0.29, BROWN);
  m.box(x + 0.62, 0, y + 0.3, x + 0.66, 0.12, y + 0.36, DARK_GREY);
  m.box(x + 0.86, 0, y + 0.3, x + 0.9, 0.12, y + 0.36, DARK_GREY);
}

// A small parking lot: grey asphalt, a divider between two bays, and a small car in each bay.
function lot(m, x, y) {
  m.flat(x, y, x + 1, y + 1, 0.001, 0x6b7280);
  m.flat(x + 0.49, y + 0.08, x + 0.51, y + 0.92, 0.004, LANE);
  car(m, x + 0.05, y, carColour(x, y, 0));
  car(m, x + 0.55, y, carColour(x, y, 1));
}

const CAR_COLOURS = [0xe53935, 0x1e88e5, 0xfdd835, 0xf5f5f5, 0x43a047, 0x8e24aa];

function carColour(x, y, bay) {
  return CAR_COLOURS[Math.floor(cellNoise(x + bay * 7, y) * CAR_COLOURS.length)];
}

// A small car nose to the road, in a bay of width 0.4 starting at bx: a low body, a cabin with
// glass, four wheels, and two headlights at the front.
function car(m, bx, y, colour) {
  m.box(bx + 0.04, 0.04, y + 0.2, bx + 0.36, 0.15, y + 0.8, colour, { top: colour });
  m.box(bx + 0.09, 0.15, y + 0.3, bx + 0.31, 0.25, y + 0.7, colour, { top: colour });
  m.box(bx + 0.085, 0.17, y + 0.32, bx + 0.315, 0.23, y + 0.68, GLASS);
  for (const wx of [bx + 0.02, bx + 0.31]) {
    for (const wz of [y + 0.24, y + 0.7]) m.box(wx, 0, wz, wx + 0.07, 0.08, wz + 0.06, DARK);
  }
  for (const hx of [bx + 0.07, bx + 0.27]) m.box(hx, 0.08, y + 0.79, hx + 0.06, 0.12, y + 0.81, 0xfff59d);
}

// A gas station tile: a concrete forecourt, a red canopy on four posts, and two fuel pumps.
function gasStation(m, x, y) {
  m.flat(x, y, x + 1, y + 1, 0.001, 0xcfd8dc);
  for (const [px, pz] of [[0.1, 0.1], [0.9, 0.1], [0.1, 0.9], [0.9, 0.9]]) {
    m.box(x + px - 0.03, 0, y + pz - 0.03, x + px + 0.03, 0.5, y + pz + 0.03, STEEL);
  }
  m.box(x + 0.02, 0.5, y + 0.02, x + 0.98, 0.56, y + 0.98, RED, { top: 0xb71c1c });
  for (const px of [0.3, 0.7]) {
    m.box(x + px - 0.08, 0, y + 0.45, x + px + 0.08, 0.32, y + 0.6, 0x1e88e5);
    m.box(x + px - 0.05, 0.32, y + 0.47, x + px + 0.05, 0.36, y + 0.58, DARK);
  }
}

// A gabled roof: two sloping sides meeting at a ridge along x, with a triangle at each end.


// A house: a cottage with a gabled roof, a porch, and windows with frames, shutters and flower
// boxes. Walls, roof, height, chimney, hedges and garden vary from house to house. Only for looking.

function groundTile(m, grid, x, y, cell) {
  if (cell.type === 'road') {
    roadTile(m, grid, x, y);
    districtLine(m, x, y);
    return;
  }
  if (cell.type === 'park') {
    park(m, x, y);
    return;
  }
  if (cell.type === 'lot') {
    lot(m, x, y);
    return;
  }
  if (cell.type === 'gas') {
    gasStation(m, x, y);
    return;
  }
  const grass = lerpHex(GRASS_A, GRASS_B, cellNoise(x, y));
  m.flat(x, y, x + 1, y + 1, 0, grass);
  if (cellNoise(x * 7 + 1, y * 11 + 3) > 0.72) districtDecor(m, x, y);
}

// An amber line painted across a road where one district meets the next.
function districtLine(m, x, y) {
  if (x === CONFIG.districtSplit) m.flat(x, y, x + 0.07, y + 1, 0.006, 0xffb300);
  if (y === CONFIG.districtSplit) m.flat(x, y, x + 1, y + 0.07, 0.006, 0xffb300);
}

// A feature on some empty tiles that says which district it is: a fountain downtown, a community
// garden on the east side, a tank and shed in the industrial south, containers at the harbor.
function districtDecor(m, x, y) {
  switch (districtOf(x, y)) {
    case 0:
      m.box(x + 0.2, 0, y + 0.2, x + 0.8, 0.02, y + 0.8, 0xe0e0e0);
      m.prism(x + 0.5, y + 0.5, 0.22, 12, 0.02, 0.1, 0xb0bec5, { top: 0xb0bec5 });
      m.prism(x + 0.5, y + 0.5, 0.18, 12, 0.1, 0.11, 0x4fc3f7);
      m.box(x + 0.48, 0.11, y + 0.48, x + 0.52, 0.24, y + 0.52, 0xb0bec5);
      break;
    case 1:
      for (const r of [0.3, 0.5, 0.7]) {
        m.box(x + 0.2, 0, y + r - 0.05, x + 0.8, 0.04, y + r + 0.05, BROWN);
        for (let k = 0; k < 4; k++) m.box(x + 0.25 + k * 0.15, 0.04, y + r - 0.03, x + 0.3 + k * 0.15, 0.11, y + r + 0.03, k % 2 ? RED : BUSH);
      }
      break;
    case 2:
      m.prism(x + 0.35, y + 0.4, 0.18, 10, 0, 0.4, STEEL, { top: GREY });
      m.box(x + 0.6, 0, y + 0.55, x + 0.9, 0.18, y + 0.85, 0x78909c, { top: 0x546e7a });
      m.box(x + 0.7, 0.18, y + 0.6, x + 0.78, 0.5, y + 0.68, BROWN);
      break;
    default:
      m.box(x + 0.2, 0, y + 0.3, x + 0.8, 0.14, y + 0.5, RED);
      m.box(x + 0.2, 0, y + 0.55, x + 0.8, 0.14, y + 0.75, 0x1e88e5);
      m.box(x + 0.3, 0.14, y + 0.4, x + 0.9, 0.28, y + 0.6, 0xffb300);
      break;
  }
}

// Lamp post on a corner of the tile.
function lamp(m, px, pz) {
  m.box(px - 0.02, 0, pz - 0.02, px + 0.02, 0.42, pz + 0.02, DARK_GREY);
  m.box(px - 0.05, 0.42, pz - 0.05, px + 0.05, 0.48, pz + 0.05, LAMP_LIGHT);
}

// A fire hydrant.
function hydrant(m, px, pz) {
  m.box(px - 0.035, 0, pz - 0.035, px + 0.035, 0.09, pz + 0.035, RED);
  m.box(px - 0.045, 0.09, pz - 0.045, px + 0.045, 0.115, pz + 0.045, 0xb71c1c);
  m.box(px - 0.06, 0.05, pz - 0.015, px + 0.06, 0.07, pz + 0.015, RED);
}

// A stop sign on a pole.
function stopSign(m, px, pz) {
  m.box(px - 0.01, 0, pz - 0.01, px + 0.01, 0.34, pz + 0.01, GREY);
  m.prism(px, pz, 0.06, 8, 0.34, 0.37, RED);
  m.prism(px, pz, 0.04, 8, 0.37, 0.375, WHITE);
}

// A bus stop: a small shelter with a bench and a sign.
function busStop(m, x, y) {
  m.box(x + 0.3, 0, y + 0.06, x + 0.33, 0.28, y + 0.09, GREY);
  m.box(x + 0.7, 0, y + 0.06, x + 0.73, 0.28, y + 0.09, GREY);
  m.box(x + 0.28, 0.28, y + 0.04, x + 0.75, 0.32, y + 0.16, 0x1e88e5);
  m.box(x + 0.34, 0.08, y + 0.08, x + 0.69, 0.1, y + 0.13, BROWN);
  m.box(x + 0.8, 0, y + 0.1, x + 0.82, 0.4, y + 0.12, GREY);
  m.box(x + 0.77, 0.4, y + 0.09, x + 0.85, 0.46, y + 0.13, 0x1e88e5);
}

// Lamps and street trees on the pavement of tiles beside a road.
function streetObjects(m, grid, x, y, cell) {
  if (cell.type === 'road') return;
  const onRoad = isRoad(grid, x, y - 1) || isRoad(grid, x, y + 1) || isRoad(grid, x - 1, y) || isRoad(grid, x + 1, y);
  if (!onRoad) return;
  // Now and then a different piece of street furniture takes the place of a lamp or a tree.
  const prop = cellNoise(x * 3 + 4, y * 5 + 1);
  if (prop > 0.9) {
    busStop(m, x, y);
  } else if (prop > 0.8) {
    hydrant(m, x + 0.9, y + 0.1);
  } else if (prop > 0.72) {
    stopSign(m, x + 0.9, y + 0.1);
  } else if ((x + y) % 2 === 0) {
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
// Each district has its own office colours and an overall tint, so the parts of the map look different.
const OFFICE_PALETTES = [
  [0x8fb8de, 0xb0bec5, 0x9fd3c7, 0xc9b6e4],
  [0xe0b79a, 0xd4a373, 0xc9a38c, 0xdcc4a8],
  [0x9e9e9e, 0x8d8d86, 0x78909c, 0xa1a39a],
  [0x4db6ac, 0x4f83a8, 0x5c7caa, 0x6fb5c9],
];
const DISTRICT_TINTS = [0xbbdefb, 0xffe0b2, 0xd7ccc8, 0xb2ebf2];

// Leans every colour added since `start` toward a tint, a little: shaded colours are stored as
// red, green, blue floats, so the tint is a multiplier.
function tintFrom(m, start, hex, amount) {
  const channels = [(hex >> 16) & 255, (hex >> 8) & 255, hex & 255];
  const top = Math.max(...channels);
  const mult = channels.map((c) => 1 - amount + amount * (c / top));
  for (let i = start; i < m.colors.length; i++) m.colors[i] = Math.min(1, m.colors[i] * mult[i % 3]);
}

const AWNINGS = [0xe4572e, 0x2e7d32, 0x1565c0, 0xf9a825];

function variant(palette, x, y) {
  return palette[(x * 7 + y * 13 + x * y) % palette.length];
}

// Three designs for each type of shop front, picked from the tile's position, so a street of shops
// does not repeat. Every design keeps the type's footprint and height (see BODIES), so the cornice,
// the machine and the purchase marker still sit right; the walls, roof, entrance and extras differ.
const SHOP_WALLS = [0xf2c14e, 0xf3e0c7, 0xcfd8dc];
const OFFICE_WINGS = [0x3d5a80, 0x37474f, 0x2e7d6e];

function shop(m, x, y, v) {
  if (v === 0) {
    // A corner shop with a striped awning.
    m.box(x + 0.1, 0, y + 0.12, x + 0.9, 0.55, y + 0.88, SHOP_WALLS[0], { top: 0x8d6e63 });
    m.windows(x + 0.1, y + 0.12, x + 0.9, y + 0.88, 0.12, 0.42, { cols: 3, rows: 1, glass: GLASS, frame: TRIM, lit: WARM });
    m.box(x + 0.44, 0, y + 0.88, x + 0.56, 0.34, y + 0.93, BROWN);
    m.box(x + 0.06, 0.42, y + 0.84, x + 0.94, 0.52, y + 0.94, 0xe4572e);
    for (const sx of [0.16, 0.44, 0.72]) m.box(x + sx, 0.42, y + 0.94, x + sx + 0.1, 0.52, y + 0.955, WHITE);
    m.box(x + 0.3, 0.55, y + 0.84, x + 0.7, 0.66, y + 0.9, 0xfff176);
    m.box(x + 0.7, 0.55, y + 0.3, x + 0.84, 0.63, y + 0.46, DARK_GREY);
  } else if (v === 1) {
    // A café: green awning, a round sign, a table and a planter out front.
    m.box(x + 0.1, 0, y + 0.12, x + 0.9, 0.55, y + 0.88, SHOP_WALLS[1], { top: 0xa1887f });
    m.windows(x + 0.1, y + 0.12, x + 0.9, y + 0.88, 0.12, 0.42, { cols: 3, rows: 1, glass: GLASS, frame: TRIM, lit: WARM });
    m.box(x + 0.44, 0, y + 0.88, x + 0.56, 0.34, y + 0.93, BROWN);
    m.box(x + 0.06, 0.42, y + 0.84, x + 0.94, 0.5, y + 0.94, 0x2e7d32);
    for (const sx of [0.14, 0.38, 0.62, 0.84]) m.box(x + sx, 0.42, y + 0.94, x + sx + 0.07, 0.5, y + 0.955, WHITE);
    m.prism(x + 0.5, y + 0.8, 0.1, 10, 0.55, 0.6, 0xfff176);
    m.prism(x + 0.5, y + 0.8, 0.07, 10, 0.6, 0.64, 0xd84315);
    m.box(x + 0.16, 0, y + 0.94, x + 0.3, 0.1, y + 1.0, 0x8d6e63, { top: 0xffe0b2 });
    m.box(x + 0.34, 0, y + 0.95, x + 0.46, 0.1, y + 1.0, BUSH);
    m.box(x + 0.7, 0.55, y + 0.3, x + 0.84, 0.63, y + 0.46, DARK_GREY);
  } else {
    // A boutique: a big glass front, a thin blue canopy, and a neon sign on the roof.
    m.box(x + 0.1, 0, y + 0.12, x + 0.9, 0.55, y + 0.88, SHOP_WALLS[2], { top: 0x607d8b });
    m.windows(x + 0.1, y + 0.12, x + 0.9, y + 0.88, 0.12, 0.42, { cols: 2, rows: 1, glass: GLASS, frame: TRIM, lit: WARM });
    m.box(x + 0.2, 0.06, y + 0.88, x + 0.8, 0.4, y + 0.9, GLASS);
    m.box(x + 0.44, 0, y + 0.9, x + 0.56, 0.3, y + 0.93, GLASS_DARK);
    m.box(x + 0.12, 0.44, y + 0.86, x + 0.88, 0.5, y + 0.95, 0x1565c0);
    m.box(x + 0.3, 0.55, y + 0.5, x + 0.7, 0.68, y + 0.54, 0xff4081);
    m.box(x + 0.34, 0.58, y + 0.54, x + 0.66, 0.64, y + 0.56, 0xfff59d);
    m.box(x + 0.16, 0.55, y + 0.25, x + 0.3, 0.63, y + 0.4, DARK_GREY);
  }
  m.box(x + 0.12, 0, y + 0.9, x + 0.2, 0.1, y + 0.98, BUSH);
  lamp(m, x + 0.93, y + 0.93);
}

function gym(m, x, y, v) {
  if (v === 0) {
    // Brick, with a red entrance and two dumbbell vents.
    m.box(x + 0.06, 0, y + 0.12, x + 0.94, 0.5, y + 0.9, BRICK, { top: 0x6b7280 });
    m.windows(x + 0.06, y + 0.12, x + 0.94, y + 0.9, 0.12, 0.34, { cols: 5, rows: 1, glass: GLASS, frame: TRIM, lit: WARM });
    m.box(x + 0.3, 0, y + 0.62, x + 0.7, 0.86, y + 0.92, 0x37474f, { top: 0x263238 });
    m.box(x + 0.36, 0.2, y + 0.92, x + 0.64, 0.7, y + 0.94, GLASS);
    m.box(x + 0.3, 0.72, y + 0.6, x + 0.7, 0.84, y + 0.94, RED);
    m.box(x + 0.4, 0.76, y + 0.94, x + 0.6, 0.8, y + 0.96, WHITE);
    m.prism(x + 0.25, y + 0.35, 0.1, 6, 0.5, 0.62, 0x90a4ae);
    m.prism(x + 0.7, y + 0.35, 0.1, 6, 0.5, 0.62, 0x90a4ae);
  } else if (v === 1) {
    // Modern: grey concrete, a yellow band, a glass wall and a dumbbell on the roof.
    m.box(x + 0.08, 0, y + 0.1, x + 0.92, 0.7, y + 0.9, 0x90a4ae, { top: 0x455a64 });
    m.windows(x + 0.08, y + 0.1, x + 0.92, y + 0.9, 0.38, 0.62, { cols: 4, rows: 1, glass: GLASS, frame: TRIM, lit: WARM });
    m.box(x + 0.06, 0.3, y + 0.88, x + 0.94, 0.36, y + 0.92, 0xffc107);
    m.box(x + 0.34, 0, y + 0.9, x + 0.66, 0.3, y + 0.93, GLASS_DARK);
    m.box(x + 0.34, 0.74, y + 0.46, x + 0.66, 0.78, y + 0.5, DARK_GREY);
    m.prism(x + 0.3, y + 0.48, 0.06, 6, 0.7, 0.86, 0x37474f);
    m.prism(x + 0.7, y + 0.48, 0.06, 6, 0.7, 0.86, 0x37474f);
  } else {
    // A boxing gym: navy walls, a red roll-up door and a white sign.
    m.box(x + 0.08, 0, y + 0.1, x + 0.92, 0.7, y + 0.9, 0x1e3a5f, { top: 0x14243b });
    m.windows(x + 0.08, y + 0.1, x + 0.92, y + 0.9, 0.46, 0.62, { cols: 5, rows: 1, glass: GLASS, frame: TRIM, lit: WARM });
    m.box(x + 0.26, 0, y + 0.9, x + 0.74, 0.34, y + 0.935, RED);
    for (const gy of [0.08, 0.16, 0.24]) m.box(x + 0.26, gy, y + 0.935, x + 0.74, gy + 0.02, y + 0.945, 0xb71c1c);
    m.box(x + 0.22, 0.38, y + 0.9, x + 0.78, 0.5, y + 0.94, WHITE);
    m.box(x + 0.3, 0.41, y + 0.94, x + 0.7, 0.47, y + 0.95, RED);
  }
  lamp(m, x + 0.93, y + 0.93);
}

function office(m, x, y, v) {
  const wall = variant(OFFICE_PALETTES[districtOf(x, y)], x, y);
  m.box(x + 0.2, 0, y + 0.2, x + 0.8, 1.5, y + 0.8, wall, { top: 0x3d5a80 });
  m.windows(x + 0.2, y + 0.2, x + 0.8, y + 0.8, 0.12, 1.42, { cols: 3, rows: 6, glass: GLASS, frame: TRIM, lit: WARM });
  if (v === 0) {
    // A plain tower with a plant room and an aerial.
    m.box(x + 0.3, 1.5, y + 0.3, x + 0.7, 1.62, y + 0.7, 0x3d5a80);
    m.box(x + 0.32, 1.62, y + 0.32, x + 0.44, 1.7, y + 0.44, GREY);
    m.box(x + 0.56, 1.62, y + 0.56, x + 0.6, 1.95, y + 0.6, GREY);
  } else if (v === 1) {
    // A stepped tower: a second, narrower tier with its own windows and a dark band between them.
    const wing = OFFICE_WINGS[(x + y) % OFFICE_WINGS.length];
    m.box(x + 0.18, 1.5, y + 0.18, x + 0.82, 1.56, y + 0.82, 0x263238);
    m.box(x + 0.3, 1.56, y + 0.3, x + 0.7, 1.86, y + 0.7, wing, { top: 0x263238 });
    m.windows(x + 0.3, y + 0.3, x + 0.7, y + 0.7, 1.6, 1.82, { cols: 2, rows: 2, glass: GLASS, frame: TRIM, lit: WARM });
    m.box(x + 0.49, 1.86, y + 0.49, x + 0.51, 2.1, y + 0.51, GREY);
  } else {
    // A roof garden: a green deck with two small trees, behind a low glass rail.
    m.box(x + 0.22, 1.5, y + 0.22, x + 0.78, 1.56, y + 0.78, 0x6d8f5a);
    m.box(x + 0.22, 1.56, y + 0.22, x + 0.78, 1.6, y + 0.24, GLASS);
    m.box(x + 0.22, 1.56, y + 0.76, x + 0.78, 1.6, y + 0.78, GLASS);
    for (const [tx, tz] of [[0.36, 0.4], [0.6, 0.58]]) {
      m.box(x + tx - 0.015, 1.56, y + tz - 0.015, x + tx + 0.015, 1.64, y + tz + 0.015, TRUNK);
      m.cone(x + tx, y + tz, 0.08, 7, 1.62, 1.84, FOLIAGE);
    }
    m.box(x + 0.62, 1.56, y + 0.3, x + 0.74, 1.66, y + 0.42, GREY);
  }
  m.box(x + 0.42, 0, y + 0.8, x + 0.58, 0.24, y + 0.86, GLASS_DARK);
  m.box(x + 0.36, 0.24, y + 0.78, x + 0.64, 0.28, y + 0.9, 0x1f2a44);
  lamp(m, x + 0.93, y + 0.93);
}

function school(m, x, y, v) {
  if (v === 0) {
    // A cream school with a clock tower and a flag.
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
  } else if (v === 1) {
    // A red-brick school with a bell tower in the middle and a blue spire.
    m.box(x + 0.1, 0, y + 0.12, x + 0.9, 0.5, y + 0.88, 0xc0674a, { top: 0x8d4b3a });
    m.windows(x + 0.1, y + 0.12, x + 0.9, y + 0.88, 0.1, 0.4, { cols: 6, rows: 1, glass: GLASS, frame: WHITE, lit: WARM });
    m.box(x + 0.4, 0.5, y + 0.4, x + 0.6, 0.8, y + 0.6, 0xc0674a, { top: 0x8d4b3a });
    m.box(x + 0.44, 0.6, y + 0.6, x + 0.56, 0.74, y + 0.62, GLASS);
    m.roof(x + 0.38, y + 0.38, x + 0.62, y + 0.62, 0.8, 1.04, 0x3949ab);
    m.box(x + 0.44, 0, y + 0.88, x + 0.56, 0.28, y + 0.93, BROWN);
    m.box(x + 0.4, 0.3, y + 0.88, x + 0.6, 0.34, y + 0.94, WHITE);
    m.box(x + 0.82, 0.5, y + 0.2, x + 0.84, 0.86, y + 0.22, GREY);
    m.box(x + 0.7, 0.76, y + 0.2, x + 0.82, 0.84, y + 0.22, 0x1565c0);
  } else {
    // A modern school: pale walls, a green roof, and blocks of red and blue on the front.
    m.box(x + 0.1, 0, y + 0.12, x + 0.9, 0.5, y + 0.88, 0xfff3c4, { top: 0x4caf50 });
    m.windows(x + 0.1, y + 0.12, x + 0.9, y + 0.88, 0.14, 0.38, { cols: 5, rows: 1, glass: GLASS, frame: TRIM, lit: WARM });
    m.box(x + 0.1, 0, y + 0.88, x + 0.34, 0.46, y + 0.93, RED);
    m.box(x + 0.66, 0, y + 0.88, x + 0.9, 0.46, y + 0.93, 0x1e88e5);
    m.box(x + 0.44, 0, y + 0.88, x + 0.56, 0.28, y + 0.94, BROWN);
    m.box(x + 0.7, 0.5, y + 0.3, x + 0.8, 0.54, y + 0.36, 0xffc107);
    m.prism(x + 0.3, y + 0.5, 0.07, 8, 0.5, 0.62, 0xffc107);
  }
  lamp(m, x + 0.07, y + 0.93);
}

function subway(m, x, y, v) {
  m.box(x + 0.1, 0, y + 0.1, x + 0.9, 0.04, y + 0.9, 0xbdbdb5);
  if (v === 0) {
    // A stair house with a round sign on a pole.
    m.box(x + 0.32, 0, y + 0.3, x + 0.68, 0.3, y + 0.7, 0x2e5a80, { top: 0x1f3f5c });
    m.box(x + 0.36, 0.04, y + 0.66, x + 0.64, 0.1, y + 0.72, 0x263238);
    m.box(x + 0.4, 0.1, y + 0.7, x + 0.6, 0.16, y + 0.76, 0x263238);
    m.box(x + 0.28, 0.3, y + 0.26, x + 0.72, 0.34, y + 0.74, GREY, { top: 0x9aa5b1 });
    m.box(x + 0.7, 0, y + 0.5, x + 0.74, 1.05, y + 0.54, DARK_GREY);
    m.prism(x + 0.72, y + 0.52, 0.14, 14, 1.0, 1.12, RED);
    m.box(x + 0.56, 1.04, y + 0.5, x + 0.88, 1.08, y + 0.56, 0x1565c0);
  } else if (v === 1) {
    // A green stair house under a glass canopy.
    m.box(x + 0.3, 0, y + 0.3, x + 0.7, 0.3, y + 0.7, 0x2e7d32, { top: 0x1b5e20 });
    m.box(x + 0.34, 0.04, y + 0.66, x + 0.66, 0.1, y + 0.72, 0x263238);
    m.box(x + 0.26, 0.3, y + 0.24, x + 0.74, 0.34, y + 0.76, GLASS, { top: GLASS });
    for (const [cx, cz] of [[0.27, 0.25], [0.73, 0.25], [0.27, 0.75], [0.73, 0.75]]) m.box(x + cx - 0.015, 0.04, y + cz - 0.015, x + cx + 0.015, 0.3, y + cz + 0.015, DARK_GREY);
    m.box(x + 0.16, 0, y + 0.42, x + 0.2, 0.9, y + 0.46, DARK_GREY);
    m.box(x + 0.12, 0.84, y + 0.34, x + 0.24, 0.98, y + 0.54, 0x2e7d32);
    m.box(x + 0.15, 0.88, y + 0.52, x + 0.21, 0.94, y + 0.55, WHITE);
  } else {
    // A kiosk with a red canopy and a sign board.
    m.box(x + 0.3, 0, y + 0.3, x + 0.7, 0.3, y + 0.7, 0xeceff1, { top: 0xcfd8dc });
    m.box(x + 0.36, 0.04, y + 0.66, x + 0.64, 0.1, y + 0.72, 0x263238);
    m.box(x + 0.24, 0.3, y + 0.24, x + 0.76, 0.36, y + 0.76, RED);
    m.box(x + 0.3, 0.36, y + 0.46, x + 0.7, 0.62, y + 0.5, 0x1565c0);
    m.box(x + 0.36, 0.42, y + 0.5, x + 0.64, 0.56, y + 0.51, WHITE);
  }
  lamp(m, x + 0.07, y + 0.93);
}

function hospital(m, x, y, v) {
  m.box(x + 0.1, 0, y + 0.1, x + 0.9, 0.9, y + 0.9, WHITE, { top: 0xe3e8ef });
  m.windows(x + 0.1, y + 0.1, x + 0.9, y + 0.9, 0.3, 0.86, { cols: 4, rows: 2, glass: GLASS, frame: TRIM, lit: WARM });
  m.box(x + 0.34, 0.24, y + 0.9, x + 0.66, 0.3, y + 0.99, 0x26a69a);
  m.box(x + 0.42, 0, y + 0.9, x + 0.58, 0.24, y + 0.94, GLASS_DARK);
  if (v === 0) {
    // A red cross on the roof.
    m.box(x + 0.42, 0.9, y + 0.28, x + 0.58, 0.94, y + 0.72, RED);
    m.box(x + 0.28, 0.9, y + 0.42, x + 0.72, 0.94, y + 0.58, RED);
  } else if (v === 1) {
    // A red band round the middle and a rooftop water tank.
    m.box(x + 0.08, 0.24, y + 0.08, x + 0.92, 0.3, y + 0.12, RED);
    m.box(x + 0.08, 0.24, y + 0.88, x + 0.92, 0.3, y + 0.92, RED);
    m.prism(x + 0.3, y + 0.35, 0.1, 10, 0.9, 1.08, 0xb0bec5);
    m.cone(x + 0.3, y + 0.35, 0.1, 10, 1.08, 1.16, 0x78909c);
    m.box(x + 0.5, 0.9, y + 0.5, x + 0.8, 0.96, y + 0.8, 0xe3e8ef);
  } else {
    // A helipad on the roof: a round yellow pad with an H.
    m.prism(x + 0.5, y + 0.5, 0.3, 16, 0.9, 0.93, 0x546e7a);
    m.prism(x + 0.5, y + 0.5, 0.25, 16, 0.93, 0.945, 0xffc107);
    m.box(x + 0.4, 0.945, y + 0.4, x + 0.44, 0.955, y + 0.6, WHITE);
    m.box(x + 0.56, 0.945, y + 0.4, x + 0.6, 0.955, y + 0.6, WHITE);
    m.box(x + 0.44, 0.945, y + 0.48, x + 0.56, 0.955, y + 0.52, WHITE);
  }
  lamp(m, x + 0.93, y + 0.93);
}

function university(m, x, y, v) {
  const stone = [0xd8c3a5, 0xc9d3dd, 0xb9d6d0][v];
  const stoneTop = [0xb89f82, 0x9fb0bd, 0x8fbab2][v];
  m.box(x + 0.1, 0, y + 0.16, x + 0.9, 0.7, y + 0.8, stone, { top: stoneTop });
  m.windows(x + 0.1, y + 0.16, x + 0.9, y + 0.8, 0.12, 0.5, { cols: 6, rows: 2, glass: GLASS, frame: TRIM, lit: WARM });
  m.box(x + 0.22, 0, y + 0.8, x + 0.78, 0.06, y + 0.95, 0xeee6d8);
  m.box(x + 0.24, 0.6, y + 0.78, x + 0.76, 0.68, y + 0.92, 0xeee6d8);
  m.roof(x + 0.22, y + 0.76, x + 0.78, y + 0.92, 0.68, 0.8, 0xe8dcc8);
  for (const cx of [0.27, 0.4, 0.6, 0.73]) m.box(x + cx - 0.03, 0.06, y + 0.82, x + cx + 0.03, 0.6, y + 0.88, WHITE);
  if (v === 0) {
    // A classic hall with a blue dome.
    m.box(x + 0.36, 0.7, y + 0.36, x + 0.64, 0.82, y + 0.64, stone, { top: stoneTop });
    m.prism(x + 0.5, y + 0.5, 0.2, 10, 0.82, 0.92, 0x3f51b5);
    m.cone(x + 0.5, y + 0.5, 0.2, 10, 0.92, 1.08, 0x3f51b5);
  } else if (v === 1) {
    // A library with a clock tower.
    m.box(x + 0.4, 0.7, y + 0.4, x + 0.6, 1.0, y + 0.6, stone, { top: stoneTop });
    m.prism(x + 0.5, y + 0.6, 0.07, 12, 0.78, 0.8, WHITE);
    m.roof(x + 0.38, y + 0.38, x + 0.62, y + 0.62, 1.0, 1.2, 0x8d6e63);
    m.box(x + 0.48, 1.2, y + 0.48, x + 0.52, 1.3, y + 0.52, GREY);
  } else {
    // A science hall with a glass dome and a satellite dish.
    m.box(x + 0.34, 0.7, y + 0.34, x + 0.66, 0.78, y + 0.66, stone, { top: stoneTop });
    m.prism(x + 0.5, y + 0.5, 0.2, 12, 0.78, 0.9, 0xb3e5fc);
    m.cone(x + 0.5, y + 0.5, 0.2, 12, 0.9, 1.0, 0x81d4fa);
    m.box(x + 0.7, 0.7, y + 0.3, x + 0.84, 0.76, y + 0.44, DARK_GREY);
    m.cone(x + 0.77, y + 0.37, 0.08, 8, 0.76, 0.9, WHITE);
  }
  lamp(m, x + 0.07, y + 0.93);
}

// Which of the three designs a tile gets, by its position.
export function designOf(x, y) {
  return Math.min(2, Math.floor(cellNoise(x * 5 + 2, y * 3 + 7) * 3));
}

export function building(m, x, y, zone) {
  const body = BODIES[zone];
  const [bx0, bz0, bx1, bz1, top] = body;
  const v = designOf(x, y);
  const tintStart = m.colors.length;
  m.box(x + bx0 - 0.015, 0, y + bz0 - 0.015, x + bx1 + 0.015, 0.06, y + bz1 + 0.015, PLINTH);
  ({ shop, gym, office, school, subway, hospital, university })[zone]?.(m, x, y, v);
  // Cornice rim under the roof: the outer ring only, so the roof stays visible.
  m.box(x + bx0 - 0.02, top, y + bz0 - 0.02, x + bx1 + 0.02, top + 0.04, y + bz0, TRIM);
  m.box(x + bx0 - 0.02, top, y + bz1, x + bx1 + 0.02, top + 0.04, y + bz1 + 0.02, TRIM);
  m.box(x + bx0 - 0.02, top, y + bz0, x + bx0, top + 0.04, y + bz1, TRIM);
  m.box(x + bx1, top, y + bz0, x + bx1 + 0.02, top + 0.04, y + bz1, TRIM);
  facadeDetail(m, x, y, body);
  tintFrom(m, tintStart, DISTRICT_TINTS[districtOf(x, y)], 0.22);
}

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

function mergeInto(target, source) {
  target.positions.push(...source.positions);
  target.colors.push(...source.colors);
}

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
      if (cell.type === 'building') {
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





// A delivery truck, built about its own origin: u runs along its travel, v across it.
