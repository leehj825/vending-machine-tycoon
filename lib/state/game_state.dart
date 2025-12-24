import 'package:freezed_annotation/freezed_annotation.dart';
import '../simulation/models/machine.dart';
import '../simulation/models/truck.dart';
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
    @Default([]) List<String> logMessages, // Game event log
    @Default([]) List<Machine> machines,
    @Default([]) List<Truck> trucks,
    @Default(Warehouse()) Warehouse warehouse,
    @Default(null) double? warehouseRoadX, // Road tile X coordinate next to warehouse (zone coordinates)
    @Default(null) double? warehouseRoadY, // Road tile Y coordinate next to warehouse (zone coordinates)
    @Default(null) CityMapState? cityMapState, // City map layout (grid, buildings, roads)
  }) = _GlobalGameState;

  const GlobalGameState._();

  /// Add a log message (keeps last 100 messages)
  GlobalGameState addLogMessage(String message) {
    final timestamp = 'Day $dayCount, ${_formatHour(hourOfDay)}';
    final newEntry = '[$timestamp] $message';
    
    // Take the last 99 items, then add the new one to avoid unnecessary copying
    final limitedHistory = logMessages.length >= 100 
        ? logMessages.sublist(logMessages.length - 99) 
        : logMessages;
        
    return copyWith(logMessages: [...limitedHistory, newEntry]);
  }

  /// Format hour for display
  String _formatHour(int hour) {
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final amPm = hour < 12 ? 'AM' : 'PM';
    return '$hour12:00 $amPm';
  }
}

