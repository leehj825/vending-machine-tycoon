// Economy and rules. The values follow the design in README.md, as the Flutter version had them.
export const CONFIG = {
  gridSize: 15,
  startingCash: 2000,
  startingReputation: 100,
  machinePrice: 400,
  truckPrice: 500,
  truckCapacity: 500,
  warehouseCapacity: 1000,
  machineCapacity: 50,
  machinePerProduct: 20,
  ticksPerHour: 125,
  hoursPerDay: 24,
  tickMs: 100,
  // Warehouse cost per unit, as a share of the product's base price.
  wholesaleShare: 0.5,
  priceMultiplierMin: 0.5,
  priceMultiplierMax: 2.0,
  priceMultiplierStep: 0.1,
  reputationGainPerSale: 1,
  emptyGraceHours: 4,
  emptyPenaltyPerHour: 5,
  // Sales rate rises 5% per 100 reputation, up to +50%.
  reputationBonusPer100: 0.05,
  maxReputationBonus: 0.5,
  fuelCostPerDistance: 0.05,
  truckSpeed: 1.5,
  // Thrown out per expired item.
  disposalCostPerItem: 0.5,
  // Theft and vandalism, each hour a machine may be targeted.
  securityBaseHourlyChance: 0.003,
  nightMultiplier: 3,
  nightStartHour: 22,
  nightEndHour: 5,
  // Extra chance per 100 of cash in the machine, up to 1.
  cashRiskPer100: 0.05,
  cashRiskCap: 1.0,
  // Share of targeted machines robbed (when they hold cash); the rest are vandalized.
  theftShare: 0.65,
  // A robbery takes this share of the cash in the machine.
  theftCashMin: 0.5,
  theftCashMax: 1.0,
  securityCost: 400,
  securityRiskFactor: 0.35,
  securityPenaltyFactor: 0.5,
  repairCostPerLevel: 150,
  saveKey: 'vending_tycoon_save_v2',
};
