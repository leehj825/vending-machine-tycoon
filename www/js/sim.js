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

// Short tips shown in the news at the start of a game.
const FIRST_DAY_HINTS = [
  'Tip: a shop front with an arrow above it can take a machine. Tap the building to buy one.',
  'Tip: stock machines from the Warehouse tab, then send a truck from Fleet.',
  'Tip: people may kick a machine. Walk up to them and talk to stop them.',
];

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
    research: Object.fromEntries(Object.keys(CONFIG.research).map((r) => [r, false])),
    hype: 0,
    rushTicks: 0,
    // Vandals kicking machines: each one is a machine being attacked until it is stopped.
    attacks: [],
    // Machines holding more cash than this show an arrow while walking.
    collectAlert: CONFIG.collectAlertStart,
    weather: 'sunny',
    // Warehouse price of each product, as a share of its normal price, and last day's change.
    market: Object.fromEntries(PRODUCT_IDS.map((p) => [p, 1])),
    marketTrend: Object.fromEntries(PRODUCT_IDS.map((p) => [p, 0])),
    news: [...FIRST_DAY_HINTS],
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

export function machineCapacity(machine) {
  return CONFIG.machineCapacity + machine.capacityLevel * CONFIG.capacityUpgradeSlots;
}

// What one unit sells for: the list price times the machine's multiplier, plus Premium Branding.
export function unitPrice(state, machine, product) {
  const branding = state.research.premiumBranding ? CONFIG.premiumPriceFactor : 1;
  return PRODUCTS[product].basePrice * machine.prices[product] * branding;
}

export function machineTotal(machine) {
  return PRODUCT_IDS.reduce((sum, p) => sum + machine.stock[p], 0);
}

export function wholesalePrice(product, state = null) {
  const market = state ? marketFactor(state, product) : 1;
  return PRODUCTS[product].basePrice * CONFIG.wholesaleShare * market;
}

export function weatherOf(state) {
  return CONFIG.weather[state.weather] ? state.weather : 'sunny';
}

export function marketFactor(state, product) {
  return state.market?.[product] ?? 1;
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
  if (cell?.type === 'house') return fail('That house is not for sale.');
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
    wear: 0,
    security: false,
    capacityLevel: 0,
    cooling: false,
    adDisplay: false,
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
  const price = unitPrice(state, machine, product);
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
  const cost = count * wholesalePrice(product, state);
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
        machineCapacity(machine) - machineTotal(machine),
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
    const speed = state.research.turboTrucks ? CONFIG.truckSpeed * CONFIG.turboSpeedFactor : CONFIG.truckSpeed;
    trip.at += speed * dt;
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
  const rush = state.rushTicks > 0 ? CONFIG.rushMultiplier : 1;
  const perHour = Math.min(
    0.95,
    PRODUCTS[product].demand * zoneDemand * priceFactor * CONDITION_SALES[machine.condition]
      * salesFactor(state, machine.zone) * (1 + reputationBonus(state.reputation)) * rush
      * CONFIG.weather[weatherOf(state)].sales,
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
      const price = unitPrice(state, machine, product);
      machine.stock[product] -= 1;
      machine.cash += price;
      state.today.sales[product] += 1;
      state.today.revenue += price;
      state.reputation += CONFIG.reputationGainPerSale;
    }
  }
  if (state.rushTicks > 0) state.rushTicks -= 1;
  announce(state, settleContracts(state));
  state.tick += 1;
  if (state.tick % CONFIG.ticksPerHour === 0) hourlyChecks(state);
  if (state.tick >= TICKS_PER_DAY) endDay(state);
}

// Wear builds up on a machine; each full step wears its condition down by one.
function addWear(state, machine, amount) {
  machine.wear = (machine.wear ?? 0) + amount;
  while (machine.wear >= CONFIG.wearLimit) {
    machine.wear -= CONFIG.wearLimit;
    if (machine.condition < CONDITIONS.length - 1) {
      machine.condition += 1;
      announce(state, [`A machine is wearing out: now ${CONDITIONS[machine.condition]}.`]);
    }
  }
}

// Each day a working machine may break down, more often when it is already worn. A broken
// machine costs reputation each day until it is repaired.
function breakdowns(state) {
  for (const machine of state.machines) {
    if (machine.condition === CONDITIONS.length - 1) {
      state.reputation = Math.max(0, state.reputation - CONFIG.brokenReputationPenalty);
      continue;
    }
    const chance = CONFIG.breakdownChancePerDay * (machine.condition + 1) * CONFIG.weather[weatherOf(state)].breakdown;
    if (nextRandom(state) < chance) {
      machine.condition = CONDITIONS.length - 1;
      announce(state, [`A machine broke down at (${machine.x}, ${machine.y}). Repair it to sell again.`]);
    }
  }
}

