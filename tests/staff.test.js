import test from 'node:test';
import assert from 'node:assert/strict';
import { CONFIG } from '../www/js/config.js';
import { PRODUCT_IDS } from '../www/js/products.js';
import * as sim from '../www/js/sim.js';
import * as staff from '../www/js/staff.js';
import * as loco from '../www/js/locomotion.js';

// A new game with `count` machines on shop fronts that have a street beside them.
function gameWithMachines(count) {
  const state = sim.newGame(7);
  state.cash = 100000;
  state.city.forEach((row, y) => row.forEach((cell, x) => {
    if (state.machines.length < count && cell.type === 'building' && loco.machineFront(state.city, x, y)) sim.buyMachine(state, x, y);
  }));
  assert.equal(state.machines.length, count, 'machines placed');
  return state;
}

const hour = (state, hours = 1) => {
  for (let i = 0; i < CONFIG.ticksPerHour * hours; i++) sim.tick(state);
};

test('a job opens once enough machines are owned, and the first day is paid up front', () => {
  const state = gameWithMachines(2);
  assert.equal(staff.hireStaff(state, 'agent').ok, false, 'needs 3 machines');
  const more = gameWithMachines(3);
  more.cash = 10;
  assert.equal(staff.hireStaff(more, 'agent').ok, false, 'needs the first wage');
  more.cash = 1000;
  assert.equal(staff.hireStaff(more, 'agent').ok, true);
  assert.equal(staff.hireStaff(more, 'agent').ok, false, 'already hired');
  assert.equal(staff.fireStaff(more, 'agent').ok, true);
  const five = gameWithMachines(5);
  assert.equal(staff.hireStaff(five, 'driver').ok, false, 'a driver needs a truck');
});

test('wages come out each day, and a worker who cannot be paid leaves', () => {
  const state = gameWithMachines(3);
  staff.hireStaff(state, 'agent');
  state.cash = 1000;
  for (let i = 0; i < CONFIG.ticksPerHour * CONFIG.hoursPerDay; i++) sim.tick(state);
  assert.equal(state.day, 2);
  assert.ok(state.cash <= 1000 - CONFIG.staff.agent.wage + 1, 'the wage was paid');
  state.cash = 0;
  state.agentRules = staff.newAgentRules();
  for (const p of PRODUCT_IDS) state.agentRules[p].min = 0;
  for (let i = 0; i < CONFIG.ticksPerHour * CONFIG.hoursPerDay; i++) sim.tick(state);
  assert.equal(state.staff.agent, false, 'left without pay');
});

test('the purchasing agent keeps the warehouse stocked, but not at a price over the limit', () => {
  const state = gameWithMachines(3);
  for (const p of PRODUCT_IDS) state.warehouse[p] = 0;
  staff.hireStaff(state, 'agent');
  hour(state);
  for (const p of PRODUCT_IDS) assert.equal(state.warehouse[p], state.agentRules[p].min, `${p} stocked`);
  // A price above the limit: no purchase.
  const dear = gameWithMachines(3);
  for (const p of PRODUCT_IDS) dear.warehouse[p] = 0;
  staff.hireStaff(dear, 'agent');
  for (const p of PRODUCT_IDS) dear.market[p] = dear.agentRules[p].maxPrice + 0.2;
  hour(dear);
  for (const p of PRODUCT_IDS) assert.equal(dear.warehouse[p], 0, `${p} too dear`);
});

test('the driver sends a truck when a machine runs low', () => {
  const state = gameWithMachines(5);
  sim.buyTruck(state);
  for (const p of PRODUCT_IDS) state.warehouse[p] = 100;
  staff.hireStaff(state, 'driver');
  hour(state);
  assert.equal(state.trucks.some((t) => t.trip), true, 'a truck is out');
  assert.ok(state.staffToday.trips >= 1);
});

test('the collector takes the cash from full machines and keeps a cut', () => {
  const state = gameWithMachines(5);
  staff.hireStaff(state, 'collector');
  const machine = state.machines[0];
  machine.cash = sim.collectAlertOf(state) + 100;
  const before = state.cash;
  const amount = machine.cash;
  hour(state);
  assert.equal(machine.cash >= 0 && machine.cash < sim.collectAlertOf(state), true, 'emptied');
  assert.ok(state.cash - before > amount * (1 - CONFIG.staff.collector.cut) - 1, 'the rest came in');
});

test('the mechanic repairs machines in poor shape at half price', () => {
  const state = gameWithMachines(8);
  staff.hireStaff(state, 'mechanic');
  const machine = state.machines[0];
  machine.condition = 4;
  const before = state.cash;
  hour(state);
  assert.equal(machine.condition, 0);
  assert.ok(before - state.cash <= 4 * CONFIG.repairCostPerLevel * CONFIG.staff.mechanic.repairShare + 1);
});

test('the guard chases off some vandals', () => {
  const state = gameWithMachines(8);
  staff.hireStaff(state, 'guard');
  assert.equal(staff.guardStops(state, 0.1), true);
  assert.equal(staff.guardStops(state, 0.95), false);
  staff.fireStaff(state, 'guard');
  assert.equal(staff.guardStops(state, 0.1), false, 'no guard, no one chased off');
});

test('the agent rules change within their limits', () => {
  const state = sim.newGame(7);
  const product = PRODUCT_IDS[0];
  for (let i = 0; i < 40; i++) staff.setAgentRule(state, product, 'min', -1);
  assert.equal(state.agentRules[product].min, 0);
  for (let i = 0; i < 40; i++) staff.setAgentRule(state, product, 'price', 1);
  assert.equal(state.agentRules[product].maxPrice, CONFIG.agent.maxPriceLimit);
});

