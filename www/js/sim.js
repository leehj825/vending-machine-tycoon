// The game rules. Everything here is plain data and functions, with no browser code, so the
// tests can run it directly. Each action returns { ok, message } for the screen to show.
import { CONFIG } from './config.js';
import { PRODUCTS, PRODUCT_IDS, ZONES } from './products.js';
import { cellAt, generateCity, seededRandom, WAREHOUSE_CELL } from './world.js';

const TICKS_PER_DAY = CONFIG.ticksPerHour * CONFIG.hoursPerDay;

export function newGame(seed = 7) {
  return {
    seed,
    rngState: seed,
    day: 1,
    tick: 0,
    cash: CONFIG.startingCash,
    reputation: CONFIG.startingReputation,
    city: generateCity(CONFIG.gridSize, seed),
    machines: [],
    trucks: [],
    warehouse: Object.fromEntries(PRODUCT_IDS.map((p) => [p, 0])),
    nextId: 1,
    // Sales and revenue per product for today and the last seven days.
    today: { sales: zeroCounts(), revenue: 0 },
    history: [],
  };
}

function zeroCounts() {
  return Object.fromEntries(PRODUCT_IDS.map((p) => [p, 0]));
}

// The game's random numbers come from one generator whose state is saved with the game.
function nextRandom(state) {
  const random = seededRandom(state.rngState);
  const value = random();
  state.rngState = (state.rngState + 0x9e3779b9) >>> 0;
  return value;
}

export function warehouseTotal(state) {
  return PRODUCT_IDS.reduce((sum, p) => sum + state.warehouse[p], 0);
}

export function machineTotal(machine) {
  return PRODUCT_IDS.reduce((sum, p) => sum + machine.stock[p], 0);
}

export function wholesalePrice(product) {
  return PRODUCTS[product].basePrice * CONFIG.wholesaleShare;
}

export function reputationBonus(reputation) {
  return Math.min(CONFIG.maxReputationBonus, (reputation / 100) * CONFIG.reputationBonusPer100);
}

export function machineById(state, id) {
  return state.machines.find((m) => m.id === id) || null;
}

export function machineAt(state, x, y) {
  return state.machines.find((m) => m.x === x && m.y === y) || null;
}

export function buyMachine(state, x, y) {
  const cell = cellAt(state.city, x, y);
  if (!cell || cell.type !== 'building') return fail('Machines go on building tiles.');
  if (machineAt(state, x, y)) return fail('There is already a machine here.');
  if (state.cash < CONFIG.machinePrice) return fail('Not enough cash for a machine.');
  state.cash -= CONFIG.machinePrice;
  state.machines.push({
    id: state.nextId++,
    x,
    y,
    zone: cell.zone,
    stock: zeroCounts(),
    prices: Object.fromEntries(PRODUCT_IDS.map((p) => [p, 1.0])),
    cash: 0,
    emptyHours: 0,
  });
  return ok(`${ZONES[cell.zone].name} machine installed.`);
}

export function setPrice(state, machineId, product, multiplier) {
  const machine = machineById(state, machineId);
  if (!machine) return fail('No such machine.');
  const clamped = Math.min(CONFIG.priceMultiplierMax, Math.max(CONFIG.priceMultiplierMin, multiplier));
  machine.prices[product] = Math.round(clamped * 10) / 10;
  return ok();
}

export function collectCash(state, machineId) {
  const machine = machineById(state, machineId);
  if (!machine) return fail('No such machine.');
  const amount = machine.cash;
  if (amount <= 0) return fail('Nothing to collect yet.');
  state.cash += amount;
  machine.cash = 0;
  return ok(`Collected $${amount.toFixed(2)}.`);
}

export function buyWarehouseStock(state, product, units) {
  const room = CONFIG.warehouseCapacity - warehouseTotal(state);
  const count = Math.min(units, room);
  if (count <= 0) return fail('The warehouse is full.');
  const cost = count * wholesalePrice(product);
  if (state.cash < cost) return fail('Not enough cash for that stock.');
  state.cash -= cost;
  state.warehouse[product] += count;
  return ok(`Bought ${count} ${PRODUCTS[product].name}.`);
}

export function buyTruck(state) {
  if (state.cash < CONFIG.truckPrice) return fail('Not enough cash for a truck.');
  state.cash -= CONFIG.truckPrice;
  state.trucks.push({ id: state.nextId++ });
  return ok('Truck bought.');
}

