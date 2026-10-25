# Vending Machine Tycoon

A business game about a vending machine empire. Buy machines for city buildings, stock them with a
truck, set prices, and collect the cash. Keep reputation up, watch your rivals, and grow.

This is version 2: a from-scratch rewrite in plain JavaScript with three.js, packaged for Android
with Capacitor (the same approach as Deepward and Nightfall Settlement). The Flutter version is in
git history before the commit "Replace the Flutter app with a web game".

## Running it

```bash
npm test            # rules and movement tests (node:test, no install needed)
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
  js/locomotion.js  clip choice, pose blending, walls, touch range, paths (pure)
  js/walk.js        the player and the walkers (pure)
  js/figure.js      the three.js figure: 13 bones and the body parts
  js/walkmode.js    walk mode: the stick, Talk, Collect, Run, Office
  js/main.js        starts the game and runs the clock
  vendor/three.min.js   three.js r160 (classic build)
  assets/           sound files and app icon, for later
tests/sim.test.js   rules tests
tests/walk.test.js  movement, walls, paths and walkers
tools/build_clips.js  builds www/assets/clips.json from Nightfall Settlement's clips
```

## Current version (milestone 1)

- City map: roads, grass, and buildings of five zones (office, school, gym, shop, hospital)
- Buy a machine on a building ($400), one per building
- Six products, each with a base price and demand; sales depend on zone, price, and reputation
- Per-machine price multiplier per product (0.5× to 2×); higher prices sell less, most in schools
- Machines hold up to 50 items, 20 per product
- Warehouse (1,000 items): buy stock at half the base price
- Trucks ($500, 500 items): a restock run loads the warehouse, drives the road route past each machine
  that needs stock (nearest first), and comes back. Stock lands as the truck reaches each machine. Fuel
  is paid at the start. Routes rate Great, Good, Fair or Poor by length. Trucks follow the game clock,
  so they stop when the game is paused.
- Collect cash from each machine
- Reputation: +1 per sale, -5 per hour for an empty machine after a 4-hour grace; +5% sales per 100
  reputation, up to +50%
- Sandwiches go off three days after they are stocked, in a machine or in the warehouse; the
  stock is thrown out at the day's close, for $0.50 an item
- Clock: 1 game day = 5 minutes real time (3,000 ticks at 10 ticks per second), with 1×, 2×, and 4×
- Save every 30 seconds, at the end of each day, and when the page closes
- Walk mode (Walk button): a third-person player walks the streets with a stick. Walking uses the
  unarmed clips from Nightfall Settlement (walk, run, back, strafe). The player walks on grass and
  roads, not into buildings. A drag turns the view and the player with it; pinch zooms.
- Talk: the nearest walker in front and touching goes to the nearest machine with stock and buys one
  item (a sale). Collect: take the cash from a machine that is touching and in front.
- Walkers wander the roads on the right-hand side, in map view and in walk mode

## Planned (in the order of the design)

4. Daily contracts (three each morning, with a reroll for $250)
5. Theft and vandalism, with the Security upgrade
6. Rival company by zone, with a counter-attack
7. Research, rush hours, and machine upgrades (capacity, cooling, security, ad display)
8. More town life: walkers buying from machines by themselves, crossings, and traffic
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

The tests cover the rules (buying, pricing, sales, empty machines, restocking, collecting, the day
close, a save round trip) and the walking rules (clips, walls, touch range, paths, walkers).

To rebuild the clip data from Nightfall Settlement's source:

```bash
node tools/build_clips.js <path to Nightfall-Settlement>
```

## Android (planned)

The game is plain web files in `www/`. To package it, add Capacitor (`@capacitor/core`,
`@capacitor/cli`, `@capacitor/android`), point `webDir` at `www`, and run `npx cap add android`.
This step needs an Android SDK, which is not set up in this repository yet.
