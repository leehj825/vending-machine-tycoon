# Reputation System - Complete Guide

## Overview

Reputation now affects both sales rates and can be gained through sales. This creates a positive feedback loop where good performance leads to better sales.

---

## Reputation Gain

### How to Gain Reputation

**From Sales:**
- **+1 reputation per sale**
- Every item sold increases your reputation by 1 point
- This happens automatically every tick when sales occur

**Example:**
- Sell 10 items in one tick = +10 reputation
- Sell 100 items over time = +100 reputation

### Reputation Loss

**From Empty Machines:**
- Machines empty for **4+ hours** start losing reputation
- **-5 reputation per hour** per empty machine (after the 4-hour grace period)
- Formula: `penalty = (hoursEmpty - 4) × 5`

**Example:**
- 1 machine empty for 5 hours = -5 reputation per tick
- 2 machines empty for 6 hours each = -20 reputation per tick

---

## Reputation-Based Sales Bonus

### How It Works

**Every 100 reputation = +5% sales rate bonus**

- **0-99 reputation**: No bonus (1.0x multiplier)
- **100-199 reputation**: +5% bonus (1.05x multiplier)
- **200-299 reputation**: +10% bonus (1.10x multiplier)
- **300-399 reputation**: +15% bonus (1.15x multiplier)
- **400-499 reputation**: +20% bonus (1.20x multiplier)
- **500-599 reputation**: +25% bonus (1.25x multiplier)
- **600-699 reputation**: +30% bonus (1.30x multiplier)
- **700-799 reputation**: +35% bonus (1.35x multiplier)
- **800-899 reputation**: +40% bonus (1.40x multiplier)
- **900-999 reputation**: +45% bonus (1.45x multiplier)
- **1000 reputation**: +50% bonus (1.50x multiplier) - **MAXIMUM**

### Updated Sales Formula

**Before:**
```
saleChancePerHour = baseDemand × zoneMultiplier × trafficMultiplier
```

**After:**
```
saleChancePerHour = baseDemand × zoneMultiplier × trafficMultiplier × reputationMultiplier
```

Where:
- `reputationMultiplier = 1.0 + (reputation / 100) × 0.05`
- Capped at 1.50 (50% bonus maximum)

---

## Real-World Examples

### Example 1: Soda in Office Zone at 8 AM

**Base calculation:**
- Base Demand: 40%
- Zone Multiplier: 2.0x (8 AM peak)
- Traffic Multiplier: 1.2x
- **Base result**: 40% × 2.0 × 1.2 = **96% per hour**

**With reputation bonuses:**
- **100 reputation**: 96% × 1.05 = **100.8% per hour** (+4.8%)
- **300 reputation**: 96% × 1.15 = **110.4% per hour** (+15%)
- **500 reputation**: 96% × 1.25 = **120% per hour** (+25%)
- **1000 reputation**: 96% × 1.50 = **144% per hour** (+50%)

### Example 2: Tech Gadget in Office Zone at 8 AM

**Base calculation:**
- Base Demand: 14%
- Zone Multiplier: 2.0x
- Traffic Multiplier: 1.2x
- **Base result**: 14% × 2.0 × 1.2 = **33.6% per hour**

**With reputation bonuses:**
- **100 reputation**: 33.6% × 1.05 = **35.3% per hour** (+1.7%)
- **500 reputation**: 33.6% × 1.25 = **42% per hour** (+8.4%)
- **1000 reputation**: 33.6% × 1.50 = **50.4% per hour** (+16.8%)

---

## Strategy Implications

### Positive Feedback Loop

1. **Sell items** → Gain reputation
2. **Higher reputation** → Faster sales
3. **Faster sales** → More reputation
4. **More reputation** → Even faster sales

### Managing Reputation

**To maximize reputation:**
- Keep machines well-stocked (avoid empty machines)
- Make frequent sales (each sale = +1 reputation)
- Monitor machines to prevent them from going empty

**Reputation decay:**
- Empty machines for 4+ hours will reduce reputation
- Multiple empty machines compound the penalty
- Keep machines stocked to maintain high reputation

---

## Reputation Ranges

| Reputation | Sales Bonus | Status |
|------------|-------------|--------|
| 0-99 | 0% | Poor |
| 100-199 | +5% | Fair |
| 200-299 | +10% | Good |
| 300-399 | +15% | Very Good |
| 400-499 | +20% | Excellent |
| 500-599 | +25% | Outstanding |
| 600-699 | +30% | Exceptional |
| 700-799 | +35% | Elite |
| 800-899 | +40% | Master |
| 900-999 | +45% | Legendary |
| 1000 | +50% | **MAXIMUM** |

---

## Summary

- **Gain reputation**: +1 per sale
- **Lose reputation**: -5 per hour per empty machine (after 4-hour grace period)
- **Sales bonus**: +5% per 100 reputation (max +50% at 1000)
- **Range**: 0 to 1000
- **Starting**: 100 reputation

The reputation system now creates a meaningful progression where maintaining good service (keeping machines stocked) and making sales both contribute to better performance!

