// The end-of-day summary: what sold, what the hired help did, and one tip for tomorrow.
import { PRODUCTS, PRODUCT_IDS } from './products.js';

const money = (n) => `$${n.toFixed(2)}`;

export function summaryHtml(summary) {
  const items = PRODUCT_IDS.reduce((sum, p) => sum + summary.sales[p], 0);
  const sold = PRODUCT_IDS.filter((p) => summary.sales[p] > 0)
    .map((p) => `<tr><td>${PRODUCTS[p].name}</td><td>${summary.sales[p]}</td></tr>`).join('');
  const s = summary.staff;
  const crew = [
    s.bought > 0 && `Purchasing agent bought ${s.bought} items for ${money(s.spent)}.`,
    s.trips > 0 && `Driver made ${s.trips} restock run${s.trips === 1 ? '' : 's'}.`,
    s.collected > 0 && `Collector brought in ${money(s.collected)} and kept ${money(s.fees)}.`,
    s.repaired > 0 && `Mechanic repaired ${s.repaired} machine${s.repaired === 1 ? '' : 's'} for ${money(s.repairCost)}.`,
    s.chasedOff > 0 && `Guard chased off ${s.chasedOff} troublemaker${s.chasedOff === 1 ? '' : 's'}.`,
    s.wages > 0 && `Wages paid: ${money(s.wages)}.`,
  ].filter(Boolean).map((line) => `<li>${line}</li>`).join('');
  return `
    <table class="summary">
      <tr><th>Sales</th><td>${items} items, ${money(summary.revenue)}</td></tr>
      <tr><th>Cash</th><td>${money(summary.cash)}</td></tr>
      <tr><th>Reputation</th><td>${summary.reputation}</td></tr>
    </table>
    ${sold ? `<table class="summary">${sold}</table>` : ''}
    ${crew ? `<ul class="news">${crew}</ul>` : ''}
    <p class="note">${summary.tip}</p>`;
}
