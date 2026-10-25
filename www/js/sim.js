// The game rules. Everything here is plain data and functions, with no browser code, so the
// tests can run it directly. Each action returns { ok, message } for the screen to show.
import { CONFIG } from './config.js';
import { PRODUCTS, PRODUCT_IDS, ZONES } from './products.js';
import { cellAt, generateCity, seededRandom, WAREHOUSE_CELL } from './world.js';
import { findPath, machineFront, walkerWalkable } from './locomotion.js';
import { makeContracts, settleContracts, swapContract as swapContractRule } from './contracts.js';
import { counterAttack as counterAttackRule, counterCost as counterCostRule, growRival, newRival, salesFactor } from './rival.js';

const TICKS_PER_DAY = CONFIG.ticksPerHour * CONFIG.hoursPerDay;
// Machine condition, best first, and how much each condition sells (broken sells nothing).
export const CONDITIONS = ['Excellent', 'Good', 'Fair', 'Poor', 'Broken'];
const CONDITION_SALES = [1, 0.9, 0.75, 0.5, 0];

export function newGame(seed = 7) {
  const state = {
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
    // The day each product's current stock arrived, for spoilage. Warehouse stock has its own.
    warehouseDay: Object.fromEntries(PRODUCT_IDS.map((p) => [p, 1])),
    spoiled: 0,
    contracts: [],
    rival: newRival(),
    news: [],
    nextId: 1,
    // Sales and revenue per product for today and the last seven days.
    today: { sales: zeroCounts(), revenue: 0 },
    history: [],
  };
  state.contracts = makeContracts(state, () => nextRandom(state));
  return state;
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
  if (!machineFront(state.city, x, y)) return fail('A machine needs a street beside it.');
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
    condition: 0,
    security: false,
    stockDay: Object.fromEntries(PRODUCT_IDS.map((p) => [p, state.day])),
  });
  return ok(`${ZONES[cell.zone].name} machine installed.`);
}

// A passer-by buys one item from a machine that has stock. Their choice is random among the
// products in stock, and it counts as a sale in every other way.
export function sellToWalker(state, machineId) {
  const machine = machineById(state, machineId);
  if (!machine) return fail('No such machine.');
  if (machine.condition === CONDITIONS.length - 1) return fail('That machine is broken.');
  const options = PRODUCT_IDS.filter((p) => machine.stock[p] > 0);
  if (options.length === 0) return fail('That machine is out of stock.');
  const product = options[Math.floor(nextRandom(state) * options.length)];
  const price = PRODUCTS[product].basePrice * machine.prices[product];
  machine.stock[product] -= 1;
  machine.cash += price;
  state.today.sales[product] += 1;
  state.today.revenue += price;
  state.reputation += CONFIG.reputationGainPerSale;
  announce(state, settleContracts(state));
  return ok(`A passer-by bought ${PRODUCTS[product].name}.`);
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
  if (state.warehouse[product] === 0) state.warehouseDay[product] = state.day;
  state.warehouse[product] += count;
  return ok(`Bought ${count} ${PRODUCTS[product].name}.`);
}

export function buyTruck(state) {
  if (state.cash < CONFIG.truckPrice) return fail('Not enough cash for a truck.');
  state.cash -= CONFIG.truckPrice;
  state.trucks.push({ id: state.nextId++ });
  return ok('Truck bought.');
}

