# Vending Machine Tycoon

A Flutter-based business simulation game where you build and manage your vending machine empire. Strategically place machines, manage inventory, optimize delivery routes, and grow your business across a dynamic city.

## 🎮 Game Overview

Vending Machine Tycoon is an idle/management game where players:
- Purchase and place vending machines in strategic locations
- Manage inventory across multiple machines
- Operate a fleet of delivery trucks to restock machines
- Monitor market prices and optimize product selection
- Build reputation through excellent service
- Expand their empire while managing cash flow

## ✨ Features

### Core Gameplay
- **City Map**: Interactive 10x10 grid city with different zone types (Office, School, Gym, Shop)
- **Vending Machines**: Purchase and place machines in strategic locations
- **Product Management**: 6 product types with different demand patterns:
  - Soda (high demand, low price)
  - Chips (medium demand, low price)
  - Protein Bar (medium demand, medium price)
  - Coffee (high demand in offices, medium price)
  - Tech Gadget (low demand, high price)
  - Sandwich (perishable, expires after 3 days)
- **Dynamic Market**: Fluctuating wholesale prices with daily updates
- **Warehouse System**: Central storage with 1000 item capacity
- **Fleet Management**: Purchase trucks and plan delivery routes
- **Route Optimization**: Plan efficient delivery routes with distance calculations
- **Reputation System**: Gain reputation from sales, lose it from empty machines
- **Rush Hour Events**: Special events that multiply sales rates
- **Daily Contracts**: Three client deals posted every game morning, with cash and reputation rewards
- **Per-Machine Pricing**: Set each product's retail price independently per machine to trade margin for volume
- **Theft & Vandalism**: Machines risk being robbed or vandalized, especially at night and in high-crime zones - collect cash promptly or invest in Security
- **Rival Company**: A competitor grows into zone types where you're thin on machines, cutting your sales there - push them back with a counter-attack campaign
- **Unlimited Machines**: Buy as many machines as the map has building tiles for - the only limit is your cash

### Game Mechanics

#### Time System
- 1 game day = 5 minutes real time (3000 ticks at 10 ticks/second)
- 24-hour day cycle with hour-based demand curves
- Different zones have peak hours (e.g., offices peak at 8 AM for coffee)

#### Sales System
- Sales probability based on:
  - Base product demand
  - Zone type and time of day
  - Traffic multiplier
  - Reputation bonus (up to +50% at 1000 reputation)
  - Rush Hour multiplier (10x during events)
- Products have different demand curves per zone type
- Customer interest system tracks sales progress

#### Reputation System
- **Gain**: +1 reputation per sale
- **Loss**: -5 reputation per hour per empty machine (after 4-hour grace period)
- **Bonus**: +5% sales rate per 100 reputation (max +50% at 1000 reputation)
- Starting reputation: 100

#### Machine Pricing
- Each product in each machine has its own price, set as a multiplier of list price (50% to 200%)
- Raising the price increases margin per sale but reduces how often that product sells
- Lowering the price does the opposite: more volume, thinner margin per unit
- How much a price change affects demand depends on the zone type - captive audiences (Hospital, Office) barely notice a markup, price-sensitive ones (School) punish it hard
- Every zone type has a revenue-maximizing price; finding it is the core pricing puzzle
- Premium Branding research still adds its flat +10% on top, independent of this multiplier

#### Daily Contracts
- Three contracts are offered each game morning and expire when the next day's set is posted
- Goal types:
  - **Supply Deal**: sell N units of a specific product today
  - **Revenue Target**: earn $N from sales today
  - **Volume Deal**: sell N items across all machines today
- Targets scale with the average revenue of the last 3 days and the number of machines
- Rewards are paid automatically on completion: cash plus +15 reputation
- An unfinished contract can be swapped once for $250

