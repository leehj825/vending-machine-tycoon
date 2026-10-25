import test from 'node:test';
import assert from 'node:assert/strict';
import { CONFIG } from '../www/js/config.js';
import { PRODUCT_IDS } from '../www/js/products.js';
import * as sim from '../www/js/sim.js';
import { cellAt, WAREHOUSE_CELL } from '../www/js/world.js';
import * as loco from '../www/js/locomotion.js';

function buildingCell(state) {
  for (let y = 0; y < state.city.length; y++) {
    for (let x = 0; x < state.city[y].length; x++) {
      if (cellAt(state.city, x, y).type === 'building') return { x, y };
    }
  }
  throw new Error('no building in city');
}

function machineFrontFor(state, x, y) {
  return loco.machineFront(state.city, x, y);
}

function fullStock(machine, amount = CONFIG.machinePerProduct) {
  for (const p of PRODUCT_IDS) machine.stock[p] = amount;
}

test('a new game starts with cash, reputation, a city and a warehouse at the crossing', () => {
  const state = sim.newGame(7);
  assert.equal(state.cash, CONFIG.startingCash);
  assert.equal(state.reputation, CONFIG.startingReputation);
  assert.equal(state.city.length, CONFIG.gridSize);
  assert.equal(cellAt(state.city, WAREHOUSE_CELL.x, WAREHOUSE_CELL.y).type, 'road');
});

test('machines go only on building tiles, once, and need the price in cash', () => {
  const state = sim.newGame(7);
  const road = { x: 0, y: 1 };
  assert.equal(cellAt(state.city, road.x, road.y).type, 'road');
  assert.equal(sim.buyMachine(state, road.x, road.y).ok, false);

  const spot = buildingCell(state);
  assert.equal(sim.buyMachine(state, spot.x, spot.y).ok, true);
  assert.equal(state.cash, CONFIG.startingCash - CONFIG.machinePrice);
  assert.equal(sim.buyMachine(state, spot.x, spot.y).ok, false);

  state.cash = 10;
  const other = { ...spot, x: spot.x + 1 };
  if (cellAt(state.city, other.x, other.y).type === 'building') {
    assert.equal(sim.buyMachine(state, other.x, other.y).ok, false);
  }
});

test('a higher price lowers the chance of a sale, more so where customers are sensitive', () => {
  const state = sim.newGame(7);
  const spot = buildingCell(state);
  sim.buyMachine(state, spot.x, spot.y);
  const machine = state.machines[0];
  const product = 'soda';
  const low = sim.saleChance(state, { ...machine, prices: { ...machine.prices, [product]: 0.5 } }, product);
  const base = sim.saleChance(state, machine, product);
  const high = sim.saleChance(state, { ...machine, prices: { ...machine.prices, [product]: 2 } }, product);
  assert.ok(low > base && base > high, `expected ${low} > ${base} > ${high}`);
});

test('a stocked machine sells over a day, takes cash and raises reputation', () => {
  const state = sim.newGame(7);
  const spot = buildingCell(state);
  sim.buyMachine(state, spot.x, spot.y);
  const machine = state.machines[0];
  fullStock(machine);
  const cashBefore = machine.cash;
  for (let i = 0; i < CONFIG.ticksPerHour * 6; i++) sim.tick(state);
  const sold = PRODUCT_IDS.reduce((n, p) => n + (CONFIG.machinePerProduct - machine.stock[p]), 0);
  assert.ok(sold > 0, 'some items sold');
  assert.ok(machine.cash > cashBefore, 'machine holds the takings');
  assert.equal(state.reputation, CONFIG.startingReputation + sold * CONFIG.reputationGainPerSale);
});

test('an empty machine costs reputation only after the grace hours', () => {
  const state = sim.newGame(7);
  const spot = buildingCell(state);
  sim.buyMachine(state, spot.x, spot.y);
  const start = state.reputation;
  for (let i = 0; i < CONFIG.ticksPerHour * CONFIG.emptyGraceHours; i++) sim.tick(state);
  assert.equal(state.reputation, start, 'no penalty during grace');
  for (let i = 0; i < CONFIG.ticksPerHour * 2; i++) sim.tick(state);
  assert.ok(state.reputation < start, 'penalty after grace');
});

