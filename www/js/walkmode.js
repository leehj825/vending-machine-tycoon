// Walk mode: the player leaves the office and walks the streets. The stick walks, a drag turns
// the view (and the player with it), Talk sends a nearby walker to buy from a machine or stops a
// vandal, and Collect takes the cash from a machine that is close and in front. Also keeps the
// walkers on the streets, and sends a vandal to any machine under attack.
import { calmTorso, machineFront, inFront, samplePose, newPose } from './locomotion.js';
import { CONFIG } from './config.js';
import { makeLook, PLAYER_LOOK } from './looks.js';
import { movePlayer, newPlayer, scareWalker, sendWalker, spawnKids, spawnWalkers, stepWalker } from './walk.js';
import { seededRandom } from './world.js';
import { CONDITIONS, collectAlertOf, machineTotal } from './sim.js';

const BEACON_MAX = 8;
const beacons = [];

const TALK_REACH = 0.6;
// Seconds between a walker's own errands to a machine.
const ERRAND_GAP_MIN = 60;
const ERRAND_GAP_MAX = 120;
const COLLECT_REACH = 0.7;
// The attack combo, in order: jab, second punch, hook, kick. Each motion is played in its own
// number of seconds. The player stands still, and cannot attack again, until it is done.
const ATTACKS = [
  { clip: 'punch', seconds: 0.4 },
  { clip: 'punch2', seconds: 0.4 },
  { clip: 'hook', seconds: 0.6 },
  { clip: 'comboKick', seconds: 0.7 },
];
// Seconds after a motion ends in which the next press continues the combo; after that it starts over.
const COMBO_GAP = 0.8;