#### Theft & Vandalism
- Every game hour, each machine has a small chance of being targeted: robbed (loses a share of its uncollected cash) or vandalized (condition drops one level)
- A machine with nothing in the till is always vandalized rather than robbed - there's nothing to steal
- Risk rises at night (10 PM - 5 AM), with how much cash is sitting uncollected, and with the zone's own crime rate - Subway and School are the riskiest zones, Hospital and Office the safest
- Only cash left sitting in the machine is ever at risk; cash already collected into your wallet is untouched
- The Security System upgrade cuts the odds of either event sharply, and also halves the reputation penalty for an empty machine

#### Rival Company
- A competing vending company is chasing the same customers, one zone type at a time
- Every game day, their presence in a zone type grows toward a cap - fastest where you have few or no machines there (an uncontested market), slower where you're already established
- A more entrenched rival cuts your sale chance in that zone type, up to 45% at their strongest
- A Counter-Attack campaign pushes their presence back, at a cash cost that rises with how entrenched they are - but they always start creeping back in afterward, so it's a recurring decision, not a one-time fix
- Tracked per zone type in the new Rival Company screen, reachable from HQ

#### Quick Collect
- A machine with cash waiting shows a small pulsing money icon floating above it on the City map - tap it to collect instantly, no dialog needed
- Tapping the building itself always opens its status popup instead, whether or not there's cash waiting, since that's where stock, condition and price live
- Collecting from inside the machine (tapping the bill validator/coin bin in its interior view) still works exactly as before - the map icon is a faster option alongside it

#### Machine Management
- Machines can hold up to 50 items total
- Maximum 20 items per product type
- Machines have condition states (Excellent, Good, Fair, Poor, Broken)
- Cash collection from machines
- Machine status monitoring with detailed analytics

#### Truck System
- Trucks have 500 item capacity
- Fuel system with distance-based costs
- Pathfinding with road snapping
- Route planning with efficiency ratings (Great, Good, Fair, Poor)
- Real-time truck movement visualization on city map

### UI Features
- **HQ Dashboard**: Overview of empire health, sales analytics, and maintenance needs
- **City View**: Interactive map with machine placement and pedestrian animations
- **Fleet Manager**: Route planning, truck selection, and cargo management
- **Warehouse & Market**: Purchase products, manage inventory, load trucks
- **Machine Status**: Detailed view of individual machine performance
- **Save/Load System**: Multiple save slots with persistent game state
- **Options Screen**: Sound and music volume controls

### Technical Features
- **Cross-Platform**: Android, iOS, macOS, Windows, Linux, Web
- **State Management**: Riverpod with Freezed for immutable state
- **Game Engine**: Flame for city map visualization
- **Audio**: Background music and sound effects
- **Ads Integration**: Google Mobile Ads (AdMob) with banner ads
- **Responsive UI**: Screen-relative sizing for all devices
- **Custom Fonts**: Fredoka font family for consistent branding

## 🏗️ Architecture

### Project Structure
```
lib/
├── config.dart              # Central configuration constants
├── main.dart                # App entry point
├── game/                    # Flame game components
│   ├── city_map_game.dart   # Main city map game
│   ├── machine_dialog_game.dart
│   └── components/          # Game entities (trucks, machines, pedestrians)
├── simulation/              # Game logic engine
│   ├── engine.dart          # Core simulation loop
│   └── models/              # Game models (Machine, Truck, Product, Zone)
├── state/                   # State management
│   ├── game_state.dart      # Global game state
│   ├── providers.dart       # Riverpod providers
│   ├── save_load_service.dart
│   └── market_provider.dart # Dynamic market prices
└── ui/                      # Flutter UI
    ├── screens/             # Main screens
    ├── widgets/             # Reusable widgets
    └── utils/               # UI utilities
```

### Key Technologies
- **Flutter**: UI framework
- **Riverpod**: State management
- **Freezed**: Immutable data classes
- **Flame**: 2D game engine for city map
- **Shared Preferences**: Local storage
- **Google Mobile Ads**: Monetization
- **Audioplayers**: Sound system

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.10.3 or higher
- Dart SDK (included with Flutter)
- For Android: Android SDK with API 34+
- For iOS: Xcode (macOS only)
- For Web: Chrome or any modern browser

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd vending-empire
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run code generation** (for Freezed models)
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

