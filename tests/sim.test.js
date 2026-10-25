import test from 'node:test';
import assert from 'node:assert/strict';
import { CONFIG } from '../www/js/config.js';
import { PRODUCT_IDS } from '../www/js/products.js';
import * as sim from '../www/js/sim.js';
import { cellAt, WAREHOUSE_CELL } from '../www/js/world.js';

function buildingCell(state) {
  for (let y = 0; y < state.city.length; y++) {
    for (let x = 0; x < state.city[y].length; x++) {
      if (cellAt(state.city, x, y).type === 'building') return { x, y };
    }
  }
  throw new Error('no building in city');
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

test('a truck restocks machines from the warehouse and charges fuel', () => {
  const state = sim.newGame(7);
  const spot = buildingCell(state);
  sim.buyMachine(state, spot.x, spot.y);
  assert.equal(sim.dispatchTruck(state).ok, false, 'needs a truck');
  sim.buyTruck(state);
  assert.equal(sim.dispatchTruck(state).ok, false, 'needs warehouse stock');
  sim.buyWarehouseStock(state, 'soda', 100);
  const cashBefore = state.cash;
  assert.equal(sim.dispatchTruck(state).ok, true);
  assert.equal(state.machines[0].stock.soda, CONFIG.machinePerProduct);
  assert.equal(state.warehouse.soda, 100 - CONFIG.machinePerProduct);
  assert.ok(state.cash < cashBefore, 'buying stock and fuel cost cash');
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
