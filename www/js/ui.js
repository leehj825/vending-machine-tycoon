// The screens around the city: the top bar, and the City, Warehouse, Fleet and HQ panels.
// Buttons carry data-act attributes; one click handler routes them to the game actions.
import { CONFIG } from './config.js';
import { PRODUCTS, PRODUCT_IDS, ZONES } from './products.js';
import * as sim from './sim.js';
import { cellAt, WAREHOUSE_CELL } from './world.js';

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
    `;
  }

  function renderPanel(state) {
    const tabs = [['city', 'City'], ['warehouse', 'Warehouse'], ['fleet', 'Fleet'], ['hq', 'HQ']]
      .map(([id, label]) => `<button class="tab ${ui.tab === id ? 'on' : ''}" data-act="tab" data-tab="${id}">${label}</button>`)
      .join('');
    const body = {
      city: () => cityPanel(state),
      warehouse: () => warehousePanel(state),
      fleet: () => fleetPanel(state),
      hq: () => hqPanel(state),
    }[ui.tab]();
    panel.innerHTML = `
      <nav class="tabs">${tabs}</nav>
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
    if (tile.type !== 'building') {
      return `<h2>${tile.type === 'road' ? 'Road' : 'Grass'}</h2><p class="hint">Machines go on buildings.</p>`;
    }
    const machine = sim.machineAt(state, cell.x, cell.y);
    if (!machine) {
      const zone = ZONES[tile.zone];
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
    return `
      <h2>${zone.name} machine</h2>
      <p class="hint">Stock ${sim.machineTotal(machine)}/${CONFIG.machineCapacity}</p>
      <div class="row">
        <span>Cash in machine: <b>${money(machine.cash)}</b></span>
        <button class="primary" data-act="collect" data-machine="${machine.id}" ${machine.cash > 0 ? '' : 'disabled'}>Collect</button>
      </div>
      <table><tr><th>Product</th><th>Stock</th><th>Price</th></tr>${rows}</table>`;
  }

  function warehousePanel(state) {
    const total = sim.warehouseTotal(state);
    const rows = PRODUCT_IDS.map((p) => {
      const unit = sim.wholesalePrice(p);
      return `
        <tr>
          <td>${PRODUCTS[p].name}</td>
          <td>${state.warehouse[p]}</td>
          <td>${money(unit)}</td>
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
    return `
      <h2>Fleet</h2>
      <p class="hint">${state.trucks.length} truck${state.trucks.length === 1 ? '' : 's'}, ${CONFIG.truckCapacity} items each.
        A run loads the warehouse and restocks every machine that needs stock.</p>
      <div class="row">
        <button data-act="buy-truck" ${state.cash < CONFIG.truckPrice ? 'disabled' : ''}>Buy truck ${wholeMoney(CONFIG.truckPrice)}</button>
        <button class="primary" data-act="dispatch" ${state.trucks.length === 0 ? 'disabled' : ''}>Send restock run</button>
      </div>`;
  }

  function hqPanel(state) {
    const today = PRODUCT_IDS.reduce((n, p) => n + state.today.sales[p], 0);
    const history = state.history.map((d) => `<tr><td>Day ${d.day}</td><td>${money(d.revenue)}</td></tr>`).join('');
    return `
      <h2>HQ</h2>
      <table>
        <tr><th>Net worth</th><td>${wholeMoney(sim.netWorth(state))}</td></tr>
        <tr><th>Machines</th><td>${state.machines.length}</td></tr>
        <tr><th>Trucks</th><td>${state.trucks.length}</td></tr>
        <tr><th>Today's sales</th><td>${today} items, ${money(state.today.revenue)}</td></tr>
      </table>
      ${history ? `<h3>Last days</h3><table>${history}</table>` : ''}`;
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
      tab: () => { ui.tab = d.tab; ui.note = ''; render(latest); },
      'buy-machine': () => act(() => sim.buyMachine(latest, +d.x, +d.y)),
      price: () => act(() => sim.setPrice(latest, +d.machine, d.product, sim.machineById(latest, +d.machine).prices[d.product] + +d.delta)),
      collect: () => act(() => sim.collectCash(latest, +d.machine)),
      'buy-stock': () => act(() => sim.buyWarehouseStock(latest, d.product, +d.units)),
      'buy-truck': () => act(() => sim.buyTruck(latest)),
      dispatch: () => act(() => sim.dispatchTruck(latest)),
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

  return { render, refresh, select, showMessage, ui };
}
