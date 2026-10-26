import test from 'node:test';
import assert from 'node:assert/strict';
import { CONFIG } from '../www/js/config.js';
import { generateCity } from '../www/js/world.js';

const SEEDS = [7, 11, 23, 42, 99];

function neighbours(grid, x, y) {
  return [[1, 0], [-1, 0], [0, 1], [0, -1]]
    .map(([dx, dy]) => ({ x: x + dx, y: y + dy }))
    .filter((c) => c.y >= 0 && c.y < grid.length && c.x >= 0 && c.x < grid[c.y].length);
}

test('every road is reachable from the warehouse crossing', () => {
  for (const seed of SEEDS) {
    const grid = generateCity(CONFIG.gridSize, seed);
    const roads = [];
    grid.forEach((row, y) => row.forEach((c, x) => { if (c.type === 'road') roads.push({ x, y }); }));
    const seen = new Set(['0,0']);
    const queue = [{ x: 0, y: 0 }];
    for (let i = 0; i < queue.length; i++) {
      for (const n of neighbours(grid, queue[i].x, queue[i].y)) {
        const key = `${n.x},${n.y}`;
        if (grid[n.y][n.x].type !== 'road' || seen.has(key)) continue;
        seen.add(key);
        queue.push(n);
      }
    }
    assert.equal(seen.size, roads.length, `seed ${seed}: all roads connected`);
  }
});

test('every building and house has a road beside it', () => {
  for (const seed of SEEDS) {
    const grid = generateCity(CONFIG.gridSize, seed);
    grid.forEach((row, y) => row.forEach((c, x) => {
      if (c.type !== 'building' && c.type !== 'house') return;
      assert.ok(neighbours(grid, x, y).some((n) => grid[n.y][n.x].type === 'road'), `seed ${seed}: ${x},${y} touches a road`);
    }));
  }
});

test('the city has parks, parking lots, gas stations and shop fronts', () => {
  const kinds = new Set();
  for (const seed of SEEDS) {
    for (const row of generateCity(CONFIG.gridSize, seed)) for (const c of row) kinds.add(c.type);
  }
  for (const kind of ['park', 'lot', 'gas', 'building', 'house', 'road']) {
    assert.ok(kinds.has(kind), `${kind} appears`);
  }
});

test('no block has more than two shop fronts', () => {
  for (const seed of SEEDS) {
    const grid = generateCity(CONFIG.gridSize, seed);
    // A block is a run of non-road tiles in a strip two tiles wide: count shop fronts per run.
    for (let x = 1; x < grid[0].length - 1; x++) {
      let run = 0;
      let shops = 0;
      for (let y = 0; y < grid.length; y++) {
        if (grid[y][x].type === 'road' || grid[y][x + 1]?.type === 'road') {
          run = 0;
          shops = 0;
          continue;
        }
        run++;
        if (grid[y][x].type === 'building') shops++;
        if (grid[y][x + 1]?.type === 'building') shops++;
        assert.ok(shops <= 2, `seed ${seed}: at most two shop fronts in a block`);
      }
    }
  }
});