// A restock run: the truck loads from the warehouse, drives the road route past each machine
// that needs stock, and comes back. The loads are taken now and the stock lands as the truck
// reaches each machine (see moveTrucks). Fuel is paid at the start.
export function dispatchTruck(state) {
  if (state.trucks.length === 0) return fail('You need a truck first.');
  const truck = state.trucks.find((t) => !t.trip);
  if (!truck) return fail('Every truck is out on a run.');
  if (warehouseTotal(state) === 0) return fail('The warehouse is empty.');
  const reserve = { ...state.warehouse };
  const cells = [];
  const stops = [];
  let here = WAREHOUSE_CELL;
  let loaded = 0;
  for (const machine of nearestRoute(state.machines, WAREHOUSE_CELL)) {
    const front = machineFront(state.city, machine.x, machine.y);
    if (!front) continue;
    const leg = findPath(state.city, here, front.cell, walkerWalkable);
    if (!leg) continue;
    const load = {};
    for (const product of PRODUCT_IDS) {
      if (loaded >= CONFIG.truckCapacity) break;
      const need = Math.min(
        CONFIG.machinePerProduct - machine.stock[product],
        CONFIG.machineCapacity - machineTotal(machine),
      );
      const give = Math.min(need, reserve[product], CONFIG.truckCapacity - loaded);
      if (give > 0) {
        load[product] = give;
        reserve[product] -= give;
        loaded += give;
      }
    }
    if (Object.keys(load).length === 0) continue;
    cells.push(...leg);
    stops.push({ machineId: machine.id, load, at: cells.length });
    here = front.cell;
  }
  if (stops.length === 0) return fail('Every machine is already stocked, or cannot be reached by road.');
  const back = findPath(state.city, here, WAREHOUSE_CELL, walkerWalkable);
  if (!back) return fail('No road back to the warehouse.');
  cells.push(...back);
  for (const stop of stops) {
    for (const [product, count] of Object.entries(stop.load)) state.warehouse[product] -= count;
  }
  const fuel = cells.length * CONFIG.fuelCostPerDistance;
  state.cash -= fuel;
  truck.trip = { path: cells, at: 0, stops, nextStop: 0, distance: cells.length };
  return ok(`A truck is on its way to ${stops.length} machines. Route ${routeRating(cells.length)}, fuel $${fuel.toFixed(2)}.`);
}

// How good a route is, by its length in tiles: short routes rate best.
export function routeRating(distance) {
  if (distance <= 50) return 'Great';
  if (distance <= 100) return 'Good';
  if (distance <= 200) return 'Fair';
  return 'Poor';
}

// Moves the trucks on their runs by dt seconds, and lands each stop's stock as they reach it.
export function moveTrucks(state, dt) {
  for (const truck of state.trucks) {
    const trip = truck.trip;
    if (!trip) continue;
    trip.at += CONFIG.truckSpeed * dt;
    while (trip.nextStop < trip.stops.length && trip.at >= trip.stops[trip.nextStop].at) {
      unload(state, trip.stops[trip.nextStop]);
      trip.nextStop += 1;
    }
    if (trip.at >= trip.path.length) truck.trip = null;
  }
}

function unload(state, stop) {
  const machine = machineById(state, stop.machineId);
  if (!machine) return;
  for (const [product, count] of Object.entries(stop.load)) {
    if (machine.stock[product] === 0) machine.stockDay[product] = state.day;
    machine.stock[product] += count;
  }
}

// Where a truck is on the map, in tiles: between the cells it has just passed and is heading to.
export function truckPosition(state, truck) {
  const trip = truck.trip;
  if (!trip) return { x: WAREHOUSE_CELL.x + 0.5, z: WAREHOUSE_CELL.y + 0.5, yaw: 0, moving: false };
  const idx = Math.min(Math.floor(trip.at), trip.path.length - 1);
  const frac = Math.min(1, trip.at - Math.floor(trip.at));
  const to = trip.path[idx];
  const from = idx > 0 ? trip.path[idx - 1] : WAREHOUSE_CELL;
  const x = from.x + 0.5 + (to.x - from.x) * frac;
  const z = from.y + 0.5 + (to.y - from.y) * frac;
  const yaw = Math.atan2(to.x - from.x, to.y - from.y);
  return { x, z, yaw, moving: true };
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
    PRODUCTS[product].demand * zoneDemand * priceFactor * CONDITION_SALES[machine.condition]
      * salesFactor(state, machine.zone) * (1 + reputationBonus(state.reputation)),
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
  announce(state, settleContracts(state));
  state.tick += 1;
  if (state.tick % CONFIG.ticksPerHour === 0) hourlyChecks(state);
  if (state.tick >= TICKS_PER_DAY) endDay(state);
}

function hourlyChecks(state) {
  const hour = Math.floor(state.tick / CONFIG.ticksPerHour) % CONFIG.hoursPerDay;
  for (const machine of state.machines) {
    if (machineTotal(machine) > 0) {
      machine.emptyHours = 0;
    } else {
      machine.emptyHours += 1;
      if (machine.emptyHours > CONFIG.emptyGraceHours) {
        const penalty = machine.security
          ? CONFIG.emptyPenaltyPerHour * CONFIG.securityPenaltyFactor
          : CONFIG.emptyPenaltyPerHour;
        state.reputation = Math.max(0, state.reputation - penalty);
      }
    }
    if (nextRandom(state) < securityChance(machine, hour)) {
      targetMachine(state, machine);
    }
  }
}

