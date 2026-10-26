// The screens around the city: the top bar, and the City, Warehouse, Fleet and HQ panels.
// Buttons carry data-act attributes; one click handler routes them to the game actions.
import { CONFIG } from './config.js';
import { PRODUCTS, PRODUCT_IDS, ZONE_IDS, ZONES } from './products.js';
import * as sim from './sim.js';
import * as staff from './staff.js';
import { cellAt, districtOf, WAREHOUSE_CELL } from './world.js';
import { CONTRACT_RULES, progressOf as contractProgress } from './contracts.js';
import { playSound } from './audio.js';
import { rewardReadyNow, showRewardAd } from './ads.js';

const money = (n) => `$${n.toFixed(2)}`;
const wholeMoney = (n) => `$${Math.round(n).toLocaleString('en-US')}`;

export function createUi({ panel, stats, toast, act, state: current }) {
  const ui = { tab: 'city', selected: null, note: '' };
  let latest = current;
  // True while a finger or mouse is down on the panel, so a refresh does not swap the button away.
  let busy = false;

  function render(state) {
    latest = state;
    renderStats(state);
    renderPanel(state);
  }

  // Keeps the numbers current without redrawing a panel someone is using.
  function refresh(state) {
    latest = state;
    renderStats(state);
    if (!busy) renderPanel(state);
  }

  function renderStats(state) {
    stats.innerHTML = `
      <span class="stat"><b>${wholeMoney(state.cash)}</b> cash</span>
      <span class="stat"><b>${state.reputation}</b> rep ${Math.round(sim.reputationBonus(state.reputation) * 100)}%</span>
      <span class="stat">Day <b>${state.day}</b> ${sim.clockText(state)}</span>
      <span class="stat">${CONFIG.weather[sim.weatherOf(state)].label}</span>
    `;
  }

  function renderPanel(state) {
    const body = {
      city: () => cityPanel(state),
      warehouse: () => warehousePanel(state),
      fleet: () => fleetPanel(state),
      hq: () => hqPanel(state),
    }[ui.tab]();
    panel.innerHTML = `
      ${ui.note ? `<p class="note">${ui.note}</p>` : ''}
      ${body}
    `;
  }

  function cityPanel(state) {
    const cell = ui.selected;
    if (!cell) {
      return '<p class="hint">Tap a building to buy a machine, or open one. Drag to turn the view. Pinch to zoom.</p>';
    }
    const tile = cellAt(state.city, cell.x, cell.y);
    if (cell.x === WAREHOUSE_CELL.x && cell.y === WAREHOUSE_CELL.y) {
      return '<h2>Warehouse</h2><p class="hint">Buy stock here, then send a truck from the Fleet tab.</p>';
    }
    if (tile.type === 'house') {
      return `<h2>${ZONES[tile.zone].name} house</h2><p class="hint">Houses are just for looking at. Machines go on shop fronts.</p>`;
    }
    if (tile.type !== 'building') {
      return `<h2>${tile.type === 'road' ? 'Road' : 'Grass'}</h2><p class="hint">Machines go on buildings.</p>`;
    }
    const machine = sim.machineAt(state, cell.x, cell.y);
    if (!machine) {
      const zone = ZONES[tile.zone];
      const district = districtOf(cell.x, cell.y);
      if (!state.districts[district]) {
        return `<h2>${zone.name} building</h2><p class="hint">The ${CONFIG.districts[district].name} district is closed. Buy its permit in HQ, under Districts, to put a machine here.</p>`;
      }
      return `
        <h2>${zone.name} building</h2>
        <p class="hint">No machine here yet.</p>
        <button class="primary" data-act="buy-machine" data-x="${cell.x}" data-y="${cell.y}"
          ${state.cash < CONFIG.machinePrice ? 'disabled' : ''}>Buy machine ${wholeMoney(CONFIG.machinePrice)}</button>`;
    }
    const zone = ZONES[machine.zone];
    const rows = PRODUCT_IDS.map((p) => `
      <tr>
        <td>${PRODUCTS[p].name}</td>
        <td>${machine.stock[p]}/${CONFIG.machinePerProduct}</td>
        <td class="price">
          <button data-act="price" data-machine="${machine.id}" data-product="${p}" data-delta="-0.1">−</button>
          <span>${machine.prices[p].toFixed(1)}× ${money(PRODUCTS[p].basePrice * machine.prices[p])}</span>
          <button data-act="price" data-machine="${machine.id}" data-product="${p}" data-delta="0.1">+</button>
        </td>
      </tr>`).join('');
    const kickers = (state.attacks ?? []).filter((a) => a.machineId === machine.id).length;
    const broken = machine.condition === sim.CONDITIONS.length - 1;
    return `
      <h2>${zone.name} machine</h2>
      <p class="hint">Stock ${sim.machineTotal(machine)}/${sim.machineCapacity(machine)}${kickers ? ` · <b>${kickers} kicking</b>` : ''}${broken ? ' · <b>broken</b>' : ''}</p>
      <div class="row">
        <span>Cash in machine: <b>${money(machine.cash)}</b></span>
        <button class="primary" data-act="collect" data-machine="${machine.id}" ${machine.cash > 0 ? '' : 'disabled'}>Collect</button>
      </div>
      <div class="row buttons">
        <button data-act="capacity" data-machine="${machine.id}" ${machine.capacityLevel >= CONFIG.capacityUpgradeMaxLevel ? 'disabled' : ''}>Capacity ${machine.capacityLevel}/${CONFIG.capacityUpgradeMaxLevel} $${CONFIG.capacityUpgradeCost}</button>
        <button data-act="cooling" data-machine="${machine.id}" ${machine.cooling ? 'disabled' : ''}>${machine.cooling ? 'Cooled' : `Cooling $${CONFIG.coolingUpgradeCost}`}</button>
        <button data-act="ads" data-machine="${machine.id}" ${machine.adDisplay ? 'disabled' : ''}>${machine.adDisplay ? 'Ads on' : `Ad display ${wholeMoney(CONFIG.adDisplayCost)}`}</button>
      </div>
      <div class="row">
        <span>Condition: <b>${sim.CONDITIONS[machine.condition]}</b>, wear ${Math.round(((machine.wear ?? 0) / CONFIG.wearLimit) * 100)}%</span>
        <span class="buttons">
          <button data-act="repair" data-machine="${machine.id}" ${machine.condition === 0 ? 'disabled' : ''}>Repair</button>
          <button data-act="security" data-machine="${machine.id}" ${machine.security ? 'disabled' : ''}>${machine.security ? 'Secured' : `Security ${wholeMoney(CONFIG.securityCost)}`}</button>
        </span>
      </div>
      <table><tr><th>Product</th><th>Stock</th><th>Price</th></tr>${rows}</table>`;
  }

  // A small arrow for a price's change today: up, down or flat.
  function trendArrow(change) {
    if (Math.abs(change) < 0.001) return '<span class="trend flat">–</span>';
    return change > 0 ? '<span class="trend up">▲</span>' : '<span class="trend down">▼</span>';
  }

  function warehousePanel(state) {
    const total = sim.warehouseTotal(state);
    const rows = PRODUCT_IDS.map((p) => {
      const unit = sim.wholesalePrice(p, state);
      return `
        <tr>
          <td>${PRODUCTS[p].name}</td>
          <td>${state.warehouse[p]}</td>
          <td>${money(unit)} ${trendArrow(state.marketTrend?.[p] ?? 0)}</td>
          <td class="buttons">
            ${[10, 50, 100].map((n) => `<button data-act="buy-stock" data-product="${p}" data-units="${n}">+${n}</button>`).join('')}
          </td>
        </tr>`;
    }).join('');
    return `
      <h2>Warehouse</h2>
      <p class="hint">Stock ${total}/${CONFIG.warehouseCapacity}</p>
      <table><tr><th>Product</th><th>In store</th><th>Cost</th><th></th></tr>${rows}</table>`;
  }

  function fleetPanel(state) {
    const idle = state.trucks.some((t) => !t.trip);
    const needStock = state.machines.filter((m) => sim.machineTotal(m) < sim.machineCapacity(m)).length;
    const rows = state.trucks.map((t, i) => {
      const trip = t.trip;
      const status = trip
        ? `On a run: stop ${trip.nextStop + 1} of ${trip.stops.length}, route ${sim.routeRating(trip.distance)}`
        : 'Parked at the warehouse';
      return `<tr><td>Truck ${i + 1}</td><td>${status}</td></tr>`;
    }).join('');
    return `
      <h2>Fleet</h2>
      <p class="hint">A run loads the warehouse and restocks each machine on the road route, nearest first.
        Trucks carry ${CONFIG.truckCapacity} items. ${needStock} ${needStock === 1 ? 'machine needs' : 'machines need'} stock.</p>
      ${rows ? `<table>${rows}</table>` : ''}
      <div class="row">
        <button data-act="buy-truck" ${state.cash < CONFIG.truckPrice ? 'disabled' : ''}>Buy truck ${wholeMoney(CONFIG.truckPrice)}</button>
        <button class="primary" data-act="dispatch" ${!idle ? 'disabled' : ''}>Send restock run</button>
      </div>
      ${rewardReadyNow() && state.freeRunDay !== state.day ? `
      <div class="row">
        <span class="hint">Watch a short video to stock every machine for free, once a day.</span>
        <button data-act="free-run">📺 Ad: Free run</button>
      </div>` : ''}`;
  }

  function contractRows(state) {
    return state.contracts.map((c) => {
      const progress = contractProgress(state, c);
      const what = c.kind === 'revenue' ? `Take ${wholeMoney(c.target)} today`
        : c.kind === 'supply' ? `Sell ${c.target} ${PRODUCTS[c.product].name} today`
        : `Sell ${c.target} items today`;
      const status = c.done ? 'Complete' : `${Math.min(progress, c.target)} / ${c.target}`;
      const swap = !c.done && !c.rerolled
        ? `<button data-act="swap" data-id="${c.id}" ${state.cash < CONTRACT_RULES.rerollCost ? 'disabled' : ''}>Swap ${wholeMoney(CONTRACT_RULES.rerollCost)}</button>`
        : '';
      return `<tr><td>${what}<br><span class="hint">Pays ${wholeMoney(c.reward)} and +${CONTRACT_RULES.rewardReputation} rep</span></td>
        <td>${status}</td><td>${swap}</td></tr>`;
    }).join('');
  }

  function researchRows(state) {
    return Object.entries(CONFIG.research).map(([id, item]) => `
      <tr><td>${item.name}<br><span class="hint">${item.text}</span></td>
      <td>${state.research[id]
        ? 'Done'
        : `<button data-act="research" data-id="${id}" ${state.cash < item.cost ? 'disabled' : ''}>${wholeMoney(item.cost)}</button>`}</td></tr>`).join('');
  }

  function rivalRows(state) {
    return ZONE_IDS.map((zone) => {
      const presence = Math.round(state.rival[zone] * 100);
      const cut = Math.round((1 - sim.salesFactor(state, zone)) * 100);
      const attack = state.rival[zone] > 0
        ? `<button data-act="counter" data-zone="${zone}" ${state.cash < sim.counterCost(state, zone) ? 'disabled' : ''}>Counter ${wholeMoney(sim.counterCost(state, zone))}</button>`
        : '';
      return `<tr><td>${ZONES[zone].name}</td><td>${presence}% (sales −${cut}%)</td><td>${attack}</td></tr>`;
    }).join('');
  }

  function hqPanel(state) {
    const today = PRODUCT_IDS.reduce((n, p) => n + state.today.sales[p], 0);
    const broken = state.machines.filter((m) => m.condition === sim.CONDITIONS.length - 1).length;
    const attacked = new Set((state.attacks ?? []).map((a) => a.machineId)).size;
    const rising = PRODUCT_IDS.filter((p) => (state.marketTrend?.[p] ?? 0) > 0.001).length;
    const falling = PRODUCT_IDS.filter((p) => (state.marketTrend?.[p] ?? 0) < -0.001).length;
    const history = state.history.map((d) => `<tr><td>Day ${d.day}</td><td>${money(d.revenue)}</td></tr>`).join('');
    const news = state.news.map((n) => `<li>${n}</li>`).join('');
    return `
      <h2>HQ</h2>
      <table>
        <tr><th>Net worth</th><td>${wholeMoney(sim.netWorth(state))}</td></tr>
        <tr><th>Machines</th><td>${state.machines.length}</td></tr>
        <tr><th>Weather</th><td>${CONFIG.weather[sim.weatherOf(state)].label}</td></tr>
        <tr><th>Broken or attacked</th><td>${broken} broken, ${attacked} under attack</td></tr>
        <tr><th>Warehouse prices today</th><td>${rising} up, ${falling} down</td></tr>
        <tr><th>Trucks</th><td>${state.trucks.length}</td></tr>
        <tr><th>Today's sales</th><td>${today} items, ${money(state.today.revenue)}</td></tr>
        <tr><th>Spoiled so far</th><td>${state.spoiled} items</td></tr>
      </table>
      <h3>Districts</h3>
      ${districtPanel(state)}
      <h3>Staff</h3>
      ${staffPanel(state)}
      <h3>Marketing</h3>
      <div class="row">
        <span>${state.rushTicks > 0 ? `<b>Rush Hour</b> on, ${Math.ceil(state.rushTicks / CONFIG.ticksPerHour * 60)} min left` : `Hype ${Math.round(state.hype * 100)}%`}</span>
        <button data-act="campaign" ${state.cash < CONFIG.campaignCost ? 'disabled' : ''}>Ad campaign ${wholeMoney(CONFIG.campaignCost)}</button>
      </div>
      <h3>Walking</h3>
      <div class="row">
        <span>Arrows to machines with over ${wholeMoney(sim.collectAlertOf(state))}</span>
        <span>
          <button data-act="alert" data-delta="${-CONFIG.collectAlertStep}">−</button>
          <button data-act="alert" data-delta="${CONFIG.collectAlertStep}">+</button>
        </span>
      </div>
      <h3>Research</h3>
      <table>${researchRows(state)}</table>
      <h3>Rival company</h3>
      <table>${rivalRows(state)}</table>
      <h3>Contracts</h3>
      <table>${contractRows(state)}</table>
      ${news ? `<h3>News</h3><ul class="news">${news}</ul>` : ''}
      ${history ? `<h3>Last days</h3><table>${history}</table>` : ''}`;
  }

  // The map's districts: a permit opens one for machines.
  function districtPanel(state) {
    const rows = CONFIG.districts.map((d, id) => {
      const owned = state.machines.filter((m) => districtOf(m.x, m.y) === id).length;
      const action = state.districts[id]
        ? `<span class="hint">Open, ${owned} machine${owned === 1 ? '' : 's'}</span>`
        : `<button class="primary" data-act="buy-district" data-id="${id}" ${state.cash < d.price ? 'disabled' : ''}>Permit ${wholeMoney(d.price)}</button>`;
      return `<tr><td><b>${d.name}</b></td><td class="buttons">${action}</td></tr>`;
    }).join('');
    return `<table>${rows}</table>`;
  }

  // The jobs that can be handed to hired help, with what each costs a day.
  function staffPanel(state) {
    const rows = staff.STAFF_ROLES.map((role) => {
      const job = CONFIG.staff[role];
      let action;
      if (state.staff[role]) action = `<button data-act="fire" data-role="${role}">Let go</button>`;
      else if (state.machines.length < job.unlockMachines) action = `<span class="hint">${job.unlockMachines} machines</span>`;
      else action = `<button class="primary" data-act="hire" data-role="${role}">Hire</button>`;
      return `<tr><td><b>${job.name}</b> ${money(job.wage)}/day<br><span class="hint">${job.blurb}</span></td><td class="buttons">${action}</td></tr>`;
    }).join('');
    return `<table>${rows}</table>
      <p class="hint">Wages each day: ${money(staff.dailyWages(state))}</p>
      ${state.staff.agent ? agentRulesPanel(state) : ''}`;
  }

  // What the purchasing agent keeps in the warehouse, and the most it will pay.
  function agentRulesPanel(state) {
    const rows = PRODUCT_IDS.map((p) => {
      const rule = state.agentRules[p];
      const buttons = (field) => `<button data-act="agent-rule" data-product="${p}" data-field="${field}" data-dir="-1">−</button><button data-act="agent-rule" data-product="${p}" data-field="${field}" data-dir="1">+</button>`;
      return `<tr><td>${PRODUCTS[p].name}</td><td>keep ${rule.min}</td><td class="buttons">${buttons('min')}</td><td>pay up to ${Math.round(rule.maxPrice * 100)}%</td><td class="buttons">${buttons('price')}</td></tr>`;
    }).join('');
    return `<h3>Purchasing agent's rules</h3><table>${rows}</table>`;
  }

  // One handler for every button in the panel and the top bar.
  const endPress = () => setTimeout(() => { busy = false; }, 0);
  panel.addEventListener('pointerdown', () => { busy = true; });
  panel.addEventListener('pointerup', endPress);
  panel.addEventListener('pointercancel', endPress);
  panel.addEventListener('click', (e) => route(e));
  stats.addEventListener('click', (e) => route(e));

  function route(e) {
    const el = e.target.closest('[data-act]');
    if (!el) return;
    const d = el.dataset;
    const actions = {
      'buy-machine': () => act(() => sim.buyMachine(latest, +d.x, +d.y)),
      price: () => act(() => sim.setPrice(latest, +d.machine, d.product, sim.machineById(latest, +d.machine).prices[d.product] + +d.delta)),
      'buy-district': () => act(() => sim.buyDistrict(latest, +d.id)),
      hire: () => act(() => staff.hireStaff(latest, d.role)),
      fire: () => act(() => staff.fireStaff(latest, d.role)),
      'agent-rule': () => act(() => staff.setAgentRule(latest, d.product, d.field, +d.dir)),
      collect: () => act(() => sim.collectCash(latest, +d.machine)),
      repair: () => act(() => sim.repairMachine(latest, +d.machine)),
      security: () => act(() => sim.installSecurity(latest, +d.machine)),
      'buy-stock': () => act(() => sim.buyWarehouseStock(latest, d.product, +d.units)),
      'buy-truck': () => act(() => sim.buyTruck(latest)),
      'free-run': () => showRewardAd(() => act(() => sim.freeRestockRun(latest))),
      dispatch: () => {
        const result = act(() => sim.dispatchTruck(latest));
        if (result.ok) playSound('truck');
      },
      swap: () => act(() => sim.swapContract(latest, d.id)),
      counter: () => act(() => sim.counterAttack(latest, d.zone)),
      research: () => act(() => sim.buyResearch(latest, d.id)),
      campaign: () => act(() => sim.runCampaign(latest)),
      capacity: () => act(() => sim.upgradeCapacity(latest, +d.machine)),
      cooling: () => act(() => sim.installCooling(latest, +d.machine)),
      ads: () => act(() => sim.installAdDisplay(latest, +d.machine)),
      alert: () => act(() => sim.changeCollectAlert(latest, +d.delta)),
    };
    actions[d.act]?.();
  }

  // The city view reports a tap here: a building opens its panel.
  function select(cell) {
    ui.selected = cell;
    ui.tab = 'city';
    render(latest);
  }

  function showMessage(result) {
    ui.note = result.message;
    if (result.message) toast(result.message, result.ok);
    render(latest);
  }

  // Opens a tab from the left rail. The City tab shows the selected building, if any.
  function openTab(tab) {
    ui.tab = tab;
    ui.note = '';
    render(latest);
  }

  return { render, refresh, select, showMessage, openTab, ui };
}
