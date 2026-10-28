// Hired help. Each job the player does by hand early on can be handed to a paid worker once the
// business is big enough: a purchasing agent buys warehouse stock, a driver runs the restock trucks,
// a collector takes the cash, a mechanic repairs machines, and a night guard chases off vandals.
// Workers are paid every day; if the cash runs out they leave.
import { CONFIG } from './config.js';
import { PRODUCT_IDS } from './products.js';
import {
  announce, buyWarehouseStock, collectAlertOf, dispatchTruck, machineCapacity, machineTotal, marketFactor, warehouseTotal,
} from './sim.js';

const ok = (message = '') => ({ ok: true, message });
const fail = (message) => ({ ok: false, message });

export const STAFF_ROLES = Object.keys(CONFIG.staff);

export function newStaff() {
  return Object.fromEntries(STAFF_ROLES.map((role) => [role, false]));
}

// What the purchasing agent does for each product: keep at least `min` in the warehouse, and
// only buy while the warehouse price is at or under `maxPrice` times its normal price.
export function newAgentRules() {
  return Object.fromEntries(PRODUCT_IDS.map((p) => [p, { min: CONFIG.agent.defaultMin, maxPrice: CONFIG.agent.defaultMaxPrice }]));
}

export function newStaffToday() {
  return { bought: 0, spent: 0, collected: 0, fees: 0, repaired: 0, repairCost: 0, trips: 0, chasedOff: 0, wages: 0 };
}

export function dailyWages(state) {
  return STAFF_ROLES.reduce((sum, role) => sum + (state.staff[role] ? CONFIG.staff[role].wage : 0), 0);
}

export function hireStaff(state, role) {
  const job = CONFIG.staff[role];
  if (!job) return fail('No such job.');
  if (state.staff[role]) return fail(`You already employ a ${job.name.toLowerCase()}.`);
  if (state.machines.length < job.unlockMachines) return fail(`Unlocks at ${job.unlockMachines} machines.`);
  if (role === 'driver' && state.trucks.length === 0) return fail('A driver needs a truck first.');
  if (state.cash < job.wage) return fail(`The first day's wage is $${job.wage}.`);
  state.staff[role] = true;
  return ok(`${job.name} hired for $${job.wage} a day.`);
}

export function fireStaff(state, role) {
  const job = CONFIG.staff[role];
  if (!job || !state.staff[role]) return fail('Nobody to let go.');
  state.staff[role] = false;
  return ok(`${job.name} let go.`);
}

// Changes one of the agent's rules a step, within its limits.
export function setAgentRule(state, product, field, direction) {
  const rule = state.agentRules[product];
  if (!rule) return fail('No such product.');
  if (field === 'min') {
    rule.min = Math.min(CONFIG.agent.maxMin, Math.max(0, rule.min + direction * CONFIG.agent.minStep));
  } else {
    const next = rule.maxPrice + direction * CONFIG.agent.priceStep;
    rule.maxPrice = Math.round(Math.min(CONFIG.agent.maxPriceLimit, Math.max(CONFIG.agent.minPriceLimit, next)) * 100) / 100;
  }
  return ok();
}

// Wages come out at the end of each day. Whoever cannot be paid leaves.
export function payWages(state) {
  for (const role of STAFF_ROLES) {
    if (!state.staff[role]) continue;
    const job = CONFIG.staff[role];
    if (state.cash >= job.wage) {
      state.cash -= job.wage;
      state.staffToday.wages += job.wage;
    } else {
      state.staff[role] = false;
      announce(state, [`You could not pay the ${job.name.toLowerCase()}, who left.`]);
    }
  }
}

// What the workers do once an hour.
export function runStaffHour(state) {
  if (state.staff.agent) agentBuys(state);
  if (state.staff.driver) driverGoes(state);
  if (state.staff.collector) collectorCollects(state);
  if (state.staff.mechanic) mechanicRepairs(state);
}

function agentBuys(state) {
  for (const product of PRODUCT_IDS) {
    const rule = state.agentRules[product];
    if (!rule || state.warehouse[product] >= rule.min) continue;
    if (marketFactor(state, product) > rule.maxPrice) continue;
    const had = state.warehouse[product];
    const before = state.cash;
    if (buyWarehouseStock(state, product, rule.min - had).ok) {
      state.staffToday.bought += state.warehouse[product] - had;
      state.staffToday.spent += before - state.cash;
    }
  }
}

// The driver sets off with the next free truck once a machine is running low.
function driverGoes(state) {
  const low = state.machines.some((m) => machineTotal(m) < machineCapacity(m) * CONFIG.driverLowShare);
  if (!low || warehouseTotal(state) === 0) return;
  if (dispatchTruck(state).ok) state.staffToday.trips += 1;
}

// The collector empties machines holding more than the walking alert, and keeps a cut.
function collectorCollects(state) {
  const alert = collectAlertOf(state);
  const job = CONFIG.staff.collector;
  for (const machine of state.machines) {
    if (machine.cash <= alert) continue;
    const fee = machine.cash * job.cut;
    state.cash += machine.cash - fee;
    state.staffToday.collected += machine.cash - fee;
    state.staffToday.fees += fee;
    machine.cash = 0;
  }
}

// The mechanic repairs machines in poor shape, at a discount, while the cash lasts.
function mechanicRepairs(state) {
  const job = CONFIG.staff.mechanic;
  for (const machine of state.machines) {
    if (machine.condition < job.fromCondition) continue;
    const cost = machine.condition * CONFIG.repairCostPerLevel * job.repairShare;
    if (state.cash < cost) continue;
    state.cash -= cost;
    machine.condition = 0;
    machine.wear = 0;
    state.staffToday.repaired += 1;
    state.staffToday.repairCost += cost;
  }
}

// The guard stops some vandals and thieves before they start. Called when a machine is targeted;
// true when the guard chased them off. `roll` is a random number from 0 to 1.
export function guardStops(state, roll) {
  if (!state.staff.guard || roll >= CONFIG.staff.guard.stopChance) return false;
  state.staffToday.chasedOff += 1;
  return true;
}
