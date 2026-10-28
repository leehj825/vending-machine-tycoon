// How people look: skin, hair, clothes and a few extras, picked from the palettes below. Plain
// data, no drawing: figure.js turns a look into a model. A look is chosen once per person, so they
// look the same every time.
export const SKIN_TONES = [0xf1c9a0, 0xe2b88e, 0xc68e63, 0xa86f46, 0x7a4a2a, 0x4e2f1d];
export const HAIR_COLOURS = [0x1d1412, 0x3e2723, 0x6d4c41, 0xd7a94b, 0xc0562f, 0x9e9e9e];
export const SHIRTS = [0xd9534f, 0x5bc0de, 0x5cb85c, 0x9b59b6, 0xe67e22, 0xecf0f1, 0xf06292, 0x26a69a, 0xffca28, 0x5c6bc0];
export const PANTS = [0x3b5b8c, 0x4b4036, 0x2f3542, 0x8a7f66, 0x5d4a7a, 0x37474f];
export const TIES = [0xc62828, 0x1565c0, 0x2e7d32, 0xf9a825];

// The hair styles, by who wears them. Women's and men's styles overlap a little in the world; here
// they are kept apart so a crowd reads at a glance. Every style is built of blocks in figure.js.
export const MEN_HAIR = ['crop', 'sidePart', 'buzz', 'spiky', 'bald', 'cap'];
export const WOMEN_HAIR = ['ponytail', 'long', 'bob', 'bun', 'braids', 'curly'];
export const GIRL_HAIR = ['pigtails', 'bowl', 'ponytail'];
export const BOY_HAIR = ['cap', 'spiky', 'bowl'];

// The player: a yellow shirt, so they stand out.
export const PLAYER_LOOK = {
  shirt: 0xffeb3b, pants: 0x3b5b8c, skin: 0xe2b88e, hair: 0x3e2723, hairStyle: 'sidePart', cap: 0xe53935,
  glasses: false, beard: false, moustache: false, tie: null, stripe: false, kid: false,
};

// A random look for an adult or a kid. `random` returns 0 to 1.
export function makeLook(random, kind = 'adult') {
  const pick = (list) => list[Math.floor(random() * list.length)];
  const kid = kind === 'kid';
  const woman = random() < 0.5;
  const hairStyle = kid ? pick(woman ? GIRL_HAIR : BOY_HAIR) : pick(woman ? WOMEN_HAIR : MEN_HAIR);
  const man = !kid && !woman;
  return {
    shirt: pick(SHIRTS),
    pants: pick(PANTS),
    skin: pick(SKIN_TONES),
    hair: pick(HAIR_COLOURS),
    hairStyle,
    // The colour of a cap, or of a hair tie or band.
    cap: pick(SHIRTS),
    glasses: !kid && random() < 0.2,
    beard: man && random() < 0.2,
    moustache: man && random() < 0.12,
    tie: man && random() < 0.2 ? pick(TIES) : null,
    stripe: random() < 0.25,
    kid,
  };
}