// The chance a machine is targeted this hour: more at night, with more cash in it, in riskier
// zones, and far less with a security system.
export function securityChance(machine, hour) {
  const night = hour >= CONFIG.nightStartHour || hour < CONFIG.nightEndHour;
  const cashRisk = Math.min(CONFIG.cashRiskCap, (machine.cash / 100) * CONFIG.cashRiskPer100);
  return CONFIG.securityBaseHourlyChance
    * (night ? CONFIG.nightMultiplier : 1)
    * ZONES[machine.zone].crime
    * (1 + cashRisk)
    * (machine.security ? CONFIG.securityRiskFactor : 1);
}

// A targeted machine is robbed, or vandalized. Nothing in the till means vandalism.
function targetMachine(state, machine) {
  const robbed = machine.cash > 0 && nextRandom(state) < CONFIG.theftShare;
  if (robbed) {
    const share = CONFIG.theftCashMin + nextRandom(state) * (CONFIG.theftCashMax - CONFIG.theftCashMin);
    const taken = machine.cash * share;
    machine.cash -= taken;
    announce(state, [`A machine was robbed: $${taken.toFixed(2)} gone.`]);
    return;
  }
  if (machine.condition < CONDITIONS.length - 1) {
    machine.condition += 1;
    announce(state, [`A machine was vandalized: now ${CONDITIONS[machine.condition]}.`]);
  }
}

// Repairs a machine to Excellent, at a price per level it has fallen.
export function repairMachine(state, machineId) {
  const machine = machineById(state, machineId);
  if (!machine) return fail('No such machine.');
  if (machine.condition === 0) return fail('That machine is already in good shape.');
  const cost = machine.condition * CONFIG.repairCostPerLevel;
  if (state.cash < cost) return fail(`Repairs cost $${cost}.`);
  state.cash -= cost;
  machine.condition = 0;
  return ok('Machine repaired.');
}

// Installs a security system on a machine, once.
export function installSecurity(state, machineId) {
  const machine = machineById(state, machineId);
  if (!machine) return fail('No such machine.');
  if (machine.security) return fail('This machine already has security.');
  if (state.cash < CONFIG.securityCost) return fail('Not enough cash for security.');
  state.cash -= CONFIG.securityCost;
  machine.security = true;
  return ok('Security installed.');
}

// Stock of a product that can spoil, and is now too old, is thrown out at the day's close. A
// sandwich stocked on day 1 is gone at the close of day 3.
function spoilStock(state) {
  let spoiled = 0;
  const expired = (day, product) => PRODUCTS[product].spoilDays && state.day + 1 - day >= PRODUCTS[product].spoilDays;
  for (const machine of state.machines) {
    for (const product of PRODUCT_IDS) {
      if (machine.stock[product] > 0 && expired(machine.stockDay[product], product)) {
        spoiled += machine.stock[product];
        machine.stock[product] = 0;
      }
    }
  }
  for (const product of PRODUCT_IDS) {
    if (state.warehouse[product] > 0 && expired(state.warehouseDay[product], product)) {
      spoiled += state.warehouse[product];
      state.warehouse[product] = 0;
    }
  }
  if (spoiled > 0) {
    state.cash -= spoiled * CONFIG.disposalCostPerItem;
    state.spoiled += spoiled;
  }
}

function announce(state, messages) {
  for (const message of messages) {
    state.news.unshift(message);
  }
  state.news = state.news.slice(0, 6);
}

export function counterAttack(state, zone) {
  const result = counterAttackRule(state, zone);
  return result.ok ? ok(result.message) : fail(result.message);
}

export { salesFactor } from './rival.js';

export function counterCost(state, zone) {
  return counterCostRule(state, zone);
}

export function swapContract(state, id) {
  const result = swapContractRule(state, id, () => nextRandom(state));
  return result.ok ? ok(result.message) : fail(result.message);
}

function endDay(state) {
  spoilStock(state);
  state.history.unshift({ day: state.day, sales: state.today.sales, revenue: state.today.revenue });
  state.history = state.history.slice(0, 7);
  state.today = { sales: zeroCounts(), revenue: 0 };
  state.day += 1;
  state.tick = 0;
  state.contracts = makeContracts(state, () => nextRandom(state));
  growRival(state);
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
