import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:games_services/games_services.dart';
import '../state/game_state.dart';
import '../simulation/models/weather.dart';

/// Achievement helper that supports Android/iOS via `games_services` and macOS via
/// a MethodChannel into native GameKit code.
class AchievementService {
  // Replace these sample IDs with your real achievement IDs from Play Games / Game Center
  static const String tycoonMonopoly = 'tycoon_monopoly'; // e.g. "CgkI..."
  static const String rainMaker = 'rain_maker';
  static const String fiveStar = 'five_star';

  static const MethodChannel _mc = MethodChannel('com.vending_empire/game_center');

  /// Unlocks an achievement by id. Uses platform-appropriate implementation.
  static Future<void> unlock(String achievementId) async {
    try {
      if (Platform.isMacOS) {
        await _mc.invokeMethod('unlockAchievement', {'id': achievementId});
      } else {
        // games_services uses platform-specific named parameters.
        // Use `androidID` for Android and `iOSID` for iOS; set percentComplete to 100 to mark unlocked.
        if (Platform.isAndroid) {
          await GamesServices.unlock(
              achievement: Achievement(androidID: achievementId, percentComplete: 100));
        } else if (Platform.isIOS) {
          await GamesServices.unlock(
              achievement: Achievement(iOSID: achievementId, percentComplete: 100));
        } else {
          // Fallback: provide both IDs in case the plugin/environment expects either.
          await GamesServices.unlock(
              achievement: Achievement(androidID: achievementId, iOSID: achievementId, percentComplete: 100));
        }
      }
    } catch (e) {
      // Non-fatal; log for debugging
      print('Error unlocking achievement $achievementId: $e');
    }
  }

  /// Optionally show achievements UI (best-effort)
  static Future<void> showAchievements() async {
    try {
      if (Platform.isMacOS) {
        await _mc.invokeMethod('showAchievements');
      } else {
        await GamesServices.showAchievements();
      }
    } catch (e) {
      print('Error showing achievements UI: $e');
    }
  }

  /// Check game state and unlock achievements when conditions are met.
  static Future<void> checkAchievements(GlobalGameState state) async {
    // Tycoon Monopoly: own 50 machines
    if (state.machines.length >= 50) {
      await unlock(tycoonMonopoly);
    }

    // Rain Maker: sales > 1000 during rainy weather
    if (state.currentDayRevenue > 1000.0 && state.weather == WeatherType.rainy) {
      await unlock(rainMaker);
    }

    // Five Star: reputation >= 1000
    if (state.reputation >= 1000) {
      await unlock(fiveStar);
    }
  }
}