test('a truck drives its road route, restocks machines on the way and charges fuel', () => {
  const state = sim.newGame(7);
  // Two machines on different buildings, each with a street beside it.
  const spots = [];
  state.city.forEach((row, y) => row.forEach((cell, x) => {
    if (spots.length < 2 && cell.type === 'building' && machineFrontFor(state, x, y)) spots.push({ x, y });
  }));
  for (const spot of spots) sim.buyMachine(state, spot.x, spot.y);
  assert.equal(state.machines.length, 2, 'two machines');
  assert.equal(sim.dispatchTruck(state).ok, false, 'needs a truck');
  sim.buyTruck(state);
  assert.equal(sim.dispatchTruck(state).ok, false, 'needs warehouse stock');
  sim.buyWarehouseStock(state, 'soda', 200);
  const cashBefore = state.cash;
  assert.equal(sim.dispatchTruck(state).ok, true);
  assert.ok(state.cash < cashBefore, 'fuel is paid at the start');
  assert.equal(state.machines[0].stock.soda, 0, 'nothing lands before the truck arrives');
  assert.equal(state.trucks[0].trip.stops.length, 2);
  for (let i = 0; i < 4000 && state.trucks[0].trip; i++) sim.moveTrucks(state, 0.05);
  assert.equal(state.trucks[0].trip, null, 'the truck is back');
  for (const machine of state.machines) assert.equal(machine.stock.soda, CONFIG.machinePerProduct);
  assert.equal(state.warehouse.soda, 200 - 2 * CONFIG.machinePerProduct);
});

test('a truck\'s route rating follows its length', () => {
  assert.equal(sim.routeRating(20), 'Great');
  assert.equal(sim.routeRating(80), 'Good');
  assert.equal(sim.routeRating(150), 'Fair');
  assert.equal(sim.routeRating(300), 'Poor');
});

test('collecting moves a machine\'s takings into cash', () => {
  const state = sim.newGame(7);
  const spot = buildingCell(state);
  sim.buyMachine(state, spot.x, spot.y);
  const machine = state.machines[0];
  machine.cash = 42;
  const cash = state.cash;
  assert.equal(sim.collectCash(state, machine.id).ok, true);
  assert.equal(state.cash, cash + 42);
  assert.equal(machine.cash, 0);
  assert.equal(sim.collectCash(state, machine.id).ok, false);
});

test('a save survives a round trip through JSON and plays on the same way', () => {
  const state = sim.newGame(7);
  const spot = buildingCell(state);
  sim.buyMachine(state, spot.x, spot.y);
  fullStock(state.machines[0]);
  for (let i = 0; i < 50; i++) sim.tick(state);
  const copy = JSON.parse(JSON.stringify(state));
  for (let i = 0; i < 500; i++) {
    sim.tick(state);
    sim.tick(copy);
  }
  assert.deepEqual(copy, state);
});

test('the day closes after 24 hours and keeps the sales history', () => {
  const state = sim.newGame(7);
  const spot = buildingCell(state);
  sim.buyMachine(state, spot.x, spot.y);
  fullStock(state.machines[0]);
  for (let i = 0; i < CONFIG.ticksPerHour * CONFIG.hoursPerDay; i++) sim.tick(state);
  assert.equal(state.day, 2);
  assert.equal(state.history.length, 1);
  assert.equal(state.tick, 0);
});

test('a passer-by buys one item from a stocked machine and not from an empty one', () => {
  const state = sim.newGame(7);
  const spot = buildingCell(state);
  sim.buyMachine(state, spot.x, spot.y);
  const machine = state.machines[0];
  assert.equal(sim.sellToWalker(state, machine.id).ok, false, 'empty machine');
  fullStock(machine, 3);
  const before = PRODUCT_IDS.reduce((n, p) => n + machine.stock[p], 0);
  const cash = machine.cash;
  assert.equal(sim.sellToWalker(state, machine.id).ok, true);
  const after = PRODUCT_IDS.reduce((n, p) => n + machine.stock[p], 0);
  assert.equal(after, before - 1);
  assert.ok(machine.cash > cash);
});