### Building for Platforms

#### Android
```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# Release App Bundle (for Play Store)
flutter build appbundle --release --dart-define=BUILD_TYPE=bundle
```

#### iOS
```bash
flutter build ios --release
```

#### macOS
```bash
flutter build macos --release
```

#### Web
```bash
flutter build web --release
```

#### Windows/Linux
```bash
flutter build windows --release
flutter build linux --release
```

## 📱 Platform-Specific Notes

### Android
- Targets Android 14 (API 34) or higher
- Uses edge-to-edge display for Android 15+
- Portrait mode locked for mobile devices
- AdMob integration for banner ads
- Release builds require signing configuration (see `ANDROID_PUBLISHING_REQUIREMENTS.md`)

### iOS
- Portrait mode locked
- AdMob integration
- Requires proper provisioning profiles for release builds

### Web
- Responsive design works on desktop browsers
- AdMob not supported on web

## 🎯 Game Strategy Tips

1. **Start Small**: Begin with 1-2 machines in high-traffic zones
2. **Monitor Demand**: Check zone demand curves to optimize product selection
3. **Manage Inventory**: Keep machines stocked to maintain reputation
4. **Optimize Routes**: Plan efficient truck routes to minimize fuel costs
5. **Watch Market Prices**: Buy products when prices are low
6. **Balance Products**: Mix high-demand/low-price with low-demand/high-price items
7. **Handle Perishables**: Sandwiches expire after 3 days - manage carefully
8. **Build Reputation**: Each sale increases reputation, which boosts future sales
9. **Rush Hour**: Take advantage of Rush Hour events for 10x sales multiplier
10. **Expand Strategically**: Don't overextend - maintain cash flow

## ⚙️ Configuration

Most game constants are centralized in `lib/config.dart`:

- **Game Economy**: Machine prices ($400), truck prices ($500), fuel costs
- **Capacities**: Machine capacity (50), truck capacity (500), warehouse (1000)
- **Time Settings**: Ticks per day, hours per day, time multipliers
- **UI Constants**: Font sizes, spacing, colors, button sizes
- **Audio Settings**: Volume multipliers for sounds and music
- **AdMob**: Ad unit IDs (test and production)

## 🧪 Testing

Run tests with:
```bash
flutter test
```

## 📦 Dependencies

Key dependencies (see `pubspec.yaml` for full list):
- `flutter_riverpod: ^3.0.3` - State management
- `freezed: ^3.2.3` - Immutable data classes
- `flame: ^1.34.0` - Game engine
- `fl_chart: ^1.1.1` - Charts for analytics
- `google_fonts: ^6.3.3` - Font loading
- `shared_preferences: ^2.2.2` - Local storage
- `google_mobile_ads: ^5.1.0` - Ad integration
- `audioplayers: ^6.1.0` - Audio playback

## 🐛 Known Issues / Limitations

- Web platform doesn't support AdMob
- Some animations may be resource-intensive on older devices
- Save files are stored locally (no cloud sync)

## 📄 License

[Add your license information here]

## 🤝 Contributing

[Add contribution guidelines if applicable]

## 📞 Support

[Add support/contact information if applicable]

## 🎨 Assets

- **Fonts**: Fredoka (Regular, Medium, SemiBold, Bold)
- **Images**: Custom sprites for machines, trucks, pedestrians, city tiles
- **Sounds**: Background music and sound effects (button clicks, coin collection, truck sounds)

## 📊 Game Statistics

The game tracks:
- Daily revenue history (last 7 days)
- Total sales per product
- Machine condition and performance
- Route efficiency metrics
- Empire net worth (cash + assets + inventory value)

## 🔄 Save System

- Multiple save slots supported
- Saves include: game state, machines, trucks, warehouse, city map, reputation, cash
- Auto-save functionality available
- Save files stored in platform-specific locations

---

**Version**: 1.1.26+26  
**Last Updated**: 2026

Enjoy building your vending machine empire! 🏢💰
