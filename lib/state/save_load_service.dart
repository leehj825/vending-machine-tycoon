import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_state.dart';
import 'providers.dart';
import 'city_map_state.dart';
import '../simulation/models/machine.dart';
import '../simulation/models/truck.dart';
import '../simulation/models/product.dart';
import '../simulation/models/zone.dart';
import '../simulation/engine.dart';

/// Service for saving and loading game state
class SaveLoadService {
  static const String _saveKey = 'vending_empire_save';

  /// Save the current game state
  static Future<bool> saveGame(GlobalGameState gameState) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = _serializeGameState(gameState);
      return await prefs.setString(_saveKey, json);
    } catch (e) {
      print('Error saving game: $e');
      return false;
    }
  }

  /// Load the saved game state
  static Future<GlobalGameState?> loadGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_saveKey);
      if (json == null) {
        return null;
      }
      return _deserializeGameState(json);
    } catch (e) {
      print('Error loading game: $e');
      return null;
    }
  }

  /// Check if a saved game exists
  static Future<bool> hasSavedGame() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_saveKey);
  }

  /// Delete the saved game
  static Future<bool> deleteSavedGame() async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.remove(_saveKey);
  }

  /// Serialize game state to JSON
  static String _serializeGameState(GlobalGameState state) {
    final map = {
      'cash': state.cash,
      'reputation': state.reputation,
      'dayCount': state.dayCount,
      'hourOfDay': state.hourOfDay,
      'logMessages': state.logMessages,
      'machines': state.machines.map((m) => _serializeMachine(m)).toList(),
      'trucks': state.trucks.map((t) => _serializeTruck(t)).toList(),
      'warehouse': _serializeWarehouse(state.warehouse),
      'warehouseRoadX': state.warehouseRoadX,
      'warehouseRoadY': state.warehouseRoadY,
      'cityMapState': state.cityMapState?.toJson(),
    };
    return jsonEncode(map);
  }

  /// Deserialize JSON to game state
  static GlobalGameState _deserializeGameState(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    
    return GlobalGameState(
      cash: (map['cash'] as num).toDouble(),
      reputation: map['reputation'] as int,
      dayCount: map['dayCount'] as int,
      hourOfDay: map['hourOfDay'] as int,
      logMessages: List<String>.from(map['logMessages'] as List),
      machines: (map['machines'] as List)
          .map((m) => _deserializeMachine(m))
          .toList(),
      trucks: (map['trucks'] as List)
          .map((t) => _deserializeTruck(t as Map<String, dynamic>))
          .toList(),
      warehouse: _deserializeWarehouse(map['warehouse'] as Map<String, dynamic>),
      warehouseRoadX: map['warehouseRoadX'] as double?,
      warehouseRoadY: map['warehouseRoadY'] as double?,
      cityMapState: map['cityMapState'] != null
          ? CityMapState.fromJson(map['cityMapState'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Serialize machine to JSON
  static Map<String, dynamic> _serializeMachine(Machine machine) {
    return {
      'id': machine.id,
      'name': machine.name,
      'zone': _serializeZone(machine.zone),
      'condition': machine.condition.name,
      'inventory': machine.inventory.map((key, value) => MapEntry(
        key.name,
        {
          'product': key.name,
          'quantity': value.quantity,
          'dayAdded': value.dayAdded,
        },
      )),
      'currentCash': machine.currentCash,
      'hoursSinceRestock': machine.hoursSinceRestock,
      'totalSales': machine.totalSales,
    };
  }

  /// Deserialize machine from JSON
  static Machine _deserializeMachine(Map<String, dynamic> map) {
    return Machine(
      id: map['id'] as String,
      name: map['name'] as String,
      zone: _deserializeZone(map['zone'] as Map<String, dynamic>),
      condition: MachineCondition.values.firstWhere(
        (e) => e.name == map['condition'] as String,
      ),
      inventory: (map['inventory'] as Map<String, dynamic>).map((key, value) {
        final product = Product.values.firstWhere((p) => p.name == key);
        final itemMap = value as Map<String, dynamic>;
        return MapEntry(
          product,
          InventoryItem(
            product: product,
            quantity: itemMap['quantity'] as int,
            dayAdded: itemMap['dayAdded'] as int,
          ),
        );
      }),
      currentCash: (map['currentCash'] as num).toDouble(),
      hoursSinceRestock: (map['hoursSinceRestock'] as num).toDouble(),
      totalSales: map['totalSales'] as int,
    );
  }

  /// Serialize truck to JSON
  static Map<String, dynamic> _serializeTruck(Truck truck) {
    return {
      'id': truck.id,
      'name': truck.name,
      'fuel': truck.fuel,
      'capacity': truck.capacity,
      'route': truck.route,
      'currentRouteIndex': truck.currentRouteIndex,
      'status': truck.status.name,
      'currentX': truck.currentX,
      'currentY': truck.currentY,
      'targetX': truck.targetX,
      'targetY': truck.targetY,
      'path': truck.path.map((p) => {'x': p.x, 'y': p.y}).toList(),
      'pathIndex': truck.pathIndex,
      'inventory': truck.inventory.map((key, value) => MapEntry(
        key.name,
        value,
      )),
    };
  }

  /// Deserialize truck from JSON
  static Truck _deserializeTruck(Map<String, dynamic> map) {
    return Truck(
      id: map['id'] as String,
      name: map['name'] as String,
      fuel: (map['fuel'] as num).toDouble(),
      capacity: map['capacity'] as int,
      route: List<String>.from(map['route'] as List),
      currentRouteIndex: map['currentRouteIndex'] as int,
      status: TruckStatus.values.firstWhere(
        (e) => e.name == map['status'] as String,
      ),
      currentX: (map['currentX'] as num).toDouble(),
      currentY: (map['currentY'] as num).toDouble(),
      targetX: (map['targetX'] as num).toDouble(),
      targetY: (map['targetY'] as num).toDouble(),
      path: (map['path'] as List<dynamic>)
          .map((p) => (
                x: (p as Map<String, dynamic>)['x'] as double,
                y: (p as Map<String, dynamic>)['y'] as double,
              ))
          .toList(),
      pathIndex: map['pathIndex'] as int,
      inventory: (map['inventory'] as Map<String, dynamic>).map((key, value) {
        final product = Product.values.firstWhere((p) => p.name == key);
        return MapEntry(product, value as int);
      }),
    );
  }

  /// Serialize zone to JSON
  static Map<String, dynamic> _serializeZone(Zone zone) {
    return {
      'id': zone.id,
      'type': zone.type.name,
      'name': zone.name,
      'x': zone.x,
      'y': zone.y,
      'demandCurve': zone.demandCurve.map((key, value) => MapEntry(
        key.toString(),
        value,
      )),
      'trafficMultiplier': zone.trafficMultiplier,
    };
  }

  /// Deserialize zone from JSON
  static Zone _deserializeZone(Map<String, dynamic> map) {
    return Zone(
      id: map['id'] as String,
      type: ZoneType.values.firstWhere(
        (e) => e.name == map['type'] as String,
      ),
      name: map['name'] as String,
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      demandCurve: (map['demandCurve'] as Map<String, dynamic>).map((key, value) {
        return MapEntry(int.parse(key), (value as num).toDouble());
      }),
      trafficMultiplier: (map['trafficMultiplier'] as num).toDouble(),
    );
  }

  /// Serialize warehouse to JSON
  static Map<String, dynamic> _serializeWarehouse(Warehouse warehouse) {
    return {
      'inventory': warehouse.inventory.map((key, value) => MapEntry(
        key.name,
        value,
      )),
    };
  }

  /// Deserialize warehouse from JSON
  static Warehouse _deserializeWarehouse(Map<String, dynamic> map) {
    return Warehouse(
      inventory: (map['inventory'] as Map<String, dynamic>).map((key, value) {
        final product = Product.values.firstWhere((p) => p.name == key);
        return MapEntry(product, value as int);
      }),
    );
  }

}