test('the first-day guide moves on as the player acts, and an older save skips it', async () => {
  const guide = await import('../www/js/tutorial.js');
  const state = gameWithMachines(0);
  assert.equal(state.tutorialStep, 0);
  assert.equal(guide.tutorialCheck(state), false, 'no machine yet');
  const owned = gameWithMachines(1);
  owned.tutorialStep = 0;
  assert.equal(guide.tutorialCheck(owned), true, 'a machine moves it on');
  assert.equal(guide.tutorialEvent(owned, 'collect'), false, 'not the step it waits for');
  for (const event of ['walk', 'open', 'refill', 'collect', 'stock', 'truck', 'done']) assert.equal(guide.tutorialEvent(owned, event), true, event);
  assert.equal(guide.tutorialStep(owned), null, 'finished');
  const old = JSON.parse(JSON.stringify(sim.newGame(7)));
  delete old.tutorialStep;
  assert.equal(sim.migrateState(old).tutorialStep, guide.TUTORIAL_DONE, 'an older save is not shown the guide');
});

test('a day that ends leaves a summary of its sales and what the help did', () => {
  const state = gameWithMachines(3);
  staff.hireStaff(state, 'agent');
  for (let i = 0; i < CONFIG.ticksPerHour * CONFIG.hoursPerDay; i++) sim.tick(state);
  assert.equal(state.summary.day, 1);
  assert.equal(state.summary.staff.wages, CONFIG.staff.agent.wage);
  assert.ok(state.summary.tip.length > 0);
});

test('machines keep selling while the app is closed, within their stock and the time cap', () => {
  const state = gameWithMachines(2);
  for (const machine of state.machines) for (const p of PRODUCT_IDS) machine.stock[p] = CONFIG.machinePerProduct;
  const cashBefore = state.machines.reduce((sum, m) => sum + m.cash, 0);
  const sold = sim.offlineSales(state, 3600);
  assert.ok(sold.items > 0, 'something sold');
  assert.ok(state.machines.reduce((sum, m) => sum + m.cash, 0) > cashBefore, 'the money waits in the machines');
  const total = state.machines.reduce((sum, m) => sum + sim.machineTotal(m), 0);
  assert.equal(total, 2 * PRODUCT_IDS.length * CONFIG.machinePerProduct - sold.items, 'stock came down by what sold');
  const capped = sim.offlineSales(gameWithMachines(2), 10 * 24 * 3600);
  assert.ok(capped.minutes <= CONFIG.offlineMaxMinutes, 'the time away is capped');
  const empty = sim.offlineSales(gameWithMachines(2), 3600);
  assert.equal(empty.items, 0, 'empty machines sell nothing');
});

test('a district needs its permit before machines can go there, and an older save has them all open', async () => {
  const world = await import('../www/js/world.js');
  const state = sim.newGame(7);
  state.cash = 100000;
  let far = null;
  state.city.forEach((row, y) => row.forEach((cell, x) => {
    if (!far && world.districtOf(x, y) === 3 && cell.type === 'building' && loco.machineFront(state.city, x, y)) far = { x, y };
  }));
  assert.ok(far, 'a shop front in the far district');
  assert.equal(sim.buyMachine(state, far.x, far.y).ok, false, 'closed');
  const before = state.cash;
  assert.equal(sim.buyDistrict(state, 3).ok, true);
  assert.equal(before - state.cash, CONFIG.districts[3].price);
  assert.equal(sim.buyDistrict(state, 3).ok, false, 'already open');
  assert.equal(sim.buyMachine(state, far.x, far.y).ok, true, 'open now');
  const poor = sim.newGame(7);
  poor.cash = 10;
  assert.equal(sim.buyDistrict(poor, 1).ok, false, 'too dear');
  const old = JSON.parse(JSON.stringify(sim.newGame(7)));
  delete old.districts;
  assert.deepEqual(sim.migrateState(old).districts, [true, true, true, true]);
});

test('people get varied looks; kids play only near schools and parks and stay close', async () => {
  const looks = await import('../www/js/looks.js');
  const walk = await import('../www/js/walk.js');
  const world = await import('../www/js/world.js');
  const random = world.seededRandom(5);
  const styles = new Set();
  for (let i = 0; i < 200; i++) {
    const look = looks.makeLook(random);
    styles.add(look.hairStyle);
    assert.ok([...looks.MEN_HAIR, ...looks.WOMEN_HAIR].includes(look.hairStyle));
    assert.equal(look.kid, false);
  }
  assert.ok(styles.size >= 10, 'many hair styles appear');
  for (let i = 0; i < 50; i++) assert.ok([...looks.GIRL_HAIR, ...looks.BOY_HAIR].includes(looks.makeLook(random, 'kid').hairStyle));
  const state = sim.newGame(7);
  const kids = walk.spawnKids(state.city, 3, random, [looks.makeLook(random, 'kid')], 50);
  assert.ok(kids.length > 0, 'a city has a school or a park with a street beside it');
  const near = (kid) => [[1, 0], [-1, 0], [0, 1], [0, -1]].some(([dx, dy]) => {
    const c = state.city[kid.home.y + dy]?.[kid.home.x + dx];
    return c && (c.type === 'park' || c.zone === 'school');
  });
  for (const kid of kids) assert.ok(near(kid), 'starts beside a school or a park');
  for (let i = 0; i < 4000; i++) {
    for (const kid of kids) {
      walk.stepWalker(kid, state.city, 0.05, random);
      assert.ok(Math.abs(kid.cell.x - kid.home.x) + Math.abs(kid.cell.y - kid.home.y) <= CONFIG.kidRange + 1, 'stays near home');
    }
  }
});
