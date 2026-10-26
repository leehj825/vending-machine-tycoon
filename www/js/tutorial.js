// The first-day guide: a short banner that walks a new player through their first machine. Each
// step waits for something the player does; the banner can be skipped at any time. A game saved
// before the guide existed counts as done (see migrateState).
export const STEPS = [
  { text: 'Tap a glowing ball over a shop front to buy your first machine.', machines: 1 },
  { text: 'Press Walk to go out onto the street, then walk to your machine.', event: 'walk' },
  { text: 'Stand in front of the machine and press Open.', event: 'open' },
  { text: 'Press Refill to fill it from the warehouse.', event: 'refill' },
  { text: 'Customers will buy. When coins show over the machine, open it and press Take cash.', event: 'collect' },
  { text: 'Well done! As you grow, hire help in HQ under Staff.', event: 'done', button: 'Got it' },
];

export const TUTORIAL_DONE = STEPS.length;

// The text to show now, or null once the guide is done.
export function tutorialStep(state) {
  return STEPS[state.tutorialStep] ?? null;
}

// Something the player did. Moves on when it is what the current step waits for.
export function tutorialEvent(state, event) {
  const step = tutorialStep(state);
  if (!step || step.event !== event) return false;
  state.tutorialStep += 1;
  return true;
}

// The steps that wait on the state rather than an event: owning enough machines.
export function tutorialCheck(state) {
  const step = tutorialStep(state);
  if (step?.machines && state.machines.length >= step.machines) {
    state.tutorialStep += 1;
    return true;
  }
  return false;
}

export function skipTutorial(state) {
  state.tutorialStep = TUTORIAL_DONE;
}
