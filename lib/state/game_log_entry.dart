import 'package:freezed_annotation/freezed_annotation.dart';
import '../simulation/engine.dart';

part 'game_log_entry.freezed.dart';

enum LogType {
  weatherChange,
  staffSalary,
  machineBreakdown,
  sale,
  purchasingAgentBuy,
  truckLoad,
  truckRestock,
  generic, // Fallback for now
}

@freezed
class GameLogEntry with _$GameLogEntry {
  const factory GameLogEntry({
    required LogType type,
    required GameTime timestamp,
    @Default({}) Map<String, dynamic> data,
    @Default('') String message, // Keep message for backward compatibility/generic logs
  }) = _GameLogEntry;

  const GameLogEntry._();

  String get formattedMessage {
    switch (type) {
      case LogType.weatherChange:
        return 'Weather changed to ${data['weather']}';
      case LogType.staffSalary:
        return '💰 Paid \$${(data['amount'] as num).toStringAsFixed(2)} in staff salaries';
      case LogType.machineBreakdown:
        return 'ALERT: Machine ${data['machineName']} has broken down!';
      case LogType.purchasingAgentBuy:
        return '📦 Purchasing Agent bought ${data['amount']} ${data['product']}';
      case LogType.truckLoad:
         return '🚚 TRUCK LOAD: ${data['details']}';
      case LogType.truckRestock:
        return '🔄 TRUCK RESTOCK: Transferred ${data['details']} to machine ${data['machineName']}';
      case LogType.generic:
      default:
        return message;
    }
  }
}