// One restock run: a truck loads from the warehouse and visits the machines that need stock,
// nearest first, then drives back. Trips are instant in this version.
export function dispatchTruck(state) {
  if (state.trucks.length === 0) return fail('You need a truck first.');
  if (warehouseTotal(state) === 0) return fail('The warehouse is empty.');
  const route = nearestRoute(state.machines, WAREHOUSE_CELL);
  let loaded = 0;
  let distance = 0;
  let here = WAREHOUSE_CELL;
  const stops = [];
  for (const machine of route) {
    const load = {};
    for (const product of PRODUCT_IDS) {
      if (loaded >= CONFIG.truckCapacity) break;
      const need = Math.min(
        CONFIG.machinePerProduct - machine.stock[product],
        CONFIG.machineCapacity - machineTotal(machine),
      );
      const give = Math.min(need, state.warehouse[product], CONFIG.truckCapacity - loaded);
      if (give > 0) {
        load[product] = give;
        loaded += give;
      }
    }
    if (Object.keys(load).length === 0) continue;
    distance += manhattan(here, machine);
    here = machine;
    stops.push({ machine, load });
  }
  if (stops.length === 0) return fail('Every machine is already stocked.');
  distance += manhattan(here, WAREHOUSE_CELL);
  for (const { machine, load } of stops) {
    for (const [product, count] of Object.entries(load)) {
      state.warehouse[product] -= count;
      machine.stock[product] += count;
    }
  }
  const fuel = distance * CONFIG.fuelCostPerDistance;
  state.cash -= fuel;
  return ok(`Restocked ${stops.length} machines with ${loaded} items. Fuel $${fuel.toFixed(2)}.`);
}

function nearestRoute(machines, start) {
  const left = [...machines];
  const route = [];
  let here = start;
  while (left.length > 0) {
    let best = 0;
    for (let i = 1; i < left.length; i++) {
      if (manhattan(here, left[i]) < manhattan(here, left[best])) best = i;
    }
    here = left[best];
    route.push(here);
    left.splice(best, 1);
  }
  return route;
}

function manhattan(a, b) {
  return Math.abs(a.x - b.x) + Math.abs(a.y - b.y);
}

// The chance that a machine sells one unit of a product in one tick.
export function saleChance(state, machine, product) {
  const zone = ZONES[machine.zone];
  const multiplier = machine.prices[product];
  const zoneDemand = zone.demand[product] || 1;
  const priceFactor = Math.max(0, 1 - zone.elasticity * (multiplier - 1));
  const perHour = Math.min(
    0.95,
    PRODUCTS[product].demand * zoneDemand * priceFactor * (1 + reputationBonus(state.reputation)),
  );
  return 1 - Math.pow(1 - perHour, 1 / CONFIG.ticksPerHour);
}

// Advances the game by one tick: sales every tick, empty-machine checks each hour, and the
// day's close at midnight.
export function tick(state) {
  for (const machine of state.machines) {
    for (const product of PRODUCT_IDS) {
      if (machine.stock[product] <= 0) continue;
      if (nextRandom(state) >= saleChance(state, machine, product)) continue;
      const price = PRODUCTS[product].basePrice * machine.prices[product];
      machine.stock[product] -= 1;
      machine.cash += price;
      state.today.sales[product] += 1;
      state.today.revenue += price;
      state.reputation += CONFIG.reputationGainPerSale;
    }
  }
  state.tick += 1;
  if (state.tick % CONFIG.ticksPerHour === 0) hourlyChecks(state);
  if (state.tick >= TICKS_PER_DAY) endDay(state);
}

function hourlyChecks(state) {
  for (const machine of state.machines) {
    if (machineTotal(machine) > 0) {
      machine.emptyHours = 0;
      continue;
    }
    machine.emptyHours += 1;
    if (machine.emptyHours > CONFIG.emptyGraceHours) {
      state.reputation = Math.max(0, state.reputation - CONFIG.emptyPenaltyPerHour);
    }
  }
}

function endDay(state) {
  state.history.unshift({ day: state.day, sales: state.today.sales, revenue: state.today.revenue });
  state.history = state.history.slice(0, 7);
  state.today = { sales: zeroCounts(), revenue: 0 };
  state.day += 1;
  state.tick = 0;
}

// Total worth: cash, cash waiting in machines, and the warehouse stock at its cost.
export function netWorth(state) {
  const waiting = state.machines.reduce((sum, m) => sum + m.cash, 0);
  const stock = PRODUCT_IDS.reduce((sum, p) => sum + state.warehouse[p] * wholesalePrice(p), 0);
  return state.cash + waiting + stock;
}

export function clockText(state) {
  const hour = Math.floor(state.tick / CONFIG.ticksPerHour);
  const minute = Math.floor(((state.tick % CONFIG.ticksPerHour) / CONFIG.ticksPerHour) * 60);
  return `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`;
}

function ok(message = '') {
  return { ok: true, message };
}

function fail(message) {
  return { ok: false, message };
}
