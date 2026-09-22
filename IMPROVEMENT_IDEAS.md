# Improvement Ideas

A running list of ideas discussed but not yet built, as of v1.1.26. Nothing
here is scheduled - it's a backlog to pick from.

## Visual / Animation

- **Fix the tile/building isometric alignment** - long-standing issue: the
  grid step is 0.70x tile width but the building artwork's footprint is
  0.94x, so buildings sit slightly off their tiles. The single biggest
  visual-polish item left, but touching the isometric spacing math risks
  shifting things that already look right elsewhere in the renderer.
- **Floating "+$" sale-popup animation** - a small text/coin pops up over a
  machine each time it sells. Pure Flutter animation, no new art.
- **Weather visual overlay** (rain/snow/fog) - `WeatherType` already exists
  in the simulation engine and is tracked in game state, but has no on-screen
  effect yet. Needs a real art/particle pass, unlike most items on this list.
- **Rival presence indicator on the map** - a tint or small flag icon on zone
  types where the Rival Company has a strong foothold, so that system shows
  up on the City map instead of living only in its own HQ screen.
- **Thief/vandal pedestrians** - mirrors the existing "tap a pedestrian to
  force a sale" mechanic. A visually distinct pedestrian (tinted, since
  pedestrians currently share one walk-sprite set and this avoids needing new
  art) walks toward a machine; tapping them before they arrive stops the
  theft/vandalism event instead of it firing automatically.
- **Machine sprite visibly degrades with condition** - today only a status
  *icon* changes as a machine's condition drops; the machine's own sprite
  stays the same.
- **New-machine "drop-in" placement animation** - a crate lowers in with a
  small bounce instead of the machine appearing instantly.
- **Truck exhaust/dust trail** while driving.

## Gameplay depth

- **City events** - a festival temporarily boosts one zone, road
  construction temporarily blocks a route. Same spirit as the existing
  weather/rush-hour systems, but visible on the map.
- **Achievements/milestones** with a dedicated badge screen.
- **Net-worth/revenue history chart** - `fl_chart` is already a dependency
  and `dailyRevenueHistory` is already tracked in game state; it just isn't
  graphed anywhere yet.

## Quality of life

- **Collect All** (HQ button) - sweeps every machine for exactly its
  recorded cash. Fast, no bonus - the "efficient" option.
- **Collect locally** (tapping a machine's money icon on the map, or
  collecting from inside the machine) - keep a small chance of a little
  extra ("someone dropped spare change near/in the machine"), so manually
  visiting machines stays worth doing even once Collect All exists, instead
  of making it strictly obsolete.
- **Sortable/filterable machine list view** - name, zone, stock, cash - as
  an alternative to hunting machines on the map.

## Already shipped this pass (for context, not part of the backlog)

- Rival Company (a competitor that grows into zone types you're thin in)
- Removed the old per-zone-type machine purchase cap - buy as many machines
  as the map has building tiles for, limited only by cash
- Quick cash collection via a floating money icon above each machine with
  cash waiting
- Fixed sound effects (coin collect, buttons, truck) interrupting other
  apps' audio (Spotify, a YouTube popup)
