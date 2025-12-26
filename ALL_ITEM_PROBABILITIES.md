# Complete Item Sale Probabilities

## Base Demand Values

| Product | Base Demand | Base Price |
|---------|-------------|------------|
| **Soda** | 30.0% per hour | $2.50 |
| **Chips** | 25.0% per hour | $1.75 |
| **Protein Bar** | 16.0% per hour | $3.00 |
| **Coffee** | 20.0% per hour | $3.50 |
| **Tech Gadget** | 4.0% per hour | $25.00 |
| **Sandwich** | 18.0% per hour | $5.50 |

---

## OFFICE ZONE
**Traffic Multiplier:** 1.2x

### Demand Curve by Hour:
- **8 AM**: 2.0x (Peak coffee demand)
- **10 AM**: 1.2x
- **12 PM**: 1.5x (Lunch rush)
- **2 PM**: 1.5x (Post-lunch coffee)
- **4 PM**: 1.0x (Normal)
- **6 PM**: 0.5x (Winding down)
- **8 PM**: 0.1x (Dead)

### Sale Probabilities Per Hour:

| Product | 8 AM | 10 AM | 12 PM | 2 PM | 4 PM | 6 PM | 8 PM |
|---------|------|-------|-------|------|------|------|------|
| **Soda** | 72.0% | 43.2% | 54.0% | 54.0% | 36.0% | 18.0% | 3.6% |
| **Chips** | 60.0% | 36.0% | 45.0% | 45.0% | 30.0% | 15.0% | 3.0% |
| **Protein Bar** | 38.4% | 23.0% | 28.8% | 28.8% | 19.2% | 9.6% | 1.9% |
| **Coffee** | 48.0% | 28.8% | 36.0% | 36.0% | 24.0% | 12.0% | 2.4% |
| **Tech Gadget** | 9.6% | 5.8% | 7.2% | 7.2% | 4.8% | 2.4% | 0.5% |
| **Sandwich** | 43.2% | 25.9% | 32.4% | 32.4% | 21.6% | 10.8% | 2.2% |

### Per-Tick Probabilities (125 ticks/hour):

| Product | 8 AM | 10 AM | 12 PM | 2 PM | 4 PM | 6 PM | 8 PM |
|---------|------|-------|-------|------|------|------|------|
| **Soda** | 0.576% | 0.346% | 0.432% | 0.432% | 0.288% | 0.144% | 0.029% |
| **Chips** | 0.480% | 0.288% | 0.360% | 0.360% | 0.240% | 0.120% | 0.024% |
| **Protein Bar** | 0.307% | 0.184% | 0.230% | 0.230% | 0.154% | 0.077% | 0.015% |
| **Coffee** | 0.384% | 0.230% | 0.288% | 0.288% | 0.192% | 0.096% | 0.019% |
| **Tech Gadget** | 0.077% | 0.046% | 0.058% | 0.058% | 0.038% | 0.019% | 0.004% |
| **Sandwich** | 0.346% | 0.207% | 0.259% | 0.259% | 0.173% | 0.086% | 0.017% |

---

## SCHOOL ZONE
**Traffic Multiplier:** 1.0x

### Demand Curve by Hour:
- **7 AM**: 1.8x (Before school)
- **12 PM**: 2.0x (Lunch peak)
- **3 PM**: 1.5x (After school)
- **6 PM**: 0.3x (Empty)

### Sale Probabilities Per Hour:

| Product | 7 AM | 12 PM | 3 PM | 6 PM |
|---------|------|-------|------|------|
| **Soda** | 54.0% | 60.0% | 45.0% | 9.0% |
| **Chips** | 45.0% | 50.0% | 37.5% | 7.5% |
| **Protein Bar** | 28.8% | 32.0% | 24.0% | 4.8% |
| **Coffee** | 36.0% | 40.0% | 30.0% | 6.0% |
| **Tech Gadget** | 7.2% | 8.0% | 6.0% | 1.2% |
| **Sandwich** | 32.4% | 36.0% | 27.0% | 5.4% |

### Per-Tick Probabilities (125 ticks/hour):

| Product | 7 AM | 12 PM | 3 PM | 6 PM |
|---------|------|-------|------|------|
| **Soda** | 0.432% | 0.480% | 0.360% | 0.072% |
| **Chips** | 0.360% | 0.400% | 0.300% | 0.060% |
| **Protein Bar** | 0.230% | 0.256% | 0.192% | 0.038% |
| **Coffee** | 0.288% | 0.320% | 0.240% | 0.048% |
| **Tech Gadget** | 0.058% | 0.064% | 0.048% | 0.010% |
| **Sandwich** | 0.259% | 0.288% | 0.216% | 0.043% |

---

## GYM ZONE
**Traffic Multiplier:** 0.9x

### Demand Curve by Hour:
- **6 AM**: 1.5x (Morning workout)
- **12 PM**: 1.2x (Lunch workout)
- **6 PM**: 2.0x (Evening peak)
- **9 PM**: 1.5x (Late evening)

### Sale Probabilities Per Hour:

