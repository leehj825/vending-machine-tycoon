// The six products: base price, base demand (chance per hour that one customer buys), and
// spoilage. Sandwiches expire after three days.
export const PRODUCTS = {
  soda: { name: 'Soda', basePrice: 3.0, demand: 0.5 },
  chips: { name: 'Chips', basePrice: 2.25, demand: 0.45 },
  proteinBar: { name: 'Protein Bar', basePrice: 3.75, demand: 0.35 },
  coffee: { name: 'Coffee', basePrice: 4.5, demand: 0.4 },
  techGadget: { name: 'Tech Gadget', basePrice: 30.0, demand: 0.18 },
  sandwich: { name: 'Sandwich', basePrice: 6.5, demand: 0.38, spoilDays: 3 },
};

export const PRODUCT_IDS = Object.keys(PRODUCTS);

// The building types. demand scales a product's chance in that zone. elasticity is how much a
// price rise cuts demand: captive audiences (hospital, office) barely notice, school punishes it.
export const ZONES = {
  office: {
    name: 'Office', color: 0x6d8fb3, height: 2.2, elasticity: 0.2,
    demand: { coffee: 1.6, techGadget: 1.3, sandwich: 1.2 },
  },
  school: {
    name: 'School', color: 0xe0b84a, height: 1.4, elasticity: 0.8,
    demand: { soda: 1.4, chips: 1.4 },
  },
  gym: {
    name: 'Gym', color: 0xc96b4b, height: 1.6, elasticity: 0.5,
    demand: { proteinBar: 1.8, soda: 1.1 },
  },
  shop: {
    name: 'Shop', color: 0x9a7bb8, height: 1.2, elasticity: 0.5,
    demand: { chips: 1.2, soda: 1.1 },
  },
  hospital: {
    name: 'Hospital', color: 0xe7e7e7, height: 2.0, elasticity: 0.1,
    demand: { sandwich: 1.3 },
  },
};

export const ZONE_IDS = Object.keys(ZONES);