test('a sandwich goes off when its third day closes, and disposal costs cash', () => {
  const state = sim.newGame(7);
  const spot = buildingCell(state);
  sim.buyMachine(state, spot.x, spot.y);
  const machine = state.machines[0];
  machine.stock.sandwich = 5;
  machine.stockDay.sandwich = 1;
  state.day = 3;
  state.tick = CONFIG.ticksPerHour * CONFIG.hoursPerDay - 1;
  const cash = state.cash;
  sim.tick(state); // closes day 3; at most one sale can happen in that last tick
  assert.equal(machine.stock.sandwich, 0, 'thrown out');
  assert.ok(state.spoiled >= 4 && state.spoiled <= 5, `spoiled ${state.spoiled}`);
  assert.ok(state.cash < cash + 5, 'disposal cost paid');
});

test('a sandwich stocked the day before is still fresh at the close of day 2', () => {
  const state = sim.newGame(7);
  const spot = buildingCell(state);
  sim.buyMachine(state, spot.x, spot.y);
  const machine = state.machines[0];
  machine.stock.sandwich = 5;
  machine.stockDay.sandwich = 2;
  state.day = 3;
  state.tick = CONFIG.ticksPerHour * CONFIG.hoursPerDay - 1;
  sim.tick(state);
  assert.ok(machine.stock.sandwich >= 4, 'still on sale');
  assert.equal(state.spoiled, 0);
});

test('three contracts a morning, one of each kind', () => {
  const state = sim.newGame(7);
  assert.equal(state.contracts.length, 3);
  assert.deepEqual(state.contracts.map((c) => c.kind).sort(), ['revenue', 'supply', 'volume']);
});

test('a contract pays when today\'s sales reach its target', () => {
  const state = sim.newGame(7);
  const revenue = state.contracts.find((c) => c.kind === 'revenue');
  const cash = state.cash;
  const rep = state.reputation;
  state.today.revenue = revenue.target;
  sim.tick(state);
  assert.equal(revenue.done, true);
  assert.equal(state.cash, cash + revenue.reward);
  assert.equal(state.reputation, rep + 15);
  assert.ok(state.news[0].includes('Contract complete'));
});

test('an unfinished contract can be swapped once for a fee', () => {
  const state = sim.newGame(7);
  const id = state.contracts[0].id;
  const kind = state.contracts[0].kind;
  const cash = state.cash;
  assert.equal(sim.swapContract(state, id).ok, true);
  assert.equal(state.cash, cash - 250);
  assert.equal(state.contracts[0].kind, kind);
  assert.equal(sim.swapContract(state, state.contracts[0].id).ok, false, 'only once');
});

test('the morning brings a new set of contracts', () => {
  const state = sim.newGame(7);
  const before = state.contracts.map((c) => c.id);
  for (let i = 0; i < CONFIG.ticksPerHour * CONFIG.hoursPerDay; i++) sim.tick(state);
  assert.equal(state.day, 2);
  assert.equal(state.contracts.length, 3);
  assert.ok(state.contracts.every((c, i) => c.id !== before[i]));
});

test('night and cash in the machine raise the risk; security lowers it', () => {
  const state = sim.newGame(7);
  const spot = buildingCell(state);
  sim.buyMachine(state, spot.x, spot.y);
  const machine = state.machines[0];
  machine.cash = 0;
  const day = sim.securityChance(machine, 12);
  const night = sim.securityChance(machine, 23);
  assert.ok(night > day * 2.5, 'night is about three times the day');
  machine.cash = 300;
  assert.ok(sim.securityChance(machine, 12) > day, 'cash raises the risk');
  machine.cash = 0;
  machine.security = true;
  assert.ok(sim.securityChance(machine, 12) < day, 'security lowers it');
});

function attackedMachine(state) {
  const spot = buildingCell(state);
  sim.buyMachine(state, spot.x, spot.y);
  const machine = state.machines[0];
  machine.cash = 0;
  for (let i = 0; i < 600000 && state.attacks.length === 0; i++) sim.tick(state);
  assert.equal(state.attacks.length, 1, 'a vandal comes');
  machine.condition = 0;
  machine.wear = 0;
  return { machine, attack: state.attacks[0] };
}