export function createWalkMode({ city, getState, clips, sale, vandal, fix, inside, say, buttons }) {
  const random = seededRandom(Date.now() % 100000);
  // Adults walk the streets; a few kids play near the schools and parks.
  const walkers = spawnWalkers(getState().city, 8, random, Array.from({ length: 8 }, () => makeLook(random)));
  walkers.push(...spawnKids(getState().city, CONFIG.kidCount, random, Array.from({ length: CONFIG.kidCount }, () => makeLook(random, 'kid')), walkers.length + 1));
  const mode = { active: false, player: null, stick: { x: 0, y: 0, id: null }, running: false };

  // Starts a walk from the road nearest the middle of town.
  function enter() {
    const grid = getState().city;
    const spawn = nearestRoad(grid, Math.floor(grid.length / 2), Math.floor(grid.length / 2));
    mode.player = newPlayer(spawn);
    mode.active = true;
    city.setWalking(true);
    buttons.show(true);
    say('You are out on the street. Walk to people and machines.');
  }

  function exit() {
    mode.active = false;
    mode.player = null;
    mode.stick = { x: 0, y: 0, id: null };
    city.setWalking(false);
    buttons.show(false);
    say('Back at the office.');
  }

  // The stick's push, turned to the ground from the camera: up walks away from the camera.
  function stickToWorld(sx, sy) {
    const yaw = city.cameraYaw();
    const rightX = Math.cos(yaw);
    const rightZ = -Math.sin(yaw);
    const forwardX = -Math.sin(yaw);
    const forwardZ = -Math.cos(yaw);
    return { dx: rightX * sx - forwardX * sy, dz: rightZ * sx - forwardZ * sy };
  }

  function nearWalker() {
    const p = mode.player;
    return walkers.find((w) => inFront(p, w.x, w.z, TALK_REACH)) || null;
  }

  function nearMachine() {
    const state = getState();
    const p = mode.player;
    for (const m of state.machines) {
      if (m.cash <= 0) continue;
      const front = machineFront(state.city, m.x, m.y);
      if (front && inFront(p, front.anchor.x, front.anchor.z, COLLECT_REACH)) return m;
    }
    return null;
  }

  // The nearest machine with stock, by straight distance from a walker.
  function machineForWalker(walker) {
    const state = getState();
    let best = null;
    let bestDistance = Infinity;
    for (const m of state.machines) {
      if (machineTotal(m) === 0) continue;
      const d = Math.hypot(m.x + 0.5 - walker.x, m.y + 0.5 - walker.z);
      if (d < bestDistance) {
        best = m;
        bestDistance = d;
      }
    }
    return best;
  }

  function talk() {
    const walker = nearWalker();
    if (!walker) return;
    if (walker.look.kid) {
      say('"I am not allowed to buy from machines!" the kid giggles.');
      return;
    }
    if (walker.attackId) {
      vandal.stop(walker.attackId);
      return;
    }
    if (walker.task) {
      say('They are already on their way somewhere.');
      return;
    }
    const machine = machineForWalker(walker);
    if (!machine) {
      say('Nowhere nearby has anything in stock.');
      return;
    }
    if (sendWalker(walker, getState().city, machine)) {
      say('"Could you point me to a machine?" They head over to buy something.');
    } else {
      say('They cannot find a way to that machine.');
    }
  }

  // The machine in front of the player, whether or not it holds cash: for opening.
  function machineInFront() {
    const state = getState();
    const p = mode.player;
    for (const m of state.machines) {
      const front = machineFront(state.city, m.x, m.y);
      if (front && inFront(p, front.anchor.x, front.anchor.z, COLLECT_REACH)) return m;
    }
    return null;
  }

  // Open swings the front of the machine in front wide open, to show its inside; pressed again, it shuts.
  function openMachine() {
    const machine = machineInFront();
    if (!machine) return;
    if (inside.isOpen(machine.id)) inside.close();
    else inside.open(machine.id);
  }

  function collect() {
    const machine = nearMachine();
    if (machine) sale.collect(machine.id);
  }

  // A broken machine within reach and in front of the player, to fix.
  function nearBroken() {
    const state = getState();
    const p = mode.player;
    for (const m of state.machines) {
      if (m.condition !== CONDITIONS.length - 1) continue;
      const front = machineFront(state.city, m.x, m.y);
      if (front && inFront(p, front.anchor.x, front.anchor.z, COLLECT_REACH)) return m;
    }
    return null;
  }

  function fixNearby() {
    const machine = nearBroken();
    if (machine) fix.repair(machine.id);
  }

  // A machine needs attention when a vandal is at it or it is broken: its arrow is red.
  function isAlarm(state, m) {
    return m.condition === CONDITIONS.length - 1 || (state.attacks ?? []).some((a) => a.machineId === m.id);
  }

  // Town life: a walker with nothing to do now and then goes to buy from the nearest machine.
  function errands(w, dt) {
    if (w.task || w.attackId || w.fleeT > 0 || w.look.kid) return;
    if (w.errandIn === undefined) w.errandIn = ERRAND_GAP_MIN + random() * (ERRAND_GAP_MAX - ERRAND_GAP_MIN);
    w.errandIn -= dt;
    if (w.errandIn > 0) return;
    w.errandIn = ERRAND_GAP_MIN + random() * (ERRAND_GAP_MAX - ERRAND_GAP_MIN);
    const machine = machineForWalker(w);
    if (machine) sendWalker(w, getState().city, machine);
  }

  // Each machine under attack gets a vandal: the nearest free walker goes to it and kicks.
  function dispatchVandals(state) {
    for (const attack of state.attacks ?? []) {
      if (walkers.some((w) => w.attackId === attack.id)) continue;
      const machine = state.machines.find((m) => m.id === attack.machineId);
      if (!machine) {
        vandal.finish(attack.id);
        continue;
      }
      const distance = (w) => Math.hypot(machine.x + 0.5 - w.x, machine.y + 0.5 - w.z);
      const free = walkers.filter((w) => !w.attackId && !w.task && !w.kicking && !w.look.kid).sort((a, b) => distance(a) - distance(b));
      if (free.length === 0) return;
      const sent = free.find((w) => {
        if (!sendWalker(w, state.city, machine)) return false;
        w.task.attackId = attack.id;
        w.attackId = attack.id;
        return true;
      });
      // No walker can get there: the attack lands without a vandal in sight.
      if (!sent) vandal.finish(attack.id);
    }
  }

  // A vandal at the machine turns to it and kicks until the attack ends.
  function startKick(w, arrived, state) {
    const machine = state.machines.find((m) => m.id === arrived.machineId);
    const front = machine ? machineFront(state.city, machine.x, machine.y) : null;
    if (front) w.facing = Math.atan2(front.anchor.x - w.x, front.anchor.z - w.z);
    w.kicking = true;
    w.kickPhase = 0;
    vandal.beginKick(arrived.attackId);
  }

  // A vandal whose attack has ended (talked out of it, or it landed) goes back to the streets.
  function releaseIfGone(w, state) {
    if (!w.attackId) return;
    if ((state.attacks ?? []).some((a) => a.id === w.attackId)) return;
    w.attackId = null;
    w.kicking = false;
    if (w.task?.attackId) {
      w.task = null;
      w.path = [];
    }
  }

  // Frame update: the walkers always walk; the player walks only in walk mode.
  function frame(dt) {
    const state = getState();
    const grid = state.city;
    dispatchVandals(state);
    for (const w of walkers) {
      releaseIfGone(w, state);
      if (w.kicking) {
        w.kickPhase += dt / clips.clips.kick.d;
        continue;
      }
      errands(w, dt);
      const arrived = stepWalker(w, grid, dt, random);
      if (!arrived) continue;
      if (arrived.attackId) startKick(w, arrived, state);
      else sale.walkerBuys(arrived.machineId);
    }
    if (mode.active && mode.player) {
      const player = mode.player;
      updateAttack(player, dt);
      player.facing = city.walkFacing();
      const move = player.punchT > 0 ? { dx: 0, dz: 0 } : stickToWorld(mode.stick.x, mode.stick.y);
      movePlayer(player, grid, clips, move.dx, move.dz, dt);
      city.follow(player.x, player.z);
      updateButtons();
      updateBeacons(state, mode.player);
    }
    const people = [];
    if (mode.active && mode.player) {
      people.push({
        key: 'player',
        x: mode.player.x,
        z: mode.player.z,
        yaw: mode.player.facing,
        pose: mode.player.punchT > 0 ? punchPose(mode.player) : posed(mode.player.moving, mode.player.clip, mode.player.phase),
        look: PLAYER_LOOK,
      });
    }
    for (const w of walkers) {
      people.push({
        key: `w${w.id}`,
        x: w.x,
        z: w.z,
        yaw: w.facing,
        pose: w.kicking ? posed(true, 'kick', w.kickPhase) : posed(true, w.fleeT > 0 ? 'run' : 'walk', w.phase),
        look: w.look,
      });
    }
    city.drawPeople(people);
  }

  function posed(moving, clipKey, phase) {
    const pose = newPose();
    if (!moving) return pose;
    samplePose(clips.clips[clipKey], phase, pose);
    // Running swings the arms without twisting the whole body.
    return clipKey.toLowerCase().includes('run') ? calmTorso(pose, 0.4) : pose;
  }

  // The attack motion now playing: its clip, played once over its length.
  function punchPose(player) {
    const clip = clips.clips[player.punchClip];
    const progress = Math.min(0.999, 1 - player.punchT / player.punchTotal);
    return samplePose(clip, progress, newPose());
  }

  // Counts the motion down. When it ends, the combo waits a moment for the next press.
  function updateAttack(player, dt) {
    if (player.punchT > 0) {
      player.punchT = Math.max(0, player.punchT - dt);
      if (player.punchT === 0) player.comboT = COMBO_GAP;
    } else if (player.comboT > 0) {
      player.comboT = Math.max(0, player.comboT - dt);
      if (player.comboT === 0) player.punchStep = 0;
    }
  }

  // A vandal (kicking, or on the way to kick) within reach and in front of the player, to punch.
  function nearVandal() {
    const p = mode.player;
    return walkers.find((w) => w.attackId && inFront(p, w.x, w.z, TALK_REACH)) || null;
  }

  // Attack swings at all times. A vandal in front is punched and the attack ends; any other
  // passer-by in front is shoved and runs off; with nobody there, the punch hits the air.
  function attack() {
    const child = nearWalker();
    if (child?.look.kid) {
      say('Leave the kids alone!');
      return;
    }
    const player = mode.player;
    if (player.punchT > 0) return; // one motion at a time: the next waits for this one to finish
    const move = ATTACKS[player.punchStep];
    player.punchStep = (player.punchStep + 1) % ATTACKS.length;
    player.punchClip = move.clip;
    player.punchTotal = move.seconds;
    player.punchT = move.seconds;
    player.comboT = 0;
    const vandalWalker = nearVandal();
    if (vandalWalker) {
      vandal.punch(vandalWalker.attackId);
      return;
    }
    const walker = nearWalker();
    if (walker) {
      scareWalker(walker, mode.player);
      say('You shove them. They run off.');
    }
  }

  function updateButtons() {
    buttons.setTalk(Boolean(nearWalker()));
    buttons.setCollect(Boolean(nearMachine()));
    buttons.setFix(Boolean(nearBroken()));
    buttons.setOpen(Boolean(machineInFront()));
  }

  // Arrows around the player, one per nearby machine holding more cash than HQ's threshold.
  // Each arrow sits on a ring and points the way to its machine, as seen on screen.
  function updateBeacons(state, player) {
    const yaw = city.cameraYaw();
    const rightX = Math.cos(yaw);
    const rightZ = -Math.sin(yaw);
    const forwardX = -Math.sin(yaw);
    const forwardZ = -Math.cos(yaw);
    const alert = collectAlertOf(state);
    const targets = state.machines
      .filter((m) => m.cash > alert || isAlarm(state, m))
      .map((m) => {
        const dx = m.x + 0.5 - player.x;
        const dz = m.y + 0.5 - player.z;
        return {
          distance: Math.hypot(dx, dz),
          angle: Math.atan2(dx * rightX + dz * rightZ, dx * forwardX + dz * forwardZ),
          warn: isAlarm(state, m),
        };
      })
      .sort((a, b) => a.distance - b.distance)
      .slice(0, BEACON_MAX);
    const el = buttons.beaconsEl;
    const radius = Math.min(el.clientWidth, el.clientHeight) * 0.32;
    while (beacons.length < targets.length) {
      const holder = document.createElement('div');
      holder.className = 'beacon';
      holder.innerHTML = '<span>▲</span>';
      el.appendChild(holder);
      beacons.push(holder);
    }
    beacons.forEach((holder, i) => {
      if (i >= targets.length) {
        holder.hidden = true;
        return;
      }
      holder.hidden = false;
      holder.classList.toggle('warn', targets[i].warn);
      holder.style.transform = `rotate(${(targets[i].angle * 180) / Math.PI}deg)`;
      holder.firstChild.style.top = `${-radius - 12}px`;
    });
  }

  // Stick: a pointer that starts on the stick steers until it lifts.
  const stickEl = buttons.stick;
  const knob = buttons.knob;
  const radius = 50;
  function stickMove(clientX, clientY) {
    const r = stickEl.getBoundingClientRect();
    let dx = clientX - (r.left + r.width / 2);
    let dy = clientY - (r.top + r.height / 2);
    const d = Math.hypot(dx, dy);
    if (d > radius) {
      dx *= radius / d;
      dy *= radius / d;
    }
    knob.style.transform = `translate(${dx}px, ${dy}px)`;
    mode.stick.x = dx / radius;
    mode.stick.y = dy / radius;
  }
  function stickRelease() {
    mode.stick.id = null;
    mode.stick.x = 0;
    mode.stick.y = 0;
    knob.style.transform = '';
  }
  stickEl.addEventListener('pointerdown', (e) => {
    mode.stick.id = e.pointerId;
    stickEl.setPointerCapture(e.pointerId);
    stickMove(e.clientX, e.clientY);
  });
  stickEl.addEventListener('pointermove', (e) => {
    if (e.pointerId === mode.stick.id) stickMove(e.clientX, e.clientY);
  });
  const endStick = (e) => {
    if (e.pointerId === mode.stick.id) stickRelease();
  };
  stickEl.addEventListener('pointerup', endStick);
  stickEl.addEventListener('pointercancel', endStick);
  // A lost release must not keep the player walking: the window also ends the hold.
  window.addEventListener('pointerup', endStick);
  window.addEventListener('pointercancel', endStick);

  // The action buttons act on touch-down, so they work while another finger holds the stick.
  buttons.talkEl.addEventListener('pointerdown', talk);
  buttons.collectEl.addEventListener('pointerdown', collect);
  buttons.fixEl.addEventListener('pointerdown', fixNearby);
  buttons.attackEl.addEventListener('pointerdown', attack);
  buttons.openEl.addEventListener('pointerdown', openMachine);
  buttons.runEl.addEventListener('pointerdown', () => {
    mode.running = !mode.running;
    if (mode.player) mode.player.running = mode.running;
    buttons.setRun(mode.running);
  });
  buttons.officeEl.addEventListener('pointerdown', exit);

  return {
    enter,
    exit,
    frame,
    // The id of the machine in front of the player, or null.
    frontMachineId: () => machineInFront()?.id ?? null,
    get active() {
      return mode.active;
    },
  };
}

function nearestRoad(grid, x, y) {
  let best = null;
  let bestDistance = Infinity;
  grid.forEach((row, cy) => row.forEach((cell, cx) => {
    if (cell.type !== 'road') return;
    const d = Math.hypot(cx - x, cy - y);
    if (d < bestDistance) {
      best = { x: cx, y: cy };
      bestDistance = d;
    }
  }));
  return best;
}