function hourlyChecks(state) {
  const hour = Math.floor(state.tick / CONFIG.ticksPerHour) % CONFIG.hoursPerDay;
  const night = hour >= CONFIG.nightStartHour || hour < CONFIG.nightEndHour;
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
    addWear(state, machine, CONFIG.wearPerHour * ZONES[machine.zone].crime * (night ? CONFIG.nightMultiplier : 1));
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

// A targeted machine is robbed, or a vandal comes to kick it. Cash in the till can be taken.
function targetMachine(state, machine) {
  const robbed = machine.cash > 0 && nextRandom(state) < CONFIG.theftShare;
  if (robbed) {
    const share = CONFIG.theftCashMin + nextRandom(state) * (CONFIG.theftCashMax - CONFIG.theftCashMin);
    const taken = machine.cash * share;
    machine.cash -= taken;
    announce(state, [`A machine was robbed: $${taken.toFixed(2)} gone.`]);
    return;
  }
  state.attacks ??= [];
  if (state.attacks.filter((a) => a.machineId === machine.id).length >= CONFIG.maxKickersPerMachine) return;
  state.attacks.push({ id: state.nextId++, machineId: machine.id, kicking: false, progress: 0 });
  announce(state, ['Someone is kicking a machine. Talk to them to stop it.']);
}

export function attackOn(state, machineId) {
  return (state.attacks ?? []).find((a) => a.machineId === machineId) || null;
}

function findAttack(state, attackId) {
  return (state.attacks ?? []).find((a) => a.id === attackId) || null;
}

// A vandal has reached the machine and started kicking it.
export function beginKick(state, attackId) {
  const attack = findAttack(state, attackId);
  if (attack) attack.kicking = true;
}

// Talking to the vandal stops the attack: the machine is left alone.
export function stopAttack(state, attackId) {
  if (!findAttack(state, attackId)) return fail('They have already moved on.');
  state.attacks = state.attacks.filter((a) => a.id !== attackId);
  announce(state, ['A vandal was talked out of kicking a machine.']);
  return { ok: true, message: 'You talked them out of it. The machine is safe.' };
}

// A punch chases the vandal off. It costs a little reputation, as passers-by see it.
export function punchAttack(state, attackId) {
  const result = stopAttack(state, attackId);
  if (!result.ok) return result;
  state.reputation = Math.max(0, state.reputation - CONFIG.punchReputationCost);
  return { ok: true, message: 'You chased the vandal off. Passers-by frown on it.' };
}

// Kicking goes on while the vandal is at the machine. Once it has gone on long enough, the
// machine is vandalized. Called every frame with the seconds that passed.
export function advanceAttacks(state, dt) {
  for (const attack of state.attacks ?? []) {
    if (!attack.kicking) continue;
    attack.progress += dt;
    const machine = machineById(state, attack.machineId);
    if (machine) addWear(state, machine, CONFIG.wearPerKickSecond * dt);
  }
  for (const attack of (state.attacks ?? []).filter((a) => a.progress >= CONFIG.vandalKickSeconds)) {
    completeAttack(state, attack.id);
  }
}

// The attack lands: the machine is vandalized, and the attack is over.
export function completeAttack(state, attackId) {
  const attack = findAttack(state, attackId);
  if (!attack) return;
  state.attacks = state.attacks.filter((a) => a.id !== attackId);
  const machine = machineById(state, attack.machineId);
  if (machine && machine.condition < CONDITIONS.length - 1) {
    machine.condition += 1;
    announce(state, [`A machine was vandalized: now ${CONDITIONS[machine.condition]}.`]);
  }
}

// The cash a machine must hold before walking shows an arrow to it.
export function collectAlertOf(state) {
  return state.collectAlert ?? CONFIG.collectAlertStart;
}

// HQ moves the arrow threshold up or down, within the limits.
export function changeCollectAlert(state, delta) {
  state.collectAlert = Math.min(CONFIG.collectAlertMax, Math.max(0, collectAlertOf(state) + delta));
  return { ok: true, message: `Arrows now show machines with over $${state.collectAlert}.` };
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
  machine.wear = 0;
  return ok('Machine repaired.');
}

// The free stock from a rewarded video: every product in every machine is filled, with no
// warehouse stock, truck or fuel needed. Once a day.
export function freeRestockRun(state) {
  if (state.freeRunDay === state.day) return fail('You have had your free run today.');
  for (const machine of state.machines) {
    for (const p of PRODUCT_IDS) machine.stock[p] = CONFIG.machinePerProduct;
  }
  state.freeRunDay = state.day;
  return ok('Every machine is stocked for free.');
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
  const cooled = state.research.efficientCooling ? CONFIG.coolingSpoilageFactor : 1;
  for (const machine of state.machines) {
    for (const product of PRODUCT_IDS) {
      if (machine.stock[product] > 0 && expired(machine.stockDay[product], product)) {
        const lost = machine.cooling ? Math.ceil(machine.stock[product] * CONFIG.coolingSpoilageFactor) : machine.stock[product];
        spoiled += lost;
        machine.stock[product] -= lost;
      }
    }
  }
  for (const product of PRODUCT_IDS) {
    if (state.warehouse[product] > 0 && expired(state.warehouseDay[product], product)) {
      const lost = Math.ceil(state.warehouse[product] * cooled);
      spoiled += lost;
      state.warehouse[product] -= lost;
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

export function buyResearch(state, id) {
  const item = CONFIG.research[id];
  if (!item) return fail('No such research.');
  if (state.research[id]) return fail('Already researched.');
  if (state.cash < item.cost) return fail(`Research costs $${item.cost}.`);
  state.cash -= item.cost;
  state.research[id] = true;
  return ok(`${item.name} researched.`);
}

export function upgradeCapacity(state, machineId) {
  const machine = machineById(state, machineId);
  if (!machine) return fail('No such machine.');
  if (machine.capacityLevel >= CONFIG.capacityUpgradeMaxLevel) return fail('Fully upgraded.');
  if (state.cash < CONFIG.capacityUpgradeCost) return fail(`Upgrade costs $${CONFIG.capacityUpgradeCost}.`);
  state.cash -= CONFIG.capacityUpgradeCost;
  machine.capacityLevel += 1;
  return ok(`Capacity is now ${machineCapacity(machine)} items.`);
}

export function installCooling(state, machineId) {
  const machine = machineById(state, machineId);
  if (!machine) return fail('No such machine.');
  if (machine.cooling) return fail('Already cooled.');
  if (state.cash < CONFIG.coolingUpgradeCost) return fail(`Cooling costs $${CONFIG.coolingUpgradeCost}.`);
  state.cash -= CONFIG.coolingUpgradeCost;
  machine.cooling = true;
  return ok('Cooling installed.');
}

export function installAdDisplay(state, machineId) {
  const machine = machineById(state, machineId);
  if (!machine) return fail('No such machine.');
  if (machine.adDisplay) return fail('Already has an ad display.');
  if (state.cash < CONFIG.adDisplayCost) return fail(`An ad display costs $${CONFIG.adDisplayCost}.`);
  state.cash -= CONFIG.adDisplayCost;
  machine.adDisplay = true;
  return ok('Ad display installed.');
}

// An ad campaign fills the hype meter. A full meter starts an hour of Rush Hour.
export function runCampaign(state) {
  if (state.cash < CONFIG.campaignCost) return fail(`A campaign costs $${CONFIG.campaignCost}.`);
  state.cash -= CONFIG.campaignCost;
  state.hype = Math.min(1, state.hype + CONFIG.campaignHype);
  if (state.hype >= 1) {
    state.hype = 0;
    state.rushTicks = CONFIG.rushTicks;
    announce(state, ['Rush Hour! Sales are running at ten times the speed.']);
    return ok('Rush Hour has started.');
  }
  return ok(`Hype is at ${Math.round(state.hype * 100)}%.`);
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
  const adMachines = state.machines.filter((m) => m.adDisplay).length;
  if (adMachines > 0) state.cash += adMachines * CONFIG.adDisplayDailyIncome;
  state.history.unshift({ day: state.day, sales: state.today.sales, revenue: state.today.revenue });
  state.history = state.history.slice(0, 7);
  state.today = { sales: zeroCounts(), revenue: 0 };
  state.day += 1;
  state.tick = 0;
  state.contracts = makeContracts(state, () => nextRandom(state));
  breakdowns(state);
  changeWeather(state);
  driftMarket(state);
  growRival(state);
}

// The weather for the coming day: sunny is most common, stormy the least.
const WEATHER_CHANCES = [['sunny', 4], ['cloudy', 3], ['rainy', 2], ['stormy', 1]];

function changeWeather(state) {
  const total = WEATHER_CHANCES.reduce((sum, [, weight]) => sum + weight, 0);
  let roll = nextRandom(state) * total;
  for (const [kind, weight] of WEATHER_CHANCES) {
    roll -= weight;
    if (roll < 0) {
      state.weather = kind;
      break;
    }
  }
  announce(state, [`Weather today: ${CONFIG.weather[weatherOf(state)].label.toLowerCase()}.`]);
}

// Each day the warehouse prices move a little, within their limits, and the change is kept for
// the trend arrow.
function driftMarket(state) {
  state.market ??= Object.fromEntries(PRODUCT_IDS.map((p) => [p, 1]));
  state.marketTrend ??= Object.fromEntries(PRODUCT_IDS.map((p) => [p, 0]));
  for (const p of PRODUCT_IDS) {
    const move = (nextRandom(state) * 2 - 1) * CONFIG.marketDrift;
    const before = marketFactor(state, p);
    const next = Math.min(CONFIG.marketMax, Math.max(CONFIG.marketMin, before * (1 + move)));
    state.market[p] = next;
    state.marketTrend[p] = next - before;
  }
}

// Total worth: cash, cash waiting in machines, and the warehouse stock at its cost.
export function netWorth(state) {
  const waiting = state.machines.reduce((sum, m) => sum + m.cash, 0);
  const stock = PRODUCT_IDS.reduce((sum, p) => sum + state.warehouse[p] * wholesalePrice(p, state), 0);
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