test('the walking arrow threshold starts at $50 and stays within its limits', () => {
  const state = sim.newGame(7);
  assert.equal(sim.collectAlertOf(state), CONFIG.collectAlertStart);
  sim.changeCollectAlert(state, -CONFIG.collectAlertStep);
  assert.equal(sim.collectAlertOf(state), CONFIG.collectAlertStart - CONFIG.collectAlertStep);
  for (let i = 0; i < 100; i++) sim.changeCollectAlert(state, CONFIG.collectAlertStep);
  assert.equal(sim.collectAlertOf(state), CONFIG.collectAlertMax);
  for (let i = 0; i < 100; i++) sim.changeCollectAlert(state, -CONFIG.collectAlertStep);
  assert.equal(sim.collectAlertOf(state), 0);
});

test('wear steps a machine down a condition, and kickers wear it faster', () => {
  const state = sim.newGame(7);
  const { machine } = attackedMachine(state);
  state.attacks = [{ id: 999, machineId: machine.id, kicking: true, progress: -1e9 }];
  machine.condition = 0;
  machine.wear = 0;
  sim.advanceAttacks(state, CONFIG.wearLimit / CONFIG.wearPerKickSecond);
  assert.equal(machine.condition, 1, 'one full step of wear');
  assert.equal(machine.wear, 0);
});

test('kickers pile up to a limit per machine', () => {
  const state = sim.newGame(7);
  const spot = buildingCell(state);
  sim.buyMachine(state, spot.x, spot.y);
  const machine = state.machines[0];
  machine.cash = 0;
  for (let i = 0; i < 300000 && state.attacks.filter((a) => a.machineId === machine.id).length < CONFIG.maxKickersPerMachine; i++) {
    sim.tick(state);
  }
  assert.equal(state.attacks.filter((a) => a.machineId === machine.id).length, CONFIG.maxKickersPerMachine);
});

test('a broken machine costs reputation each day until it is repaired', () => {
  const state = sim.newGame(7);
  const spot = buildingCell(state);
  sim.buyMachine(state, spot.x, spot.y);
  const machine = state.machines[0];
  machine.condition = 4;
  const day = state.day;
  const reputation = state.reputation;
  for (let i = 0; i < 100000 && state.day === day; i++) sim.tick(state);
  assert.ok(state.reputation < reputation, 'reputation falls while broken');
  assert.equal(sim.repairMachine(state, machine.id).ok, true);
  assert.equal(machine.condition, 0);
});

test('weather and warehouse prices stay within their rules as the days pass', () => {
  const state = sim.newGame(7);
  const day = state.day;
  for (let i = 0; i < 100000 && state.day < day + 20; i++) sim.tick(state);
  assert.ok(Object.keys(CONFIG.weather).includes(sim.weatherOf(state)));
  for (const p of Object.keys(state.market)) {
    assert.ok(state.market[p] >= CONFIG.marketMin && state.market[p] <= CONFIG.marketMax, 'price within limits');
  }
});

test('a vandal kicking a machine vandalizes it, and repair restores it', () => {
  const state = sim.newGame(7);
  const { machine, attack } = attackedMachine(state);
  sim.advanceAttacks(state, CONFIG.vandalKickSeconds * 2);
  assert.equal(machine.condition, 0, 'nothing happens until the vandal kicks');
  sim.beginKick(state, attack.id);
  sim.advanceAttacks(state, CONFIG.vandalKickSeconds);
  assert.ok(machine.condition > 0, 'vandalized');
  assert.equal(state.attacks.length, 0);
  const cash = state.cash;
  assert.equal(sim.repairMachine(state, machine.id).ok, true);
  assert.equal(machine.condition, 0);
  assert.ok(state.cash < cash);
});

test('talking to a kicking vandal stops the attack before the machine is hurt', () => {
  const state = sim.newGame(7);
  const { machine, attack } = attackedMachine(state);
  sim.beginKick(state, attack.id);
  sim.advanceAttacks(state, CONFIG.vandalKickSeconds / 2);
  assert.equal(sim.stopAttack(state, attack.id).ok, true);
  sim.advanceAttacks(state, CONFIG.vandalKickSeconds * 2);
  assert.equal(machine.condition, 0, 'the machine is safe');
  assert.equal(state.attacks.length, 0);
  assert.equal(sim.stopAttack(state, attack.id).ok, false, 'the vandal has gone');
});