| Product | 6 AM | 12 PM | 6 PM | 9 PM |
|---------|------|-------|------|------|
| **Soda** | 40.5% | 32.4% | 54.0% | 40.5% |
| **Chips** | 33.8% | 27.0% | 45.0% | 33.8% |
| **Protein Bar** | 21.6% | 17.3% | 28.8% | 21.6% |
| **Coffee** | 27.0% | 21.6% | 36.0% | 27.0% |
| **Tech Gadget** | 5.4% | 4.3% | 7.2% | 5.4% |
| **Sandwich** | 24.3% | 19.4% | 32.4% | 24.3% |

### Per-Tick Probabilities (125 ticks/hour):

| Product | 6 AM | 12 PM | 6 PM | 9 PM |
|---------|------|-------|------|------|
| **Soda** | 0.324% | 0.259% | 0.432% | 0.324% |
| **Chips** | 0.270% | 0.216% | 0.360% | 0.270% |
| **Protein Bar** | 0.173% | 0.138% | 0.230% | 0.173% |
| **Coffee** | 0.216% | 0.173% | 0.288% | 0.216% |
| **Tech Gadget** | 0.043% | 0.035% | 0.058% | 0.043% |
| **Sandwich** | 0.194% | 0.155% | 0.259% | 0.194% |

---

## SHOP ZONE
**Traffic Multiplier:** 1.2x

### Demand Curve by Hour:
- **10 AM**: 1.5x (Morning shoppers)
- **12 PM**: 2.0x (Lunch rush)
- **3 PM**: 1.8x (Afternoon shopping)
- **6 PM**: 1.5x (Evening shoppers)
- **8 PM**: 1.0x (Normal)
- **10 PM**: 0.5x (Late night)

### Sale Probabilities Per Hour:

| Product | 10 AM | 12 PM | 3 PM | 6 PM | 8 PM | 10 PM |
|---------|-------|-------|------|------|------|-------|
| **Soda** | 54.0% | 72.0% | 64.8% | 54.0% | 36.0% | 18.0% |
| **Chips** | 45.0% | 60.0% | 54.0% | 45.0% | 30.0% | 15.0% |
| **Protein Bar** | 28.8% | 38.4% | 34.6% | 28.8% | 19.2% | 9.6% |
| **Coffee** | 36.0% | 48.0% | 43.2% | 36.0% | 24.0% | 12.0% |
| **Tech Gadget** | 7.2% | 9.6% | 8.6% | 7.2% | 4.8% | 2.4% |
| **Sandwich** | 32.4% | 43.2% | 38.9% | 32.4% | 21.6% | 10.8% |

### Per-Tick Probabilities (125 ticks/hour):

| Product | 10 AM | 12 PM | 3 PM | 6 PM | 8 PM | 10 PM |
|---------|-------|-------|------|------|------|-------|
| **Soda** | 0.432% | 0.576% | 0.518% | 0.432% | 0.288% | 0.144% |
| **Chips** | 0.360% | 0.480% | 0.432% | 0.360% | 0.240% | 0.120% |
| **Protein Bar** | 0.230% | 0.307% | 0.277% | 0.230% | 0.154% | 0.077% |
| **Coffee** | 0.288% | 0.384% | 0.346% | 0.288% | 0.192% | 0.096% |
| **Tech Gadget** | 0.058% | 0.077% | 0.069% | 0.058% | 0.038% | 0.019% |
| **Sandwich** | 0.259% | 0.346% | 0.311% | 0.259% | 0.173% | 0.086% |

---

## Summary: Best Selling Times

### Highest Probability Combinations:

1. **Soda in Shop Zone at 12 PM**: 72.0% per hour
2. **Soda in Office Zone at 8 AM**: 72.0% per hour
3. **Chips in Shop Zone at 12 PM**: 60.0% per hour
4. **Chips in School Zone at 12 PM**: 50.0% per hour
5. **Coffee in Office Zone at 8 AM**: 48.0% per hour

### Lowest Probability Combinations:

1. **Tech Gadget in Office Zone at 8 PM**: 0.5% per hour
2. **Tech Gadget in School Zone at 6 PM**: 1.2% per hour
3. **Protein Bar in Office Zone at 8 PM**: 1.9% per hour
4. **Sandwich in Office Zone at 8 PM**: 2.2% per hour
5. **Coffee in Office Zone at 8 PM**: 2.4% per hour

---

## Calculation Formula

**Sale Probability Per Hour** = `Base Demand × Zone Multiplier × Traffic Multiplier`

**Sale Probability Per Tick** = `Sale Probability Per Hour ÷ 125`

**Example: Soda in Office Zone at 8 AM**
- Base Demand: 0.30 (30%)
- Zone Multiplier: 2.0 (8 AM peak)
- Traffic Multiplier: 1.2
- **Result**: 0.30 × 2.0 × 1.2 = **0.72 (72% per hour)**
- **Per Tick**: 0.72 ÷ 125 = **0.00576 (0.576% per tick)**

---

## Notes

- Probabilities are calculated per hour, then divided by 125 ticks per hour for per-tick values
- The accumulator system accumulates progress each tick until it reaches 1.0, then triggers a sale
- Zone multipliers interpolate between defined hours for smooth transitions
- All probabilities are clamped between 0.0 and 1.0

