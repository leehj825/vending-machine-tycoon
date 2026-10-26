// Economy and rules. The values follow the design in README.md, as the Flutter version had them.
export const CONFIG = {
  gridSize: 15,
  startingCash: 2000,
  startingReputation: 100,
  machinePrice: 400,
  // Walking shows an arrow to each machine holding more than this much cash. HQ changes it.
  collectAlertStart: 50,
  collectAlertStep: 25,
  collectAlertMax: 1000,
  // Share of the blocks' buildings that are shop fronts. The rest are houses, for looking at.
  shopFrontShare: 0.3,
  // Share of the blocks' other buildings that are houses. The rest are parks or grass.
  houseShare: 0.12,
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
  // A broken machine (4 levels) costs 300 to repair, less than the 400 a new one costs.
  repairCostPerLevel: 75,
  // Wear: a machine wears a little each hour (more in risky zones and at night), and a kicker
  // wears it faster. Each full step of wear lowers its condition by one.
  wearPerHour: 0.6,
  wearPerKickSecond: 2,
  wearLimit: 100,
  // Each day a working machine may break down: the chance grows with its condition.
  breakdownChancePerDay: 0.03,
  brokenReputationPenalty: 1,
  // Weather changes each day. Sales and breakdown chances change with it.
  weather: {
    sunny: { label: 'Sunny', sales: 1.1, breakdown: 1 },
    cloudy: { label: 'Cloudy', sales: 1, breakdown: 1 },
    rainy: { label: 'Rainy', sales: 0.85, breakdown: 1.5 },
    stormy: { label: 'Stormy', sales: 0.7, breakdown: 2 },
  },
  // Each day the warehouse price of a product moves by up to this share, within the limits.
  marketDrift: 0.05,
  marketMin: 0.8,
  marketMax: 1.25,
  // Most vandals that can be kicking one machine at once.
  maxKickersPerMachine: 3,
  // Reputation lost for each punch: passers-by see it.
  punchReputationCost: 2,
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
    // Rewarded video: watching it to the end gives a free restock run once a day (Flutter's IDs).
    rewardedId: 'ca-app-pub-4400173019354346/8820412223',
    rewardedTestId: 'ca-app-pub-3940256099942544/5224354917',
  },
  saveKey: 'vending_tycoon_save_v2',
};
