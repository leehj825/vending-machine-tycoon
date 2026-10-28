// The rival company: a competitor chasing the same customers, one zone type at a time. Its
// presence grows each day, fastest in zones where you have few machines. A strong rival cuts
// your sales there. A counter-attack pushes it back, at a cost, and it creeps back afterwards.
import { CONFIG } from './config.js';
import { ZONE_IDS } from './products.js';

export function newRival() {
  return Object.fromEntries(ZONE_IDS.map((z) => [z, 0]));
}

// How much a rival's presence cuts the sales in a zone type: none at no presence, up to the cap.
export function salesFactor(state, zone) {
  const presence = state.rival[zone];
  const cut = Math.min(CONFIG.rivalMaxSalesCut, presence * CONFIG.rivalSalesCutPerPresence);
  return 1 - cut;
}

// One day's growth in each zone type. The more machines you have there, the less the rival grows.
export function growRival(state) {
  for (const zone of ZONE_IDS) {
    const machines = state.machines.filter((m) => m.zone === zone).length;
    const share = Math.max(CONFIG.rivalMinGrowthShare, 1 - machines * CONFIG.rivalResistancePerMachine);
    const growth = CONFIG.rivalBaseDailyGrowth * share;
    state.rival[zone] = Math.min(CONFIG.rivalMaxPresence, state.rival[zone] + growth);
  }
}

// What a counter-attack in a zone type costs: more the stronger the rival.
export function counterCost(state, zone) {
  return Math.round(CONFIG.rivalCounterBaseCost + state.rival[zone] * CONFIG.rivalCounterCostPerPresence);
}

export function counterAttack(state, zone) {
  if (state.rival[zone] <= 0) return { ok: false, message: 'The rival is not in that market.' };
  const cost = counterCost(state, zone);
  if (state.cash < cost) return { ok: false, message: `A counter-attack costs $${cost}.` };
  state.cash -= cost;
  state.rival[zone] = Math.max(0, state.rival[zone] - CONFIG.rivalCounterReduction);
  return { ok: true, message: 'Counter-attack launched. They will be back.' };
}
