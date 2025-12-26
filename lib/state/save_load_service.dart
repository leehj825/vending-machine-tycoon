import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_state.dart';
import 'providers.dart';
import 'city_map_state.dart';
import '../simulation/models/machine.dart';
import '../simulation/models/truck.dart';
import '../simulation/models/product.dart';
import '../simulation/models/zone.dart';

/// Save slot data structure
class SaveSlot {
  final String name;
  final GlobalGameState? gameState;

  SaveSlot({required this.name, this.gameState});

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'gameState': gameState != null ? SaveLoadService._serializeGameState(gameState!) : null,
    };
  }

  factory SaveSlot.fromJson(Map<String, dynamic> json) {
    return SaveSlot(
      name: json['name'] as String,
      gameState: json['gameState'] != null
          ? SaveLoadService._deserializeGameState(json['gameState'] as String)
          : null,
    );
  }
}

/// Service for saving and loading game state with 3 named slots
class SaveLoadService {
  static const String _saveSlotsKey = 'vending_empire_save_slots';
  static const String _oldSaveKey = 'vending_empire_save'; // Legacy key for migration
  static const int _maxSlots = 3;
  static const int _maxNameLength = 10;

  /// Migrate old save format to slot 1 if it exists
  static Future<void> _migrateOldSave() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if old save exists
      if (prefs.containsKey(_oldSaveKey)) {
        final oldJson = prefs.getString(_oldSaveKey);
        if (oldJson != null && oldJson.isNotEmpty) {
          try {
            // Try to deserialize the old save
            final oldState = _deserializeGameState(oldJson);
            
            // Get current slots (without calling migration again to avoid recursion)
            final prefs2 = await SharedPreferences.getInstance();
            final json = prefs2.getString(_saveSlotsKey);
            List<SaveSlot> slots;
            
            if (json == null) {
              slots = List.generate(_maxSlots, (index) => SaveSlot(name: ''));
            } else {
              final map = jsonDecode(json) as Map<String, dynamic>;
              final slotsJson = map['slots'] as List<dynamic>;
              slots = slotsJson.map((s) => SaveSlot.fromJson(s as Map<String, dynamic>)).toList();
            }
            
            // If slot 1 is empty, migrate old save to it
            if (slots[0].gameState == null) {
              slots[0] = SaveSlot(name: 'unknown', gameState: oldState);
              await _saveSlots(slots);
              
              // Remove old save key only after successful migration
              await prefs.remove(_oldSaveKey);
              print('✅ Migrated old save to slot 1 with name "unknown"');
            } else {
              // Slot 1 already has a save, just remove old key
              await prefs.remove(_oldSaveKey);
              print('⚠️ Old save exists but slot 1 is already used, removed old save key');
            }
          } catch (e) {
            print('❌ Error deserializing old save during migration: $e');
            // Don't remove old save if we can't deserialize it - user might want to try again
          }
        }
      }
    } catch (e) {
      print('❌ Error migrating old save: $e');
    }
  }

  /// Get all save slots
  static Future<List<SaveSlot>> _getSlots() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_saveSlotsKey);
      
      if (json == null) {
        // Initialize empty slots
        return List.generate(_maxSlots, (index) => SaveSlot(name: ''));
      }
      
      final map = jsonDecode(json) as Map<String, dynamic>;
      final slotsJson = map['slots'] as List<dynamic>;
      return slotsJson.map((s) => SaveSlot.fromJson(s as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Error getting slots: $e');
      return List.generate(_maxSlots, (index) => SaveSlot(name: ''));
    }
  }

  /// Save slots to storage
  static Future<bool> _saveSlots(List<SaveSlot> slots) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = {
        'slots': slots.map((s) => s.toJson()).toList(),
      };
      return await prefs.setString(_saveSlotsKey, jsonEncode(map));
    } catch (e) {
      print('Error saving slots: $e');
      return false;
    }
  }

  /// Get all save slots (public)
  static Future<List<SaveSlot>> getSaveSlots() async {
    await _migrateOldSave();
    return await _getSlots();
  }

  /// Save game to a specific slot
  static Future<bool> saveGame(int slotIndex, GlobalGameState gameState, String name) async {
    if (slotIndex < 0 || slotIndex >= _maxSlots) {
      return false;
    }
    
    // Validate name length
    final trimmedName = name.trim();
    if (trimmedName.isEmpty || trimmedName.length > _maxNameLength) {
      return false;
    }
    
    try {
      await _migrateOldSave();
      final slots = await _getSlots();
      slots[slotIndex] = SaveSlot(name: trimmedName, gameState: gameState);
      return await _saveSlots(slots);
    } catch (e) {
      print('Error saving game: $e');
      return false;
    }
  }

  /// Load game from a specific slot
  static Future<GlobalGameState?> loadGame(int slotIndex) async {
    if (slotIndex < 0 || slotIndex >= _maxSlots) {
      return null;
    }
    
    try {
      await _migrateOldSave();
      final slots = await _getSlots();
      return slots[slotIndex].gameState;
    } catch (e) {
      print('Error loading game: $e');
      return null;
    }
  }

  /// Delete game from a specific slot
  static Future<bool> deleteGame(int slotIndex) async {
    if (slotIndex < 0 || slotIndex >= _maxSlots) {
      return false;
    }
    
    try {
      final slots = await _getSlots();
      slots[slotIndex] = SaveSlot(name: '');
      return await _saveSlots(slots);
    } catch (e) {
      print('Error deleting game: $e');
      return false;
    }
  }

  /// Check if any saved game exists (for backward compatibility)
  static Future<bool> hasSavedGame() async {
    await _migrateOldSave();
    final slots = await _getSlots();
    return slots.any((slot) => slot.gameState != null);
  }

  /// Legacy methods for backward compatibility (deprecated)
  @Deprecated('Use saveGame(slotIndex, gameState, name) instead')
  static Future<bool> saveGameLegacy(GlobalGameState gameState) async {
    return await saveGame(0, gameState, 'Save 1');
  }

  @Deprecated('Use loadGame(slotIndex) instead')
  static Future<GlobalGameState?> loadGameLegacy() async {
    return await loadGame(0);
  }

  @Deprecated('Use getSaveSlots() instead')
  static Future<bool> deleteSavedGame() async {
    return await deleteGame(0);
  }

  /// Serialize game state to JSON (internal method)
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

  /// Deserialize JSON to game state (internal method)
  /// Handles both old and new save formats for backward compatibility
  static GlobalGameState _deserializeGameState(String json) {
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      
      // Handle old format where json might be the game state directly
      // vs new format where it's stored as a string in SaveSlot
      Map<String, dynamic> gameStateMap;
      if (map.containsKey('cash') || map.containsKey('machines')) {
        // This is already the game state map
        gameStateMap = map;
      } else {
        // This might be wrapped, try to extract
        gameStateMap = map;
      }
      
      return GlobalGameState(
        cash: (gameStateMap['cash'] as num?)?.toDouble() ?? 2000.0,
        reputation: gameStateMap['reputation'] as int? ?? 100,
        dayCount: gameStateMap['dayCount'] as int? ?? 1,
        hourOfDay: gameStateMap['hourOfDay'] as int? ?? 8,
        logMessages: gameStateMap['logMessages'] != null
            ? List<String>.from(gameStateMap['logMessages'] as List)
            : [],
        machines: gameStateMap['machines'] != null
            ? (gameStateMap['machines'] as List)
                .map((m) => _deserializeMachine(m as Map<String, dynamic>))
                .toList()
            : [],
        trucks: gameStateMap['trucks'] != null
            ? (gameStateMap['trucks'] as List)
                .map((t) => _deserializeTruck(t as Map<String, dynamic>))
                .toList()
            : [],
        warehouse: gameStateMap['warehouse'] != null
            ? _deserializeWarehouse(gameStateMap['warehouse'] as Map<String, dynamic>)
            : const Warehouse(),
        warehouseRoadX: gameStateMap['warehouseRoadX'] as double?,
        warehouseRoadY: gameStateMap['warehouseRoadY'] as double?,
        cityMapState: gameStateMap['cityMapState'] != null
            ? CityMapState.fromJson(gameStateMap['cityMapState'] as Map<String, dynamic>)
            : null,
      );
    } catch (e) {
      print('Error deserializing game state: $e');
      print('JSON was: ${json.substring(0, json.length > 200 ? 200 : json.length)}...');
      rethrow;
    }
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
      path: (map['path'] as List)
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

