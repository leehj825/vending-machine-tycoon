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

// The building types, as the original game had them. color is the zone's colour, used for its
// machines. height is the building's body height. crime scales the theft and vandalism risk.
// demand scales a product's chance in that zone. elasticity is how much a price rise cuts demand:
// captive audiences (hospital, office) barely notice, school punishes it.
export const ZONES = {
  shop: {
    name: 'Shop', color: 0x2196f3, height: 0.55, crime: 1.2, elasticity: 0.5,
    demand: { chips: 1.2, soda: 1.1 },
  },
  school: {
    name: 'School', color: 0x9c27b0, height: 0.5, crime: 1.6, elasticity: 0.8,
    demand: { soda: 1.4, chips: 1.4 },
  },
  gym: {
    name: 'Gym', color: 0xff9800, height: 0.7, crime: 1.0, elasticity: 0.5,
    demand: { proteinBar: 1.8, soda: 1.1 },
  },
  office: {
    name: 'Office', color: 0x2196f3, height: 1.5, crime: 0.6, elasticity: 0.2,
    demand: { coffee: 1.6, techGadget: 1.3, sandwich: 1.2 },
  },
  subway: {
    name: 'Subway', color: 0x607d8b, height: 0.32, crime: 1.8, elasticity: 0.6,
    demand: { coffee: 1.2, chips: 1.2 },
  },
  hospital: {
    name: 'Hospital', color: 0xf44336, height: 0.9, crime: 0.5, elasticity: 0.1,
    demand: { sandwich: 1.3 },
  },
  university: {
    name: 'University', color: 0x3f51b5, height: 0.72, crime: 1.1, elasticity: 0.4,
    demand: { coffee: 1.3, techGadget: 1.3 },
  },
};

export const ZONE_IDS = Object.keys(ZONES);