test('security costs cash once, and a broken machine sells nothing to passers-by', () => {
  const state = sim.newGame(7);
  const spot = buildingCell(state);
  sim.buyMachine(state, spot.x, spot.y);
  const machine = state.machines[0];
  assert.equal(sim.installSecurity(state, machine.id).ok, true);
  assert.equal(sim.installSecurity(state, machine.id).ok, false);
  fullStock(machine, 3);
  machine.condition = 4;
  assert.equal(sim.sellToWalker(state, machine.id).ok, false);
});

test('the rival grows fastest where you have no machines, and a counter-attack costs cash', () => {
  const state = sim.newGame(7);
  const spot = buildingCell(state);
  sim.buyMachine(state, spot.x, spot.y);
  const zone = state.machines[0].zone;
  const other = Object.keys(state.rival).find((z) => z !== zone);
  for (let i = 0; i < CONFIG.ticksPerHour * CONFIG.hoursPerDay; i++) sim.tick(state);
  assert.ok(state.rival[other] > state.rival[zone], 'the unguarded zone grows faster');
  state.cash = 5000; // a counter-attack costs about $1,500 or more
  const cash = state.cash;
  const before = state.rival[other];
  assert.equal(sim.counterAttack(state, other).ok, true);
  assert.ok(state.rival[other] < before);
  assert.ok(state.cash < cash);
});

test('a strong rival cuts sales in its zone', () => {
  const state = sim.newGame(7);
  const spot = buildingCell(state);
  sim.buyMachine(state, spot.x, spot.y);
  const machine = state.machines[0];
  const clear = sim.saleChance(state, machine, 'soda');
  state.rival[machine.zone] = 0.75;
  assert.ok(sim.saleChance(state, machine, 'soda') < clear);
});

test('premium branding raises prices by ten percent', () => {
  const state = sim.newGame(7);
  const spot = buildingCell(state);
  sim.buyMachine(state, spot.x, spot.y);
  const machine = state.machines[0];
  const plain = sim.unitPrice(state, machine, 'soda');
  state.cash = 10000;
  assert.equal(sim.buyResearch(state, 'premiumBranding').ok, true);
  assert.ok(Math.abs(sim.unitPrice(state, machine, 'soda') - plain * 1.1) < 1e-9);
  assert.equal(sim.buyResearch(state, 'premiumBranding').ok, false, 'once');
});

test('capacity upgrades raise the limit, up to two levels', () => {
  const state = sim.newGame(7);
  const spot = buildingCell(state);
  sim.buyMachine(state, spot.x, spot.y);
  const machine = state.machines[0];
  state.cash = 10000;
  assert.equal(sim.machineCapacity(machine), CONFIG.machineCapacity);
  sim.upgradeCapacity(state, machine.id);
  sim.upgradeCapacity(state, machine.id);
  assert.equal(sim.machineCapacity(machine), CONFIG.machineCapacity + 2 * CONFIG.capacityUpgradeSlots);
  assert.equal(sim.upgradeCapacity(state, machine.id).ok, false);
});

test('an ad display pays a little each day', () => {
  const state = sim.newGame(7);
  const spot = buildingCell(state);
  sim.buyMachine(state, spot.x, spot.y);
  state.cash = 5000;
  sim.installAdDisplay(state, state.machines[0].id);
  const cash = state.cash;
  for (let i = 0; i < CONFIG.ticksPerHour * CONFIG.hoursPerDay; i++) sim.tick(state);
  assert.ok(state.cash >= cash + CONFIG.adDisplayDailyIncome);
});

test('four campaigns fill the hype meter and start Rush Hour, which sells faster', () => {
  const state = sim.newGame(7);
  state.cash = 10000;
  for (let i = 0; i < 3; i++) sim.runCampaign(state);
  assert.equal(state.rushTicks, 0);
  sim.runCampaign(state);
  assert.equal(state.rushTicks, CONFIG.rushTicks);
  const spot = buildingCell(state);
  sim.buyMachine(state, spot.x, spot.y);
  const machine = state.machines[0];
  const rush = sim.saleChance(state, machine, 'soda');
  state.rushTicks = 0;
  assert.ok(rush > sim.saleChance(state, machine, 'soda'));
});
