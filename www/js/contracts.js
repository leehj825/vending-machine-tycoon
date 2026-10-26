// Daily contracts: three client deals each morning. A contract is complete when today's sales
// reach its target, and it pays cash and reputation at once. Targets scale with the recent
// takings and the number of machines. An unfinished contract can be swapped once.
import { PRODUCTS, PRODUCT_IDS } from './products.js';

export const CONTRACT_RULES = {
  minDailyRevenue: 400,
  revenuePerMachine: 250,
  revenueShare: 0.6,
  productShare: 0.25,
  unitsShare: 0.4,
  rewardRate: 0.25,
  productRewardRate: 0.3,
  minProductUnits: 5,
  minTotalUnits: 15,
  rewardReputation: 15,
  rerollCost: 250,
  averagePrice: 3,
};

// The day's revenue scale: the best of the recent average, the machine count, and a floor.
export function revenueEstimate(state) {
  const recent = state.history.slice(0, 3);
  const average = recent.length ? recent.reduce((sum, d) => sum + d.revenue, 0) / recent.length : 0;
  return Math.max(CONTRACT_RULES.minDailyRevenue, average, state.machines.length * CONTRACT_RULES.revenuePerMachine);
}

const roundTo10 = (n) => Math.max(10, Math.round(n / 10) * 10);

// One contract of a kind; product is chosen for supply deals.
function makeContract(kind, state, random) {
  const base = revenueEstimate(state);
  const id = `${kind}-${state.day}-${Math.floor(random() * 1e6)}`;
  if (kind === 'revenue') {
    const target = roundTo10(base * CONTRACT_RULES.revenueShare);
    return { id, kind, target, reward: Math.round(target * CONTRACT_RULES.rewardRate), rerolled: false, done: false };
  }
  if (kind === 'supply') {
    const product = PRODUCT_IDS[Math.floor(random() * PRODUCT_IDS.length)];
    const price = PRODUCTS[product].basePrice;
    const target = Math.max(CONTRACT_RULES.minProductUnits, Math.round((base * CONTRACT_RULES.productShare) / price));
    const reward = Math.round(target * price * CONTRACT_RULES.productRewardRate);
    return { id, kind, product, target, reward, rerolled: false, done: false };
  }
  const target = Math.max(CONTRACT_RULES.minTotalUnits, Math.round((base * CONTRACT_RULES.unitsShare) / CONTRACT_RULES.averagePrice));
  return { id, kind: 'volume', target, reward: Math.round(target * CONTRACT_RULES.averagePrice * CONTRACT_RULES.rewardRate), rerolled: false, done: false };
}

// The three contracts for a morning: one of each kind.
export function makeContracts(state, random) {
  return ['revenue', 'supply', 'volume'].map((kind) => makeContract(kind, state, random));
}

// What today's sales count towards a contract.
export function progressOf(state, contract) {
  if (contract.kind === 'revenue') return state.today.revenue;
  if (contract.kind === 'supply') return state.today.sales[contract.product];
  return PRODUCT_IDS.reduce((sum, p) => sum + state.today.sales[p], 0);
}

// Pays out each contract whose target has been reached. Returns a message for each.
export function settleContracts(state) {
  const messages = [];
  for (const contract of state.contracts) {
    if (contract.done || progressOf(state, contract) < contract.target) continue;
    contract.done = true;
    state.cash += contract.reward;
    state.reputation += CONTRACT_RULES.rewardReputation;
    messages.push(`Contract complete: +$${contract.reward} and +${CONTRACT_RULES.rewardReputation} reputation.`);
  }
  return messages;
}

// Swaps an unfinished contract for a new one of the same kind, once, for a fee.
export function swapContract(state, id, random) {
  const index = state.contracts.findIndex((c) => c.id === id);
  if (index < 0) return { ok: false, message: 'No such contract.' };
  const old = state.contracts[index];
  if (old.done) return { ok: false, message: 'That contract is already complete.' };
  if (old.rerolled) return { ok: false, message: 'That contract was already swapped.' };
  if (state.cash < CONTRACT_RULES.rerollCost) return { ok: false, message: 'Not enough cash to swap.' };
  state.cash -= CONTRACT_RULES.rerollCost;
  const replacement = makeContract(old.kind, state, random);
  replacement.rerolled = true;
  state.contracts[index] = replacement;
  return { ok: true, message: 'Contract swapped.' };
}

