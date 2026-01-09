import 'package:freezed_annotation/freezed_annotation.dart';
import '../simulation/models/machine.dart';
import '../simulation/models/truck.dart';
import '../simulation/models/product.dart';
import '../simulation/models/research.dart';
import '../simulation/models/weather.dart';
import '../simulation/engine.dart'; // For GameTime
import 'game_log_entry.dart';
import 'providers.dart';
import 'city_map_state.dart';

part 'game_state.freezed.dart';

/// Global game state that holds the overall game progress
@freezed
abstract class GlobalGameState with _$GlobalGameState {
  const factory GlobalGameState({
    @Default(2000.0) double cash, // Starting cash: $2000
    @Default(100) int reputation, // Starting reputation: 100
    @Default(1) int dayCount, // Current day number
    @Default(8) int hourOfDay, // Current hour (0-23), starts at 8 AM
    @Default([]) List<GameLogEntry> logHistory, // Structured game event log
    @Default([]) List<Machine> machines,
    @Default([]) List<Truck> trucks,
    @Default(Warehouse()) Warehouse warehouse,
    @Default(null) double? warehouseRoadX, // Road tile X coordinate next to warehouse (zone coordinates)
    @Default(null) double? warehouseRoadY, // Road tile Y coordinate next to warehouse (zone coordinates)
    @Default(null) CityMapState? cityMapState, // City map layout (grid, buildings, roads)
    @Default([]) List<double> dailyRevenueHistory, // Last 7 days of revenue
    @Default(0.0) double currentDayRevenue, // Revenue accumulated for current day
    @Default({}) Map<Product, int> productSalesCount, // Global sales count per product
    @Default(0.0) double hypeLevel, // Marketing hype level (0.0 to 1.0)
    @Default(false) bool isRushHour, // Whether Rush Hour is currently active
    @Default(1.0) double rushMultiplier, // Sales multiplier during Rush Hour (default 1.0, 10.0 during rush)
    @Default(null) int? marketingButtonGridX, // Marketing button grid X position (0-9)
    @Default(null) int? marketingButtonGridY, // Marketing button grid Y position (0-9)
    // Tutorial flags - saved with game state
    @Default(false) bool hasSeenPedestrianTapTutorial,
    @Default(false) bool hasSeenBuyTruckTutorial,
    @Default(false) bool hasSeenTruckTutorial,
    @Default(false) bool hasSeenGoStockTutorial,
    @Default(false) bool hasSeenMarketTutorial,
    @Default(false) bool hasSeenMoneyExtractionTutorial,
    // Staff Management - Centralized in HQ
    @Default(0) int driverPoolCount, // Number of hired drivers (not assigned to trucks)
    @Default(0) int mechanicCount, // Number of mechanics (auto-repair)
    @Default(0) int purchasingAgentCount, // Number of purchasing agents (auto-buy stock)
    @Default({}) Map<Product, int> purchasingAgentTargetInventory, // Target inventory levels for purchasing agent
    @Default(false) bool isGameOver, // Game over flag (when cash is too negative)
    @Default({}) Set<ResearchType> unlockedResearch, // Unlocked research items
    @Default(WeatherType.sunny) WeatherType weather, // Current weather
  }) = _GlobalGameState;

  const GlobalGameState._();

  /// Add a log message (keeps last 100 messages)
  /// This is deprecated; prefer using structured logging via addLogEntry
  GlobalGameState addLogMessage(String message) {
    // Convert legacy string messages to generic entries
    final timestamp = GameTime(day: dayCount, hour: hourOfDay, minute: 0, tick: 0);
    final entry = GameLogEntry(
      type: LogType.generic,
      timestamp: timestamp,
      message: message,
    );
    return addLogEntry(entry);
  }

  /// Add a structured log entry (keeps last 100 messages)
  GlobalGameState addLogEntry(GameLogEntry entry) {
    // Take the last 99 items, then add the new one to avoid unnecessary copying
    final limitedHistory = logHistory.length >= 100
        ? logHistory.sublist(logHistory.length - 99)
        : logHistory;
        
    return copyWith(logHistory: [...limitedHistory, entry]);
  }

  /// Format hour for display
  String _formatHour(int hour) {
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final amPm = hour < 12 ? 'AM' : 'PM';
    return '$hour12:00 $amPm';
  }
}

