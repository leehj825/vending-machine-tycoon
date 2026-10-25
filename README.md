# Vending Machine Tycoon

A business game about a vending machine empire. Buy machines for city buildings, stock them with a
truck, set prices, and collect the cash. Keep reputation up, watch your rivals, and grow.

This is version 2: a from-scratch rewrite in plain JavaScript with three.js, packaged for Android
with Capacitor (the same approach as Deepward and Nightfall Settlement). The Flutter version is in
git history before the commit "Replace the Flutter app with a web game".

## Running it

```bash
npm test            # rules tests (node:test, no install needed)
npm run serve       # then open http://localhost:8080
```

Open `www/index.html` through a web server (ES modules do not load from `file://`).

## Layout

```
www/
  index.html        page and layout
  css/style.css     phone-first styles
  js/config.js      economy and rules constants
  js/products.js    products and zone types
  js/world.js       city generator (seeded)
  js/sim.js         game rules: buying, sales, reputation, trucks, the clock (no browser code)
  js/city3d.js      three.js city: map, machines, taps, drag and pinch camera
  js/ui.js          top bar and the City, Warehouse, Fleet and HQ panels
  js/save.js        save and load in local storage
  js/main.js        starts the game and runs the clock
  vendor/three.min.js   three.js r160 (classic build)
  assets/           sound files and app icon, for later
tests/sim.test.js   rules tests
```

## Current version (milestone 1)

- City map: roads, grass, and buildings of five zones (office, school, gym, shop, hospital)
- Buy a machine on a building ($400), one per building
- Six products, each with a base price and demand; sales depend on zone, price, and reputation
- Per-machine price multiplier per product (0.5× to 2×); higher prices sell less, most in schools
- Machines hold up to 50 items, 20 per product
- Warehouse (1,000 items): buy stock at half the base price
- Trucks ($500, 500 items): one restock run loads the warehouse and visits the machines that need
  stock, nearest first, and charges fuel
- Collect cash from each machine
- Reputation: +1 per sale, -5 per hour for an empty machine after a 4-hour grace; +5% sales per 100
  reputation, up to +50%
- Clock: 1 game day = 5 minutes real time (3,000 ticks at 10 ticks per second), with 1×, 2×, and 4×
- Save every 30 seconds, at the end of each day, and when the page closes

## Planned (in the order of the design)

1. Walking mode: a third-person player walks, talks to walkers, and collects from machines
   (animations from Nightfall Settlement's unarmed clips), with a stick and a view drag
2. Animated trucks on the map, and per-truck routes with efficiency ratings
3. Sandwich and salad spoilage
4. Daily contracts (three each morning, with a reroll for $250)
5. Theft and vandalism, with the Security upgrade
6. Rival company by zone, with a counter-attack
7. Research, rush hours, and machine upgrades (capacity, cooling, security, ad display)
8. Walkers on the pavement and the town's animated life
9. Android package with Capacitor, and an APK in CI

## Economy reference

| Item | Value |
| --- | --- |
| Starting cash | $2,000 |
| Machine | $400, 50 items total, 20 per product |
| Truck | $500, 500 items |
| Warehouse | 1,000 items |
| Products | Soda $3.00, Chips $2.25, Protein Bar $3.75, Coffee $4.50, Tech Gadget $30, Sandwich $6.50 |
| Fuel | $0.05 per unit of distance |

## Testing

```bash
npm test
```

The tests cover the rules: buying, pricing, sales, empty machines, restocking, collecting, the day
close, and a save round trip.

## Android (planned)

The game is plain web files in `www/`. To package it, add Capacitor (`@capacitor/core`,
`@capacitor/cli`, `@capacitor/android`), point `webDir` at `www`, and run `npx cap add android`.
This step needs an Android SDK, which is not set up in this repository yet.
