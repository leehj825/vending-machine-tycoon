// Economy and rules. The values follow the design in README.md, as the Flutter version had them.
export const CONFIG = {
  gridSize: 15,
  startingCash: 2000,
  startingReputation: 100,
  machinePrice: 400,
  // Share of the blocks' buildings that are shop fronts. The rest are houses, for looking at.
  shopFrontShare: 0.3,
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
  // Seconds a vandal kicks a machine before it is vandalized. Talking to them stops it sooner.
  vandalKickSeconds: 12,
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
  // The rival company, by zone type. Presence grows each day, fastest where you are absent.
  rivalMaxPresence: 0.75,
  rivalBaseDailyGrowth: 0.04,
  rivalResistancePerMachine: 0.18,
  rivalMinGrowthShare: 0.12,
  // A rival at full strength cuts sales by up to this much.
  rivalMaxSalesCut: 0.45,
  rivalSalesCutPerPresence: 0.6,
  rivalCounterBaseCost: 1500,
  rivalCounterCostPerPresence: 3000,
  rivalCounterReduction: 0.3,
  // Research, one purchase each.
  research: {
    turboTrucks: { name: 'Turbo Logistics', cost: 2000, text: 'Trucks move 25% faster.' },
    premiumBranding: { name: 'Premium Branding', cost: 5000, text: 'Prices 10% higher, with no loss of customers.' },
    efficientCooling: { name: 'Efficient Cooling', cost: 3000, text: 'Halves spoilage.' },
  },
  turboSpeedFactor: 1.25,
  premiumPriceFactor: 1.1,
  coolingSpoilageFactor: 0.5,
  // Machine upgrades.
  capacityUpgradeCost: 500,
  capacityUpgradeSlots: 25,
  capacityUpgradeMaxLevel: 2,
  coolingUpgradeCost: 800,
  adDisplayCost: 1000,
  adDisplayDailyIncome: 10,
  // Rush Hour: an ad campaign fills the hype meter; a full meter starts an hour of 10× sales.
  campaignCost: 200,
  campaignHype: 0.25,
  rushMultiplier: 10,
  rushTicks: 125,
  // AdMob, as in the original app. The banner sits at the top of the screen, inside the Android app
  // only. Set testing to true while you check the layout: live ads must not be clicked by their owner.
  admob: {
    bannerId: 'ca-app-pub-4400173019354346/5798507534',
    testBannerId: 'ca-app-pub-3940256099942544/6300978111',
    testing: false,
  },
  saveKey: 'vending_tycoon_save_v2',
};
