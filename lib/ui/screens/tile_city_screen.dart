import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import '../../state/providers.dart';
import '../../state/selectors.dart';
import '../../state/city_map_state.dart';
import '../../simulation/models/zone.dart';
import '../../simulation/models/truck.dart' as sim;
import '../../simulation/models/machine.dart' as sim;
import '../../simulation/models/product.dart';
import '../../config.dart';
import '../theme/zone_ui.dart';
import '../utils/screen_utils.dart';
import '../widgets/machine_interior_dialog.dart';
import '../widgets/marketing_button.dart';

enum TileType {
  grass,
  road,
  shop,
  gym,
  office,
  school,
  gasStation,
  park,
  house,
  warehouse,
  subway,
  hospital,
  university,
}

enum RoadDirection {
  vertical,
  horizontal,
  intersection,
}

enum BuildingOrientation {
  normal,
  flippedHorizontal,
}

/// Pedestrian state class for tile city screen
class _PedestrianState {
  final int personId; // 0-9
  double gridX;
  double gridY;
  double? targetGridX;
  double? targetGridY;
  String direction; // 'front', 'back'
  bool flipHorizontal;
  int stepsWalked; // Track how many steps the pedestrian has taken
  
  _PedestrianState({
    required this.personId,
    required this.gridX,
    required this.gridY,
    this.targetGridX,
    this.targetGridY,
    this.direction = 'front',
    this.flipHorizontal = false,
    this.stepsWalked = 0,
  });
}

class TileCityScreen extends ConsumerStatefulWidget {
  const TileCityScreen({super.key});

  @override
  ConsumerState<TileCityScreen> createState() => _TileCityScreenState();
}

class _TileCityScreenState extends ConsumerState<TileCityScreen> {
  static const int gridSize = 15; // Using AppConfig.cityGridSize value
  
  // Tile dimensions will be calculated relative to screen size
  double _getTileWidth(BuildContext context) {
    return ScreenUtils.relativeSizeClamped(
      context,
      0.15, // 15% of smaller dimension
      min: 48.0,
      max: 96.0,
    );
  }
  
  double _getTileHeight(BuildContext context) {
    return ScreenUtils.relativeSizeClamped(
      context,
      0.075, // 7.5% of smaller dimension (half of width for isometric)
      min: 24.0,
      max: 48.0,
    );
  }
  
  double _getBuildingImageHeight(BuildContext context) {
    return ScreenUtils.relativeSizeClamped(
      context,
      0.18, // 18% of smaller dimension
      min: 50.0,
      max: 100.0,
    );
  }
  
  static const double tileSpacingFactor = AppConfig.tileSpacingFactor;
  static const double horizontalSpacingFactor = AppConfig.horizontalSpacingFactor;
  
  static const double buildingScale = AppConfig.buildingScale;
  static const double schoolScale = AppConfig.schoolScale;
  
  static const double gasStationScale = AppConfig.gasStationScale;
  static const double parkScale = AppConfig.parkScale;
  static const double houseScale = AppConfig.houseScale;
  static const double warehouseScale = AppConfig.warehouseScale;
  
  double _getWarehouseVerticalOffset(BuildContext context) {
    return ScreenUtils.relativeSize(context, 0.007);
  }

  double _getSpecialBuildingVerticalOffset(BuildContext context, TileType tileType) {
    // Hospital, subway, and university tiles need to be moved up a bit
    if (tileType == TileType.hospital || tileType == TileType.subway || tileType == TileType.university) {
      return ScreenUtils.relativeSize(context, 0.007); // Adjust this value to move up more/less
    }
    return 0.0;
  }
  
  static const int minBlockSize = AppConfig.minBlockSize;
  static const int maxBlockSize = AppConfig.maxBlockSize;
  
  late List<List<TileType>> _grid;
  late List<List<RoadDirection?>> _roadDirections;
  late List<List<BuildingOrientation?>> _buildingOrientations;
  
  int? _warehouseX;
  int? _warehouseY;
  
  late TransformationController _transformationController;
  bool _isPanning = false;
  Timer? _panEndTimer;
  
  // Debounce tracking
  DateTime? _lastTapTime;
  String? _lastTappedButton;
  
  // Draggable message position (null = use default position)
  Offset? _messagePosition;
  Offset? _messageDragStartPosition; // Position when drag started
  Offset _messageDragAccumulatedDelta = Offset.zero; // Accumulated delta during current drag
  bool _previousRushHourState = false; // Track previous rush hour state to detect transitions
  
  // Pedestrian management
  final List<_PedestrianState> _pedestrians = [];
  Timer? _pedestrianUpdateTimer;
  final Set<int> _usedPersonIds = {}; // Track which personIds are currently in use
  final math.Random _pedestrianRandom = math.Random();

  @override
  void initState() {
    super.initState();
    // Initialize with a zoomed-in view (scale 1.5)
    _transformationController = TransformationController();
    
    // Listen to transformation changes to detect panning
    _transformationController.addListener(_onTransformationChanged);
    
    // Initialize map immediately - check if map state exists in saved game, otherwise generate new map
    final gameState = ref.read(gameControllerProvider);
    if (gameState.cityMapState != null) {
      _loadMapFromState(gameState.cityMapState!);
    } else {
      _generateMap();
      // Save map state after frame is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _saveMapToState();
      });
    }
    
    // Ensure simulation is running when city screen loads (if not already running)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = ref.read(gameControllerProvider.notifier);
      if (!controller.isSimulationRunning) {
        controller.startSimulation();
      }
      
      // Ensure marketing button is spawned if it doesn't exist
      final gameState = ref.read(gameStateProvider);
      if ((gameState.marketingButtonGridX == null || 
           gameState.marketingButtonGridY == null) && 
          !gameState.isRushHour) {
        controller.spawnMarketingButton();
      }
      
      // Spawn pedestrians (clear used IDs first)
      _usedPersonIds.clear();
      _pedestrians.clear();
      _spawnPedestrians();
      
      // Start pedestrian update timer
      _pedestrianUpdateTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        if (mounted) {
          _updatePedestrians();
          setState(() {}); // Trigger rebuild to show movement
        }
      });
    });
  }
  
  /// Load map from saved state
  void _loadMapFromState(CityMapState mapState) {
    _grid = mapState.grid.map((row) {
      return row.map((tileName) {
        return TileType.values.firstWhere(
          (e) => e.name == tileName,
          orElse: () => TileType.grass,
        );
      }).toList();
    }).toList();
    
    _roadDirections = mapState.roadDirections.map((row) {
      return row.map((dirName) {
        if (dirName == null) return null;
        return RoadDirection.values.firstWhere(
          (e) => e.name == dirName,
          orElse: () => RoadDirection.horizontal,
        );
      }).toList();
    }).toList();
    
    _buildingOrientations = mapState.buildingOrientations.map((row) {
      return row.map((orientName) {
        if (orientName == null) return null;
        return BuildingOrientation.values.firstWhere(
          (e) => e.name == orientName,
          orElse: () => BuildingOrientation.normal,
        );
      }).toList();
    }).toList();
    
    _warehouseX = mapState.warehouseX;
    _warehouseY = mapState.warehouseY;
    
    // Update valid roads in simulation engine
    _updateValidRoads();
  }
  
  /// Save current map to game state
  void _saveMapToState() {
    final gridStrings = _grid.map((row) {
      return row.map((tile) => tile.name).toList();
    }).toList();
    
    final roadDirStrings = _roadDirections.map((row) {
      return row.map((dir) => dir?.name).toList();
    }).toList();
    
    final buildingOrientStrings = _buildingOrientations.map((row) {
      return row.map((orient) => orient?.name).toList();
    }).toList();
    
    final mapState = CityMapState(
      grid: gridStrings,
      roadDirections: roadDirStrings,
      buildingOrientations: buildingOrientStrings,
      warehouseX: _warehouseX,
      warehouseY: _warehouseY,
    );
    
    final controller = ref.read(gameControllerProvider.notifier);
    controller.updateCityMapState(mapState);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    _pedestrianUpdateTimer?.cancel();
    _panEndTimer?.cancel();
    super.dispose();
  }
  
  void _onTransformationChanged() {
    // Detect if transformation is changing (panning/zooming)
    if (!_isPanning) {
      setState(() {
        _isPanning = true;
      });
    }
    
    // Reset timer - if no changes for 200ms, consider panning stopped
    _panEndTimer?.cancel();
    _panEndTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted && _isPanning) {
        setState(() {
          _isPanning = false;
        });
      }
    });
  }

  void _generateMap() {
    _grid = List.generate(
      gridSize,
      (_) => List.filled(gridSize, TileType.grass),
    );
    _roadDirections = List.generate(
      gridSize,
      (_) => List.filled(gridSize, null),
    );
    _buildingOrientations = List.generate(
      gridSize,
      (_) => List.filled(gridSize, null),
    );

    _generateRoadGrid();
    _placeWarehouse();
    _placeBuildingBlocks();
    
    // Update valid roads in simulation engine
    _updateValidRoads();
  }
  
  /// Extract road tiles from grid and update simulation engine
  /// Note: This is now handled by updateCityMapState in GameController,
  /// but we keep this for backward compatibility during map generation
  void _updateValidRoads() {
    final roadTiles = <({double x, double y})>[];
    
    // Find all road tiles
    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        if (_grid[y][x] == TileType.road) {
          // Convert grid coordinates to zone coordinates (grid + 1)
          roadTiles.add((x: (x + 1).toDouble(), y: (y + 1).toDouble()));
        }
      }
    }
    
    // Update simulation engine with road tiles
    if (roadTiles.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final controller = ref.read(gameControllerProvider.notifier);
        controller.simulationEngine.setMapLayout(roadTiles);
      });
    }
  }

  void _generateRoadGrid() {
    final random = math.Random();
    
    // Generate horizontal roads with dynamic spacing (2x3 or 2x4 blocks)
    int currentY = 3;
    while (currentY < gridSize - 2) {
      for (int x = 0; x < gridSize; x++) {
        _grid[currentY][x] = TileType.road;
      }
      // Randomly choose spacing: 3 (2x3 block) or 4 (2x4 block)
      final spacing = random.nextBool() ? 3 : 4;
      currentY += spacing;
    }
    
    // Generate vertical roads with dynamic spacing (2x3 or 2x4 blocks)
    int currentX = 3;
    while (currentX < gridSize - 2) {
      for (int y = 0; y < gridSize; y++) {
        _grid[y][currentX] = TileType.road;
      }
      // Randomly choose spacing: 3 (2x3 block) or 4 (2x4 block)
      final spacing = random.nextBool() ? 3 : 4;
      currentX += spacing;
    }
    _updateRoadDirections();
  }

  void _placeWarehouse() {
    final random = math.Random();
    final validSpots = <List<int>>[];
    
    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        if (_grid[y][x] == TileType.grass && _isTileAdjacentToRoad(x, y)) {
          validSpots.add([x, y]);
        }
      }
    }
    
    if (validSpots.isNotEmpty) {
      final spot = validSpots[random.nextInt(validSpots.length)];
      _warehouseX = spot[0];
      _warehouseY = spot[1];
      _grid[spot[1]][spot[0]] = TileType.warehouse;
      _updateWarehouseRoadPosition();
    }
  }

  void _updateWarehouseRoadPosition() {
    if (_warehouseX == null || _warehouseY == null) return;
    
    double? nearestRoadX;
    double? nearestRoadY;
    double minDistance = double.infinity;
    
    final directions = [[-1, 0], [1, 0], [0, -1], [0, 1]];
    
    for (final dir in directions) {
      final checkX = (_warehouseX! + dir[0]).toInt();
      final checkY = (_warehouseY! + dir[1]).toInt();
      
      if (checkX >= 0 && checkX < gridSize && 
          checkY >= 0 && checkY < gridSize &&
          _grid[checkY][checkX] == TileType.road) {
        final zoneX = (checkX + 1).toDouble();
        final zoneY = (checkY + 1).toDouble();
        
        final distance = (checkX - _warehouseX!).abs().toDouble() + (checkY - _warehouseY!).abs().toDouble();
        
        if (distance < minDistance) {
          minDistance = distance;
          nearestRoadX = zoneX;
          nearestRoadY = zoneY;
        }
      }
    }
    
    if (nearestRoadX != null && nearestRoadY != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final controller = ref.read(gameControllerProvider.notifier);
        controller.setWarehouseRoadPosition(nearestRoadX!, nearestRoadY!);
      });
    }
  }

  void _updateRoadDirections() {
    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        if (_grid[y][x] == TileType.road) {
          _roadDirections[y][x] = _getRoadDirection(x, y);
        }
      }
    }
  }

  RoadDirection _getRoadDirection(int x, int y) {
    final bool hasNorth = y > 0 && _grid[y - 1][x] == TileType.road;
    final bool hasSouth = y < gridSize - 1 && _grid[y + 1][x] == TileType.road;
    final bool hasEast = x < gridSize - 1 && _grid[y][x + 1] == TileType.road;
    final bool hasWest = x > 0 && _grid[y][x - 1] == TileType.road;
    final bool isAtEdge = x == 0 || x == gridSize - 1 || y == 0 || y == gridSize - 1;

    final int connections = (hasNorth ? 1 : 0) + (hasSouth ? 1 : 0) + (hasEast ? 1 : 0) + (hasWest ? 1 : 0);

    if (isAtEdge) {
      if (hasNorth && hasSouth) return RoadDirection.vertical;
      if (hasEast && hasWest) return RoadDirection.horizontal;
      if (hasNorth || hasSouth) return RoadDirection.vertical;
      if (hasEast || hasWest) return RoadDirection.horizontal;
      return RoadDirection.horizontal;
    }

    if (connections >= 3) return RoadDirection.intersection;
    if (hasNorth && hasSouth) return RoadDirection.vertical;
    if (hasEast && hasWest) return RoadDirection.horizontal;
    return RoadDirection.intersection;
  }

  void _placeBuildingBlocks() {
    final random = math.Random();
    final buildingTypes = [
      TileType.shop, TileType.gym, TileType.office, TileType.school,
      TileType.gasStation, TileType.park, TileType.house,
      TileType.subway, TileType.hospital, TileType.university,
    ];

    final buildingCounts = <TileType, int>{
      TileType.shop: 0, TileType.gym: 0, TileType.office: 0, TileType.school: 0,
      TileType.gasStation: 0, TileType.park: 0, TileType.house: 0,
      TileType.subway: 0, TileType.hospital: 0, TileType.university: 0,
    };
    
    final maxBuildingCounts = <TileType, int>{
      TileType.shop: 4, TileType.gym: 4, TileType.office: 4, TileType.school: 4,
      TileType.gasStation: 4, TileType.park: 6, TileType.house: 6,
      TileType.subway: 4, TileType.hospital: 4, TileType.university: 4,
    };

    final validBlocks = <Map<String, dynamic>>[];
    
    for (int startY = 0; startY < gridSize; startY++) {
      for (int startX = 0; startX < gridSize; startX++) {
        for (int blockWidth = minBlockSize; blockWidth <= maxBlockSize; blockWidth++) {
          for (int blockHeight = minBlockSize; blockHeight <= maxBlockSize; blockHeight++) {
            if (blockWidth == 3 && blockHeight == 3) continue;
            if (_canPlaceBlock(startX, startY, blockWidth, blockHeight)) {
              validBlocks.add({
                'x': startX, 'y': startY, 'width': blockWidth, 'height': blockHeight,
              });
            }
          }
        }
      }
    }

    validBlocks.sort((a, b) {
      final aHasBuildings = _blockHasBuildings(a['x'] as int, a['y'] as int, a['width'] as int, a['height'] as int);
      final bHasBuildings = _blockHasBuildings(b['x'] as int, b['y'] as int, b['width'] as int, b['height'] as int);
      if (aHasBuildings != bHasBuildings) return aHasBuildings ? 1 : -1;
      return 0;
    });
    
    final emptyBlocks = validBlocks.where((b) => !_blockHasBuildings(b['x'] as int, b['y'] as int, b['width'] as int, b['height'] as int)).toList();
    final blocksWithBuildings = validBlocks.where((b) => _blockHasBuildings(b['x'] as int, b['y'] as int, b['width'] as int, b['height'] as int)).toList();
    emptyBlocks.shuffle(random);
    blocksWithBuildings.shuffle(random);
    final sortedBlocks = [...emptyBlocks, ...blocksWithBuildings];
    
    final placedTiles = <String>{};
    
    for (final block in sortedBlocks) {
      final startX = block['x'] as int;
      final startY = block['y'] as int;
      final blockWidth = block['width'] as int;
      final blockHeight = block['height'] as int;
      
      bool overlaps = false;
      for (int by = startY; by < startY + blockHeight && !overlaps; by++) {
        for (int bx = startX; bx < startX + blockWidth && !overlaps; bx++) {
          if (placedTiles.contains('$bx,$by')) overlaps = true;
        }
      }
      
      if (overlaps) continue;
      
      final blockBuildingTypes = <TileType>{};
      final blockTiles = <List<int>>[];
      for (int by = startY; by < startY + blockHeight && by < gridSize; by++) {
        for (int bx = startX; bx < startX + blockWidth && bx < gridSize; bx++) {
          blockTiles.add([bx, by]);
        }
      }
      
      blockTiles.sort((a, b) {
        final aAdjacent = _isTileAdjacentToBuilding(a[0], a[1], placedTiles);
        final bAdjacent = _isTileAdjacentToBuilding(b[0], b[1], placedTiles);
        if (aAdjacent != bAdjacent) return aAdjacent ? 1 : -1;
        return 0;
      });
      
      final maxBuildingsPerBlock = 2;
      final numBuildings = math.min(math.min(blockTiles.length, maxBuildingsPerBlock), buildingTypes.length);
      
      final priorityTypes = [
        TileType.gasStation, TileType.park, TileType.house,
        TileType.shop, TileType.gym, TileType.office, TileType.school,
        TileType.subway, TileType.hospital, TileType.university,
      ];
      
      for (int i = 0; i < numBuildings && i < blockTiles.length; i++) {
        final tile = blockTiles[i];
        final bx = tile[0];
        final by = tile[1];
        
        if (!_isTileAdjacentToRoad(bx, by)) continue;
        
        final availableTypes = buildingTypes.where((type) => 
          !blockBuildingTypes.contains(type) && buildingCounts[type]! < maxBuildingCounts[type]!
        ).toList();
        
        if (availableTypes.isEmpty) break;
        
        final housesAndParks = availableTypes.where((type) => 
          (type == TileType.house || type == TileType.park) && buildingCounts[type]! < maxBuildingCounts[type]!
        ).toList();
        
        final priorityAvailable = housesAndParks.isNotEmpty 
            ? housesAndParks
            : availableTypes.where((type) => 
                priorityTypes.contains(type) && buildingCounts[type]! < maxBuildingCounts[type]!
              ).toList();
        
        final buildingType = priorityAvailable.isNotEmpty 
            ? priorityAvailable[random.nextInt(priorityAvailable.length)]
            : availableTypes[random.nextInt(availableTypes.length)];
        
        buildingCounts[buildingType] = buildingCounts[buildingType]! + 1;
        blockBuildingTypes.add(buildingType);
        
        _grid[by][bx] = buildingType;
        _buildingOrientations[by][bx] = BuildingOrientation.normal;
        placedTiles.add('$bx,$by');
      }
    }
  }

  bool _canPlaceBlock(int startX, int startY, int width, int height) {
    if (startX + width > gridSize || startY + height > gridSize) return false;
    
    for (int y = startY; y < startY + height; y++) {
      for (int x = startX; x < startX + width; x++) {
        if (_grid[y][x] != TileType.grass) return false;
      }
    }
    
    bool adjacentToRoad = false;
    
    if (startY > 0) {
      for (int x = startX; x < startX + width; x++) {
        if (_grid[startY - 1][x] == TileType.road) { adjacentToRoad = true; break; }
      }
    }
    if (!adjacentToRoad && startY + height < gridSize) {
      for (int x = startX; x < startX + width; x++) {
        if (_grid[startY + height][x] == TileType.road) { adjacentToRoad = true; break; }
      }
    }
    if (!adjacentToRoad && startX > 0) {
      for (int y = startY; y < startY + height; y++) {
        if (_grid[y][startX - 1] == TileType.road) { adjacentToRoad = true; break; }
      }
    }
    if (!adjacentToRoad && startX + width < gridSize) {
      for (int y = startY; y < startY + height; y++) {
        if (_grid[y][startX + width] == TileType.road) { adjacentToRoad = true; break; }
      }
    }
    
    return adjacentToRoad;
  }

  bool _isTileAdjacentToRoad(int x, int y) {
    if (x > 0 && _grid[y][x - 1] == TileType.road) return true;
    if (x < gridSize - 1 && _grid[y][x + 1] == TileType.road) return true;
    if (y > 0 && _grid[y - 1][x] == TileType.road) return true;
    if (y < gridSize - 1 && _grid[y + 1][x] == TileType.road) return true;
    return false;
  }

  bool _blockHasBuildings(int startX, int startY, int width, int height) {
    for (int y = startY; y < startY + height && y < gridSize; y++) {
      for (int x = startX; x < startX + width && x < gridSize; x++) {
        if (_isBuilding(_grid[y][x])) return true;
      }
    }
    return false;
  }

  bool _isTileAdjacentToBuilding(int x, int y, Set<String> placedTiles) {
    if (x > 0 && placedTiles.contains('${x - 1},$y')) return true;
    if (x < gridSize - 1 && placedTiles.contains('${x + 1},$y')) return true;
    if (y > 0 && placedTiles.contains('$x,${y - 1}')) return true;
    if (y < gridSize - 1 && placedTiles.contains('$x,${y + 1}')) return true;
    return false;
  }

  Offset _gridToScreen(BuildContext context, int gridX, int gridY) {
    final tileWidth = _getTileWidth(context);
    final tileHeight = _getTileHeight(context);
    final screenX = (gridX - gridY) * (tileWidth / 2) * horizontalSpacingFactor;
    final screenY = (gridX + gridY) * (tileHeight / 2) * tileSpacingFactor;
    return Offset(screenX, screenY);
  }

  Offset _gridToScreenDouble(BuildContext context, double gridX, double gridY) {
    final tileWidth = _getTileWidth(context);
    final tileHeight = _getTileHeight(context);
    final screenX = (gridX - gridY) * (tileWidth / 2) * horizontalSpacingFactor;
    final screenY = (gridX + gridY) * (tileHeight / 2) * tileSpacingFactor;
    return Offset(screenX, screenY);
  }

  String _getTileAssetPath(TileType tileType, RoadDirection? roadDir) {
    switch (tileType) {
      case TileType.grass: return 'assets/images/tiles/grass.png';
      case TileType.road:
        return roadDir == RoadDirection.intersection 
          ? 'assets/images/tiles/road_4way.png' 
          : 'assets/images/tiles/road_2way.png';
      case TileType.shop: return 'assets/images/tiles/shop.png';
      case TileType.gym: return 'assets/images/tiles/gym.png';
      case TileType.office: return 'assets/images/tiles/office.png';
      case TileType.school: return 'assets/images/tiles/school.png';
      case TileType.gasStation: return 'assets/images/tiles/gas_station.png';
      case TileType.park: return 'assets/images/tiles/park.png';
      case TileType.house: return 'assets/images/tiles/house.png';
      case TileType.warehouse: return 'assets/images/tiles/warehouse.png';
      case TileType.subway: return 'assets/images/tiles/subway.png';
      case TileType.hospital: return 'assets/images/tiles/hospital.png';
      case TileType.university: return 'assets/images/tiles/university.png';
    }
  }

  bool _isBuilding(TileType tileType) {
    return tileType == TileType.shop || tileType == TileType.gym ||
        tileType == TileType.office || tileType == TileType.school ||
        tileType == TileType.gasStation || tileType == TileType.park ||
        tileType == TileType.house || tileType == TileType.warehouse ||
        tileType == TileType.subway || tileType == TileType.hospital ||
        tileType == TileType.university;
  }

  double _getBuildingScale(TileType tileType) {
    switch (tileType) {
      case TileType.school: return schoolScale;
      case TileType.gasStation: return gasStationScale;
      case TileType.park: return parkScale;
      case TileType.house: return houseScale;
      case TileType.warehouse: return warehouseScale;
      default: return buildingScale;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch machines provider to ensure rebuild when machines change
    ref.watch(machinesProvider);
    
    // Get tile dimensions for this context
    final tileWidth = _getTileWidth(context);
    final tileHeight = _getTileHeight(context);
    final buildingImageHeight = _getBuildingImageHeight(context);
    
    // 1. Calculate the map's bounding box
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    
    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        final screenPos = _gridToScreen(context, x, y);
        minX = math.min(minX, screenPos.dx);
        maxX = math.max(maxX, screenPos.dx + tileWidth);
        minY = math.min(minY, screenPos.dy);
        maxY = math.max(maxY, screenPos.dy + tileHeight);
        
        if (_isBuilding(_grid[y][x])) {
          final buildingTop = screenPos.dy - (buildingImageHeight - tileHeight);
          minY = math.min(minY, buildingTop);
        }
      }
    }
    
    // Add generous padding for the map canvas to ensure no clipping during pans/scales
    // Calculate padding relative to map dimensions
    final initialMapWidth = maxX - minX;
    final initialMapHeight = maxY - minY;
    final sidePadding = initialMapWidth * AppConfig.mapSidePaddingFactor;
    final topPadding = initialMapHeight * AppConfig.mapTopPaddingFactor;
    final bottomPadding = initialMapHeight * AppConfig.mapBottomPaddingFactor;
    
    minX -= sidePadding;
    maxX += sidePadding;
    minY -= topPadding;
    maxY += bottomPadding;
    
    final mapWidth = maxX - minX;
    final mapHeight = maxY - minY;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        final viewportHeight = constraints.maxHeight;
        
        // 2. Determine the container size for InteractiveViewer
        // Force the container to be AT LEAST the size of the viewport.
        // This allows us to position the map at the bottom of the viewport.
        final containerWidth = math.max(viewportWidth, mapWidth);
        final containerHeight = math.max(viewportHeight, mapHeight);

        // 3. Calculate Offsets to position tiles
        // Horizontal: Center in the container
        final offsetX = (containerWidth - mapWidth) / 2 - minX;
        
        // Vertical: Bottom Align in the container
        // We want the bottom visual edge (maxY) to be 'targetBottomGap' from container bottom.
        final double targetBottomGap = mapHeight * AppConfig.mapTargetBottomGapFactor; 
        // Logic: containerHeight - targetBottomGap = New Visual Bottom Position
        // Visual Bottom Position = (maxY + dy)
        // dy = containerHeight - targetBottomGap - maxY
        final offsetY = containerHeight - targetBottomGap - maxY;
        
        final centerOffset = Offset(offsetX, offsetY);

        // Calculate initial scale to zoom in for better visibility
        final initialScale = AppConfig.initialMapZoom;
        
        // Calculate center of the map in container coordinates
        final mapCenterX = offsetX + (minX + maxX) / 2;
        final mapCenterY = offsetY + (minY + maxY) / 2;
        
        // Calculate initial translation to center the viewport on the map center
        // After scaling, we need to adjust translation to keep the center point in view
        final initialTranslationX = viewportWidth / 2 - mapCenterX * initialScale;
        final initialTranslationY = viewportHeight / 2 - mapCenterY * initialScale;
        
        // Set initial transformation if not already set (only on first build)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_transformationController.value.isIdentity()) {
            _transformationController.value = Matrix4.identity()
              ..translate(initialTranslationX, initialTranslationY)
              ..scale(initialScale);
          }
        });
        
        final components = _buildMapComponents(context, centerOffset, tileWidth, tileHeight, buildingImageHeight);
        
        return Stack(
          children: [
            InteractiveViewer(
              transformationController: _transformationController,
              boundaryMargin: EdgeInsets.all(ScreenUtils.relativeSize(context, 0.2)),
              minScale: 0.3,
              maxScale: 3.0,
              // *** CRITICAL FIX: ***
              // constrained: false allows the child to be its natural size (containerWidth/Height)
              // rather than forcing it to the viewport size. This ensures elements outside the
              // initial screen bounds are still part of the hit-test area.
              constrained: false,
              child: SizedBox(
                width: containerWidth,
                height: containerHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ...components['tiles']!,
                    // Buttons on top (hidden during panning)
                    if (!_isPanning) ...components['buttons']!,
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Map<String, List<Widget>> _buildMapComponents(BuildContext context, Offset centerOffset, double tileWidth, double tileHeight, double buildingImageHeight) {
    final warehouseVerticalOffset = _getWarehouseVerticalOffset(context);
    
    // Two-Layer Rendering System:
    // Layer 1: Ground tiles (Grass/Road) - rendered first, always behind everything
    // Layer 2: Objects (Buildings, Pedestrians, Trucks, Machines) - sorted by depth
    final groundTiles = <Widget>[];
    final objectItems = <Map<String, dynamic>>[];
    
    // 1. Iterate through the grid and separate ground tiles from buildings
    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        final screenPos = _gridToScreen(context, x, y);
        final tileType = _grid[y][x];
        
        // Build the tile widget
        final tileWidget = _buildSingleTileWidget(
          context, x, y, tileType, _roadDirections[y][x], _buildingOrientations[y][x],
          screenPos.dx + centerOffset.dx, screenPos.dy + centerOffset.dy,
          tileWidth, tileHeight, buildingImageHeight, warehouseVerticalOffset
        );
        
        // Separate ground tiles from buildings
        if (tileType == TileType.grass || tileType == TileType.road) {
          // Ground tiles: Add directly to groundTiles (no sorting needed)
          groundTiles.add(tileWidget);
        } else {
          // Buildings: Add to objectItems for depth sorting
          objectItems.add({
            'type': 'building',
            'depth': x + y,
            'y': y,
            'priority': 3, // Buildings have Priority 3 (drawn last at same depth)
            'widget': tileWidget,
          });
        }
      }
    }
    
    // 2. Add all pedestrians to objectItems
    for (final pedestrian in _pedestrians) {
      // Use .round() to assign pedestrian to the visual tile they are closest to
      final gridX = pedestrian.gridX.round();
      final gridY = pedestrian.gridY.round();
      final depth = gridX + gridY;
      
      // Build the pedestrian widget
      final pedestrianWidget = _buildPedestrian(context, pedestrian, centerOffset, tileWidth, tileHeight);
      
      objectItems.add({
        'type': 'pedestrian',
        'depth': depth,
        'y': gridY,
        'priority': 1, // Pedestrians/Trucks have Priority 1
        'widget': pedestrianWidget,
      });
    }
    
    // 3. Add all trucks to objectItems
    final gameTrucks = ref.watch(trucksProvider);
    for (final truck in gameTrucks) {
      // Convert from 1-based zone coordinates to 0-based grid coordinates
      final gridX = (truck.currentX - 1.0).round();
      final gridY = (truck.currentY - 1.0).round();
      final depth = gridX + gridY;
      
      // Build the truck widget
      final truckWidget = _buildGameTruck(context, truck, centerOffset, tileWidth, tileHeight);
      
      objectItems.add({
        'type': 'truck',
        'depth': depth,
        'y': gridY,
        'priority': 1, // Pedestrians/Trucks have Priority 1
        'widget': truckWidget,
      });
    }
    
    // 4. Machines are rendered separately after all objects to always appear in front
    // (Don't add machines to objectItems - they'll be added to tiles list separately)
    
    // 5. Sort objectItems using Painter's Algorithm
    objectItems.sort((a, b) {
      // Primary sort: Depth (x + y) - Ascending (lower depth draws first/behind)
      final depthA = (a['depth'] as int?) ?? 0;
      final depthB = (b['depth'] as int?) ?? 0;
      if (depthA != depthB) return depthA.compareTo(depthB);
      
      // Secondary sort: Y coordinate - Ascending (higher up on grid draws first/behind)
      final yA = (a['y'] as int?) ?? 0;
      final yB = (b['y'] as int?) ?? 0;
      if (yA != yB) return yA.compareTo(yB);
      
      // Tertiary sort: Priority - Ascending
      // Priority order: 1 (Pedestrians/Trucks) < 3 (Buildings)
      // Note: Machines are rendered separately after all objects, so they always appear on top
      final priorityA = (a['priority'] as int?) ?? 0;
      final priorityB = (b['priority'] as int?) ?? 0;
      return priorityA.compareTo(priorityB);
    });
    
    // 6. Build objects list from sorted objectItems
    final objects = <Widget>[];
    for (final item in objectItems) {
      objects.add(item['widget'] as Widget);
    }
    
    // 7. Add machines separately - always render on top of everything
    final gameMachines = ref.watch(machinesProvider);
    final machineWidgets = <Widget>[];
    for (final machine in gameMachines) {
      final machineWidget = _buildGameMachine(context, machine, centerOffset, tileWidth, tileHeight);
      machineWidgets.add(machineWidget);
    }
    
    // 8. Combine ground tiles, objects, and machines into final tiles list
    // Ground tiles render first (behind), then objects, then machines (always on top)
    final tiles = <Widget>[...groundTiles, ...objects, ...machineWidgets];
    
    // 7. Build purchase buttons (separate from depth sorting, rendered on top)
    final buttons = <Widget>[];
    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        final tileType = _grid[y][x];
        if (_isBuilding(tileType) && tileType != TileType.warehouse && _shouldShowPurchaseButton(x, y, tileType)) {
          final screenPos = _gridToScreen(context, x, y);
          final posX = screenPos.dx + centerOffset.dx;
          final posY = screenPos.dy + centerOffset.dy;
          
          final buttonSize = ScreenUtils.relativeSizeClamped(
            context, 0.03,
            min: ScreenUtils.getSmallerDimension(context) * 0.03,
            max: ScreenUtils.getSmallerDimension(context) * 0.03,
          );
          
          final buttonTop = posY;
          final buttonLeft = posX + (tileWidth / 2) - (buttonSize / 2);
          
          buttons.add(
            Positioned(
              left: buttonLeft,
              top: buttonTop,
              width: buttonSize,
              height: buttonSize,
              child: _PurchaseButton(
                size: buttonSize,
                onTap: () => _handleDebouncedBuildingTap(x, y, tileType),
              ),
            ),
          );
        }
      }
    }

    // Add Marketing Button if position is set (show during rush hour too, but with fire icon)
    final gameState = ref.watch(gameStateProvider);
    
    // Reset message position when rush hour ends (transitions from true to false)
    if (_previousRushHourState && !gameState.isRushHour) {
      _messagePosition = null; // Reset to default position above button
    }
    _previousRushHourState = gameState.isRushHour;
    
    if (gameState.marketingButtonGridX != null && 
        gameState.marketingButtonGridY != null) {
      final buttonGridX = gameState.marketingButtonGridX!;
      final buttonGridY = gameState.marketingButtonGridY!;
      final screenPos = _gridToScreen(context, buttonGridX, buttonGridY);
      final positionedX = screenPos.dx + centerOffset.dx;
      final positionedY = screenPos.dy + centerOffset.dy;
      
      buttons.add(
        MarketingButton(
          gridX: buttonGridX,
          gridY: buttonGridY,
          screenPosition: Offset(positionedX, positionedY),
          tileWidth: tileWidth,
          tileHeight: tileHeight,
        ),
      );
      
      // Add instruction message above the button (only when not in rush hour)
      if (!gameState.isRushHour) {
        // Calculate default position above the button (rush button during rush hour, marketing button otherwise)
        final defaultMessageOffsetX = positionedX - tileWidth * 0.5;
        final defaultMessageOffsetY = positionedY - tileHeight * 1.0; // Lower above button
        
        // Use stored position if available, otherwise use default
        final messageOffsetX = _messagePosition?.dx ?? defaultMessageOffsetX;
        final messageOffsetY = _messagePosition?.dy ?? defaultMessageOffsetY;
        
        buttons.add(
          Positioned(
            left: messageOffsetX,
            top: messageOffsetY,
            child: GestureDetector(
              onPanStart: (details) {
                // Store the current position when drag starts and reset accumulated delta
                _messageDragStartPosition = _messagePosition ?? Offset(defaultMessageOffsetX, defaultMessageOffsetY);
                _messageDragAccumulatedDelta = Offset.zero;
              },
              onPanUpdate: (details) {
                setState(() {
                  // Accumulate delta and update position
                  _messageDragAccumulatedDelta += details.delta;
                  if (_messageDragStartPosition != null) {
                    _messagePosition = Offset(
                      _messageDragStartPosition!.dx + _messageDragAccumulatedDelta.dx,
                      _messageDragStartPosition!.dy + _messageDragAccumulatedDelta.dy,
                    );
                  }
                });
              },
              onPanEnd: (details) {
                // Clear drag start position
                _messageDragStartPosition = null;
                _messageDragAccumulatedDelta = Offset.zero;
              },
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: tileWidth * 3.0, // Smaller width
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: ScreenUtils.relativeSize(context, 0.01),
                  vertical: ScreenUtils.relativeSize(context, 0.005),
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(ScreenUtils.relativeSize(context, AppConfig.borderRadiusFactorSmall)),
                  border: Border.all(
                    color: Colors.white,
                    width: ScreenUtils.relativeSize(context, AppConfig.borderWidthFactorSmall * 1.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.touch_app,
                      color: Colors.white,
                      size: ScreenUtils.relativeSize(context, 0.025), // Smaller icon
                    ),
                    SizedBox(width: ScreenUtils.relativeSize(context, 0.005)),
                    Flexible(
                      child: Text(
                        'Keep pressing to rush selling!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: ScreenUtils.relativeFontSize(
                            context,
                            0.018, // Smaller font
                            min: ScreenUtils.getSmallerDimension(context) * 0.014,
                            max: ScreenUtils.getSmallerDimension(context) * 0.025,
                          ),
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }

    return {'tiles': tiles, 'buttons': buttons};
  }

  Widget _buildSingleTileWidget(
    BuildContext context, int x, int y, TileType tileType, 
    RoadDirection? roadDir, BuildingOrientation? orientation,
    double posX, double posY, double tileWidth, double tileHeight, 
    double buildingImageHeight, double warehouseOffset
  ) {
    if (tileType == TileType.warehouse) {
      final scale = warehouseScale;
      final w = tileWidth * scale;
      final h = buildingImageHeight * scale;
      return Positioned(
        left: posX + (tileWidth - w) / 2,
        top: posY - (h - tileHeight) - warehouseOffset,
        width: w, height: h,
        child: _buildGroundTile(tileType, roadDir),
      );
    } 
    
    if (!_isBuilding(tileType)) {
      return Positioned(
        left: posX, top: posY, width: tileWidth, height: tileHeight,
        child: _buildGroundTile(tileType, roadDir),
      );
    }
    
    // It's a building
    final scale = _getBuildingScale(tileType);
    final w = tileWidth * scale;
    final h = buildingImageHeight * scale;
    final verticalOffset = _getSpecialBuildingVerticalOffset(context, tileType);
    
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Ground patch under building
        Positioned(
          left: posX, top: posY, width: tileWidth, height: tileHeight,
          child: _buildGroundTile(TileType.grass, null),
        ),
        // The building itself
        Positioned(
          left: posX + (tileWidth - w) / 2,
          top: posY - (h - tileHeight*0.95) - verticalOffset,
          width: w, height: h,
          child: GestureDetector(
            onTap: () => _handleDebouncedBuildingTap(x, y, tileType),
            behavior: HitTestBehavior.opaque,
            child: _buildBuildingTile(tileType, orientation),
          ),
        ),
      ],
    );
  }

  void _handleDebouncedBuildingTap(int x, int y, TileType tileType) {
    final now = DateTime.now();
    final key = '$x,$y';
    if (_lastTappedButton == key && _lastTapTime != null && now.difference(_lastTapTime!) < AppConfig.debounceTap) {
      return;
    }
    _lastTapTime = now;
    _lastTappedButton = key;
    _handleBuildingTap(x, y, tileType);
  }

  Widget _buildGameMachine(BuildContext context, sim.Machine machine, Offset centerOffset, double tileWidth, double tileHeight) {
    // Convert zone coordinates to grid coordinates
    // Zone coordinates are (gridX + 1.5), so zoneX - 1.0 = gridX + 0.5
    // Use floor() instead of round() to avoid rounding 0.5 up to the wrong tile
    final gridPos = _zoneToGrid(machine.zone.x, machine.zone.y);
    final gridX = gridPos.dx.floor();
    final gridY = gridPos.dy.floor();
    
    // Use integer grid coordinates to get exact tile position (same as building tiles)
    final pos = _gridToScreen(context, gridX, gridY);
    final positionedX = pos.dx + centerOffset.dx;
    final positionedY = pos.dy + centerOffset.dy;
    
    // Make machine button smaller
    final double machineSize = tileWidth * 0.2;
    
    // Position machine button at bottom center of building tile (not on road)
    // Use similar centering pattern as message: center horizontally on tile
    final left = positionedX + (tileWidth - machineSize) / 2; // Center horizontally on tile
    final top = positionedY + machineSize / 4; // Bottom center of building tile

    Color machineColor;
    switch (machine.zone.type) {
      case ZoneType.shop: machineColor = Colors.blue; break;
      case ZoneType.school: machineColor = Colors.purple; break;
      case ZoneType.gym: machineColor = Colors.red; break;
      case ZoneType.office: machineColor = Colors.orange; break;
      case ZoneType.subway: machineColor = Colors.blueGrey; break;
      case ZoneType.hospital: machineColor = Colors.red; break;
      case ZoneType.university: machineColor = Colors.indigo; break;
    }

    final machineId = machine.id;

    // Determine status indicators - positioned at center of tile
    Widget? statusIndicator;
    final indicatorSize = tileWidth * 0.15; // Larger indicator for better visibility
    if (machine.isBroken) {
      statusIndicator = Container(
        width: indicatorSize*2,
        height: indicatorSize*2,
        decoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 4,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.build,
          color: Colors.white,
          size: indicatorSize * 1.2,
        ),
      );
    } else if (machine.totalInventory == 0) {
      statusIndicator = Container(
        width: indicatorSize*2,
        height: indicatorSize*2,
        decoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 4,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.close,
          color: Colors.white,
          size: indicatorSize * 1.2,
        ),
      );
    } else if (machine.totalInventory < 10) { // Low stock threshold
      statusIndicator = Container(
        width: indicatorSize*2,
        height: indicatorSize*2,
        decoration: BoxDecoration(
          color: Colors.amber,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 4,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.priority_high,
          color: Colors.black,
          size: indicatorSize * 1.2,
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Status indicator at center of tile
        if (statusIndicator != null)
          Positioned(
            left: positionedX + (tileWidth / 2) - (indicatorSize),
            top: positionedY - (indicatorSize *2.0),
            child: statusIndicator,
          ),
        // Machine button at bottom center of tile
        Positioned(
          left: left,
          top: top,
          width: machineSize,
          height: machineSize,
          child: GestureDetector(
            onTap: () {
              final machines = ref.read(machinesProvider);
              final currentMachine = machines.firstWhere(
                (m) => m.id == machineId,
                orElse: () => machine,
              );
              _showMachineView(context, currentMachine);
            },
            child: Container(
              decoration: BoxDecoration(
                color: machineColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: ScreenUtils.relativeSize(context, 0.002)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.search,
                  color: Colors.white,
                  size: machineSize * 0.6,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getViewImagePath(ZoneType zoneType) {
    switch (zoneType) {
      case ZoneType.shop: return 'assets/images/views/shop_view.png';
      case ZoneType.school: return 'assets/images/views/school_view.png';
      case ZoneType.gym: return 'assets/images/views/gym_view.png';
      case ZoneType.office: return 'assets/images/views/office_view.png';
      case ZoneType.subway: return 'assets/images/views/subway_view.png';
      case ZoneType.hospital: return 'assets/images/views/hospital_view.png';
      case ZoneType.university: return 'assets/images/views/university_view.png';
    }
  }

  void _showMachineView(BuildContext context, sim.Machine machine) {
    final machineId = machine.id;
    final imagePath = _getViewImagePath(machine.zone.type);
    
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => _MachineViewDialog(
        machineId: machineId,
        imagePath: imagePath,
      ),
    );
  }

  void _showMachinePurchaseDialog(BuildContext context, ZoneType zoneType, double zoneX, double zoneY) {
    final imagePath = _getViewImagePath(zoneType);
    final price = MachinePrices.getPrice(zoneType);
    
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (dialogContext) => _MachinePurchaseDialog(
        zoneType: zoneType,
        zoneX: zoneX,
        zoneY: zoneY,
        imagePath: imagePath,
        price: price,
        onPurchased: () {
          // After purchase, close purchase dialog and show machine status
          Navigator.of(dialogContext).pop();
          // Wait a moment for the machine to be created, then show status
          Future.delayed(const Duration(milliseconds: 100), () {
            if (context.mounted) {
              final machines = ref.read(machinesProvider);
              try {
                final machine = machines.firstWhere(
                  (m) => (m.zone.x - zoneX).abs() < 0.1 && (m.zone.y - zoneY).abs() < 0.1,
                );
                _showMachineView(context, machine);
              } catch (e) {
                // Machine not found yet, just close
              }
            }
          });
        },
      ),
    );
  }

  Offset _zoneToGrid(double zoneX, double zoneY) {
    final gridX = (zoneX - 1.0).clamp(0.0, (gridSize - 1).toDouble());
    final gridY = (zoneY - 1.0).clamp(0.0, (gridSize - 1).toDouble());
    return Offset(gridX, gridY);
  }

  Widget _buildGameTruck(BuildContext context, sim.Truck truck, Offset centerOffset, double tileWidth, double tileHeight) {
    final gridPos = _zoneToGrid(truck.currentX, truck.currentY);
    final pos = _gridToScreenDouble(context, gridPos.dx, gridPos.dy);
    final positionedX = pos.dx + centerOffset.dx;
    final positionedY = pos.dy + centerOffset.dy;
    
    final double truckSize = tileWidth * 0.4; 
    final left = positionedX + (tileWidth - truckSize) / 2;
    final top = positionedY + (tileHeight / 2) - truckSize/1.2;

    String asset = 'assets/images/tiles/truck_front.png';
    bool flip = false;
    
    double dx = 0.0;
    double dy = 0.0;
    
    if (truck.path.isNotEmpty && truck.pathIndex < truck.path.length) {
      final nextWaypoint = truck.path[truck.pathIndex];
      dx = nextWaypoint.x - truck.currentX;
      dy = nextWaypoint.y - truck.currentY;
    } else {
      dx = truck.targetX - truck.currentX;
      dy = truck.targetY - truck.currentY;
    }
    
    if (dx.abs() > 0.01 || dy.abs() > 0.01) {
      if (dx.abs() > dy.abs()) {
        if (dx > 0) {
          asset = 'assets/images/tiles/truck_front.png';
          flip = true;
        } else {
          asset = 'assets/images/tiles/truck_back.png';
          flip = false;
        }
      } else {
        if (dy > 0) {
          asset = 'assets/images/tiles/truck_front.png';
          flip = false;
        } else {
          asset = 'assets/images/tiles/truck_back.png';
          flip = true;
        }
      }
    }

    Widget img = Image.asset(
      asset,
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.blue.shade300,
          alignment: Alignment.bottomCenter,
          child: Text(
            'T',
            style: TextStyle(
              fontSize: ScreenUtils.relativeFontSize(
                context,
                AppConfig.fontSizeFactorNormal,
                min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
              ),
              color: Colors.white,
            ),
          ),
        );
      },
    );

    if (flip) {
      return Positioned(
        left: left,
        top: top,
        width: truckSize,
        height: truckSize,
        child: Transform(
          alignment: Alignment.center, 
          transform: Matrix4.identity()..scale(-1.0, 1.0), 
          child: img
        ),
      );
    }
    
    return Positioned(
      left: left,
      top: top,
      width: truckSize,
      height: truckSize,
      child: img,
    );
  }

  // --- PEDESTRIAN MANAGEMENT ---
  
  /// Spawn random number (1-10) of pedestrians with unique personIds next to buildings
  void _spawnPedestrians() {
    // Find all road tiles that are next to buildings
    final validTiles = _findRoadTilesNextToBuildings();
    
    if (validTiles.isEmpty) return;
    
    // Spawn random number of pedestrians (1-10)
    final numToSpawn = _pedestrianRandom.nextInt(10) + 1; // 1 to 10
    
    // Get available personIds (0-9) that are not currently in use
    final availablePersonIds = List.generate(10, (i) => i).where((id) => !_usedPersonIds.contains(id)).toList();
    
    // Shuffle and take only what we need
    availablePersonIds.shuffle(_pedestrianRandom);
    final personIdsToUse = availablePersonIds.take(numToSpawn).toList();
    
    // If we don't have enough unique IDs, use what we have
    for (int i = 0; i < personIdsToUse.length && i < numToSpawn; i++) {
      final personId = personIdsToUse[i];
      final validTile = validTiles[_pedestrianRandom.nextInt(validTiles.length)];
      
      _pedestrians.add(_PedestrianState(
        personId: personId,
        gridX: validTile.x.toDouble(),
        gridY: validTile.y.toDouble(),
      ));
      _usedPersonIds.add(personId);
    }
  }
  
  /// Spawn a single pedestrian at a random road tile next to a building
  void _spawnSinglePedestrian() {
    // Find all road tiles that are next to buildings
    final validTiles = _findRoadTilesNextToBuildings();
    
    if (validTiles.isEmpty) return;
    
    // Get available personIds that are not currently in use
    final availablePersonIds = List.generate(10, (i) => i).where((id) => !_usedPersonIds.contains(id)).toList();
    
    if (availablePersonIds.isEmpty) return; // All personIds are in use
    
    final personId = availablePersonIds[_pedestrianRandom.nextInt(availablePersonIds.length)];
    final validTile = validTiles[_pedestrianRandom.nextInt(validTiles.length)];
    
    _pedestrians.add(_PedestrianState(
      personId: personId,
      gridX: validTile.x.toDouble(),
      gridY: validTile.y.toDouble(),
    ));
    _usedPersonIds.add(personId);
  }
  
  /// Check if a tile type is a building or house
  bool _isBuildingOrHouse(TileType tileType) {
    return tileType == TileType.shop ||
           tileType == TileType.gym ||
           tileType == TileType.office ||
           tileType == TileType.school ||
           tileType == TileType.house ||
           tileType == TileType.subway ||
           tileType == TileType.hospital ||
           tileType == TileType.university;
  }
  
  /// Check if pedestrian is adjacent to a building or house (in front of it)
  bool _isInFrontOfBuildingOrHouse(int gridX, int gridY) {
    // Check all 4 adjacent tiles for buildings or houses
    final directions = [
      (x: gridX, y: gridY - 1), // Up
      (x: gridX, y: gridY + 1), // Down
      (x: gridX - 1, y: gridY), // Left
      (x: gridX + 1, y: gridY), // Right
    ];
    
    for (final dir in directions) {
      if (dir.y >= 0 && dir.y < _grid.length &&
          dir.x >= 0 && dir.x < _grid[dir.y].length) {
        if (_isBuildingOrHouse(_grid[dir.y][dir.x])) {
          return true;
        }
      }
    }
    
    return false;
  }
  
  /// Find all road tiles that are adjacent to buildings or houses
  List<({int x, int y})> _findRoadTilesNextToBuildings() {
    final spawnTiles = <({int x, int y})>[];
    
    // Find all road tiles and check if they're next to buildings
    for (int y = 0; y < _grid.length; y++) {
      for (int x = 0; x < _grid[y].length; x++) {
        // Must be a road tile
        if (_grid[y][x] == TileType.road) {
          // Check if adjacent to a building or house
          if (_isInFrontOfBuildingOrHouse(x, y)) {
            spawnTiles.add((x: x, y: y));
          }
        }
      }
    }
    
    return spawnTiles;
  }
  
  /// Update pedestrian positions and find new targets
  void _updatePedestrians() {
    const double speed = 0.01; // Grid units per update (50ms = 0.2 grid units per second) - slower
    const double arrivalThreshold = 0.1;
    const int minStepsBeforeDisappear = 30; // Minimum steps before pedestrian can disappear
    const double disappearChance = 0.005; // 0.5% chance per update to disappear when in front of building
    
    // Remove pedestrians that should disappear (only when in front of buildings/houses)
    final pedestriansToRemove = <_PedestrianState>[];
    for (final pedestrian in _pedestrians) {
      if (pedestrian.stepsWalked > minStepsBeforeDisappear) {
        // Check if pedestrian is in front of a building or house
        final gridX = pedestrian.gridX.floor();
        final gridY = pedestrian.gridY.floor();
        if (_isInFrontOfBuildingOrHouse(gridX, gridY)) {
          // Only disappear when in front of building/house
          if (_pedestrianRandom.nextDouble() < disappearChance) {
            pedestriansToRemove.add(pedestrian);
          }
        }
      }
    }
    
    for (final pedestrian in pedestriansToRemove) {
      _pedestrians.remove(pedestrian);
      _usedPersonIds.remove(pedestrian.personId);
    }
    
    // Randomly spawn new pedestrians if we have available personIds
    if (_pedestrians.length < 10 && _pedestrianRandom.nextDouble() < 0.01) { // 1% chance per update
      _spawnSinglePedestrian();
    }
    
    for (final pedestrian in _pedestrians) {
      // Clamp position to stay within map bounds
      pedestrian.gridX = pedestrian.gridX.clamp(0.0, (gridSize - 1).toDouble());
      pedestrian.gridY = pedestrian.gridY.clamp(0.0, (gridSize - 1).toDouble());
      
      // Check if we need a new target
      if (pedestrian.targetGridX == null || pedestrian.targetGridY == null ||
          ((pedestrian.gridX - pedestrian.targetGridX!).abs() < arrivalThreshold &&
           (pedestrian.gridY - pedestrian.targetGridY!).abs() < arrivalThreshold)) {
        
        // Find adjacent valid tiles (road, grass, or park)
        final adjacentTiles = _getAdjacentValidTilesForPedestrian(
          pedestrian.gridX.floor(),
          pedestrian.gridY.floor(),
        );
        
        if (adjacentTiles.isNotEmpty) {
          final random = math.Random();
          final target = adjacentTiles[random.nextInt(adjacentTiles.length)];
          pedestrian.targetGridX = target.x.toDouble();
          pedestrian.targetGridY = target.y.toDouble();
        } else {
          // Find any nearby valid tile
          final nearbyTile = _findNearbyValidTileForPedestrian(
            pedestrian.gridX.floor(),
            pedestrian.gridY.floor(),
          );
          if (nearbyTile != null) {
            pedestrian.targetGridX = nearbyTile.x.toDouble();
            pedestrian.targetGridY = nearbyTile.y.toDouble();
          }
        }
      }
      
      // Move towards target
      if (pedestrian.targetGridX != null && pedestrian.targetGridY != null) {
        // Clamp target to map bounds
        final targetX = pedestrian.targetGridX!.clamp(0.0, (gridSize - 1).toDouble());
        final targetY = pedestrian.targetGridY!.clamp(0.0, (gridSize - 1).toDouble());
        
        final dx = targetX - pedestrian.gridX;
        final dy = targetY - pedestrian.gridY;
        final distance = math.sqrt(dx * dx + dy * dy);
        
        if (distance > arrivalThreshold) {
          final normalizedDx = dx / distance;
          final normalizedDy = dy / distance;
          
          pedestrian.gridX += normalizedDx * speed;
          pedestrian.gridY += normalizedDy * speed;
          
          // Clamp position after movement to stay within bounds
          pedestrian.gridX = pedestrian.gridX.clamp(0.0, (gridSize - 1).toDouble());
          pedestrian.gridY = pedestrian.gridY.clamp(0.0, (gridSize - 1).toDouble());
          
          pedestrian.stepsWalked++; // Increment step counter
          
          // Update direction and flip based on movement
          // Upper right (dy < 0, dx > 0): walk_back flipped
          // Upper left (dy < 0, dx < 0): walk_back original
          // Down right (dy > 0, dx > 0): walk_front original
          // Down left (dy > 0, dx < 0): walk_front flipped


          if (dy.abs() > dx.abs()) {
            // Moving primarily vertical on grid
            if (dy < 0) {
              // Moving Up (Grid Y-) -> Visual Upper Right
              pedestrian.direction = 'front';
              pedestrian.flipHorizontal = false;
            } else {
              // Moving Down (Grid Y+) -> Visual Down Left
              pedestrian.direction = 'front';
              pedestrian.flipHorizontal = true;
            }
          } else {
            // Moving primarily horizontal on grid
            if (dx < 0) {
              // Moving Left (Grid X-) -> Visual Upper Left
              pedestrian.direction = 'front';
              pedestrian.flipHorizontal = true;
            } else {
              // Moving Right (Grid X+) -> Visual Down Right
              pedestrian.direction = 'front';
              pedestrian.flipHorizontal = false;
            }
          }
        } else {
          // Arrived at target
          pedestrian.gridX = pedestrian.targetGridX!;
          pedestrian.gridY = pedestrian.targetGridY!;
          pedestrian.targetGridX = null;
          pedestrian.targetGridY = null;
        }
      }
    }
  }
  
  /// Check if a tile type is valid for pedestrians (only road tiles - sidewalks)
  bool _isValidTileForPedestrian(TileType tileType) {
    return tileType == TileType.road;
  }
  
  /// Get adjacent road tiles for pedestrian pathfinding (sidewalks only)
  List<({int x, int y})> _getAdjacentValidTilesForPedestrian(int gridX, int gridY) {
    final adjacentTiles = <({int x, int y})>[];
    
    final directions = [
      (x: gridX, y: gridY - 1), // Up
      (x: gridX, y: gridY + 1), // Down
      (x: gridX - 1, y: gridY), // Left
      (x: gridX + 1, y: gridY), // Right
    ];
    
    for (final dir in directions) {
      if (dir.y >= 0 && dir.y < _grid.length &&
          dir.x >= 0 && dir.x < _grid[dir.y].length &&
          _isValidTileForPedestrian(_grid[dir.y][dir.x])) {
        adjacentTiles.add(dir);
      }
    }
    
    return adjacentTiles;
  }
  
  /// Find a nearby road tile if current position is not on a road
  ({int x, int y})? _findNearbyValidTileForPedestrian(int gridX, int gridY) {
    for (int radius = 1; radius <= 5; radius++) {
      for (int dy = -radius; dy <= radius; dy++) {
        for (int dx = -radius; dx <= radius; dx++) {
          if (dx.abs() == radius || dy.abs() == radius) {
            final checkX = gridX + dx;
            final checkY = gridY + dy;
            
            if (checkY >= 0 && checkY < _grid.length &&
                checkX >= 0 && checkX < _grid[checkY].length &&
                _isValidTileForPedestrian(_grid[checkY][checkX])) {
              return (x: checkX, y: checkY);
            }
          }
        }
      }
    }
    return null;
  }
  
  /// Build pedestrian widget with animation
  Widget _buildPedestrian(BuildContext context, _PedestrianState pedestrian, Offset centerOffset, double tileWidth, double tileHeight) {
    final pos = _gridToScreenDouble(context, pedestrian.gridX, pedestrian.gridY);
    final positionedX = pos.dx + centerOffset.dx;
    final positionedY = pos.dy + centerOffset.dy;
    
    final double pedestrianSize = tileWidth * 0.3;
    
    // Position on sidewalk (edge of tile) - offset to the right side of the tile
    // Use 75% of tile width to position on the right edge (sidewalk)
    final sidewalkOffset = tileWidth * 0.75; // Position on right edge of tile
    final left = positionedX + sidewalkOffset - pedestrianSize / 2;
    final top = positionedY + (tileHeight / 2) - pedestrianSize / 1.2;
    
    return Positioned(
      left: left,
      top: top,
      width: pedestrianSize,
      height: pedestrianSize,
      child: _AnimatedPedestrian(
        personId: pedestrian.personId,
        direction: pedestrian.direction,
        flipHorizontal: pedestrian.flipHorizontal,
      ),
    );
  }

  void _handleBuildingTap(int gridX, int gridY, TileType tileType) {
    try {
      final zoneX = (gridX + 1).toDouble() + 0.5;
      final zoneY = (gridY + 1).toDouble() + 0.5;

      final zoneType = _tileTypeToZoneType(tileType);
      if (zoneType == null) return;

      // Ensure game controller is ready
      final controller = ref.read(gameControllerProvider.notifier);
      
      // Ensure simulation is running
      if (!controller.isSimulationRunning) {
        controller.startSimulation();
      }

      // Read machines to check if one already exists at this location
      final machines = ref.read(machinesProvider);
      sim.Machine? existingMachine;
      try {
        existingMachine = machines.firstWhere(
          (m) => (m.zone.x - zoneX).abs() < 0.1 && (m.zone.y - zoneY).abs() < 0.1,
        );
      } catch (e) {
        // Machine doesn't exist - will show purchase dialog
      }
      
      if (existingMachine != null) {
        // Machine exists - show status popup
        if (context.mounted) {
          _showMachineView(context, existingMachine);
        }
      } else {
        // Machine doesn't exist - show purchase dialog
        if (!_canPurchaseMachine(zoneType)) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_getProgressionMessage(zoneType)),
                duration: AppConfig.snackbarDurationShort,
              ),
            );
          }
          return;
        }
        
        if (context.mounted) {
          _showMachinePurchaseDialog(context, zoneType, zoneX, zoneY);
        }
      }
    } catch (e) {
      // Handle any errors gracefully
      print('Error handling building tap: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: AppConfig.snackbarDurationShort,
          ),
        );
      }
    }
  }

  bool _shouldShowPurchaseButton(int gridX, int gridY, TileType tileType) {
    final zoneX = (gridX + 1).toDouble() + 0.5;
    final zoneY = (gridY + 1).toDouble() + 0.5;

    final zoneType = _tileTypeToZoneType(tileType);
    if (zoneType == null) return false;

    if (!_canPurchaseMachine(zoneType)) return false;

    final machines = ref.watch(machinesProvider);
    final hasExistingMachine = machines.any(
      (m) => (m.zone.x - zoneX).abs() < 0.1 && (m.zone.y - zoneY).abs() < 0.1,
    );

    return !hasExistingMachine;
  }

  ZoneType? _tileTypeToZoneType(TileType tileType) {
    switch (tileType) {
      case TileType.shop: return ZoneType.shop;
      case TileType.school: return ZoneType.school;
      case TileType.gym: return ZoneType.gym;
      case TileType.office: return ZoneType.office;
      case TileType.subway: return ZoneType.subway;
      case TileType.hospital: return ZoneType.hospital;
      case TileType.university: return ZoneType.university;
      default: return null;
    }
  }

  bool _canPurchaseMachine(ZoneType zoneType) {
    final machines = ref.read(machinesProvider);
    // All machine types are available from the start - just check if under limit
    final machinesOfType = machines.where((m) => m.zone.type == zoneType).length;
    return machinesOfType < AppConfig.machineLimitPerType;
  }

  String _getProgressionMessage(ZoneType zoneType) {
    final machines = ref.read(machinesProvider);
    final machinesOfType = machines.where((m) => m.zone.type == zoneType).length;
    final limit = AppConfig.machineLimitPerType;
    
    if (machinesOfType >= limit) {
      return '${zoneType.name.toUpperCase()} limit reached (have $machinesOfType/$limit)';
    }
    return 'Can purchase ${zoneType.name} machines ($machinesOfType/$limit)';
  }

  Widget _buildGroundTile(TileType tileType, RoadDirection? roadDir) {
    final isRoad = tileType == TileType.road;
    final needsFlip = isRoad && roadDir == RoadDirection.vertical;

    Widget imageWidget = Image.asset(
      _getTileAssetPath(tileType, roadDir),
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: _getFallbackColor(tileType),
          alignment: Alignment.bottomCenter,
          child: Text(
            _getTileLabel(tileType),
            style: TextStyle(
            fontSize: ScreenUtils.relativeFontSize(
              context,
              AppConfig.fontSizeFactorTiny,
              min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
              max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
            ),
          ),
          ),
        );
      },
    );

    if (needsFlip) {
      return Transform(
        alignment: Alignment.bottomCenter,
        transform: Matrix4.identity()..scale(-1.0, 1.0),
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildBuildingTile(TileType tileType, BuildingOrientation? orientation) {
    Widget imageWidget = Image.asset(
      _getTileAssetPath(tileType, null),
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: _getFallbackColor(tileType),
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall)),
            child: Text(
              _getTileLabel(tileType),
              style: TextStyle(
              fontSize: ScreenUtils.relativeFontSize(
                context,
                AppConfig.fontSizeFactorTiny,
                min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
              ),
            ),
            ),
          ),
        );
      },
    );

    if (orientation == BuildingOrientation.flippedHorizontal) {
      return Transform(
        alignment: Alignment.bottomCenter,
        transform: Matrix4.identity()..scaleByVector3(Vector3(-1.0, 1.0, 1.0)),
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Color _getFallbackColor(TileType tileType) {
    switch (tileType) {
      case TileType.grass: return Colors.green.shade300;
      case TileType.road: return Colors.grey.shade600;
      case TileType.shop: return Colors.blue.shade300;
      case TileType.gym: return Colors.red.shade300;
      case TileType.office: return Colors.orange.shade300;
      case TileType.school: return Colors.purple.shade300;
      case TileType.gasStation: return Colors.yellow.shade300;
      case TileType.park: return Colors.green.shade400;
      case TileType.house: return Colors.brown.shade300;
      case TileType.warehouse: return Colors.grey.shade400;
      case TileType.subway: return Colors.blueGrey.shade300;
      case TileType.hospital: return Colors.white;
      case TileType.university: return Colors.indigo.shade300;
    }
  }

  String _getTileLabel(TileType tileType) {
    switch (tileType) {
      case TileType.grass: return 'G';
      case TileType.road: return 'R';
      case TileType.shop: return 'S';
      case TileType.gym: return 'G';
      case TileType.office: return 'O';
      case TileType.school: return 'Sc';
      case TileType.gasStation: return 'GS';
      case TileType.park: return 'P';
      case TileType.house: return 'H';
      case TileType.warehouse: return 'W';
      case TileType.subway: return 'Sub';
      case TileType.hospital: return 'Hos';
      case TileType.university: return 'Uni';
    }
  }
}

class _MachineViewDialog extends ConsumerWidget {
  final String machineId;
  final String imagePath;

  const _MachineViewDialog({
    required this.machineId,
    required this.imagePath,
  });

  /// Handles the logic when a customer makes a purchase
  void _handlePurchase(WidgetRef ref, bool isSpecial) {
    // 1. Get current machine state
    final machines = ref.read(machinesProvider);
    final machineIndex = machines.indexWhere((m) => m.id == machineId);
    if (machineIndex == -1) return;
    final machine = machines[machineIndex];

    // 2. Determine "Bundle" size
    // Normal: 1 Soda + 1 Chips
    // Special: 2 Soda + 2 Chips (Double Benefit)
    final multiplier = isSpecial ? 2 : 1;
    final requiredSoda = 1 * multiplier;
    final requiredChips = 1 * multiplier;

    // 3. Check and deduct inventory
    final newInventory = Map<Product, sim.InventoryItem>.from(machine.inventory);
    double earnedCash = 0.0;
    bool soldAnything = false;

    // Process Soda
    if (newInventory.containsKey(Product.soda)) {
      final item = newInventory[Product.soda]!;
      final soldQty = math.min(item.quantity, requiredSoda);
      if (soldQty > 0) {
        newInventory[Product.soda] = item.copyWith(quantity: item.quantity - soldQty);
        earnedCash += soldQty * Product.soda.basePrice;
        soldAnything = true;
      }
    }

    // Process Chips
    if (newInventory.containsKey(Product.chips)) {
      final item = newInventory[Product.chips]!;
      final soldQty = math.min(item.quantity, requiredChips);
      if (soldQty > 0) {
        newInventory[Product.chips] = item.copyWith(quantity: item.quantity - soldQty);
        earnedCash += soldQty * Product.chips.basePrice;
        soldAnything = true;
      }
    }

    // 4. Apply Updates if purchase happened
    if (soldAnything) {
      // If Special person (Any Zone), apply Double Benefit to the cash earned
      // (They buy 2x items naturally, but we can add a bonus multiplier if desired. 
      //  Here we stick to the volume benefit: 2x items = 2x cash).
      
      final updatedMachine = machine.copyWith(
        inventory: newInventory,
        currentCash: machine.currentCash + earnedCash,
        totalSales: machine.totalSales + (isSpecial ? 2 : 1), 
      );

      // Update Controller
      ref.read(gameControllerProvider.notifier).updateMachine(updatedMachine);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final machines = ref.watch(machinesProvider);
    
    sim.Machine? machine;
    try {
      machine = machines.firstWhere((m) => m.id == machineId);
    } catch (e) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: const Text('Machine not found', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
      );
    }
    
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogMaxWidth = screenWidth * AppConfig.machineStatusDialogWidthFactor;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(
        ScreenUtils.relativeSize(context, AppConfig.machineStatusDialogInsetPaddingFactor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dialogWidth = constraints.maxWidth;
          final imageHeight = dialogWidth * AppConfig.machineStatusDialogImageHeightFactor;
          final borderRadius = dialogWidth * AppConfig.machineStatusDialogBorderRadiusFactor;
          final padding = dialogWidth * AppConfig.machineStatusDialogPaddingFactor;
          
          return Container(
            constraints: BoxConstraints(
              maxWidth: dialogMaxWidth,
              maxHeight: screenHeight * AppConfig.machineStatusDialogHeightFactor,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(borderRadius),
                        topRight: Radius.circular(borderRadius),
                      ),
                      child: Image.asset(
                        imagePath,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: imageHeight,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: double.infinity, 
                          height: imageHeight, 
                          color: Colors.grey[800]
                        ),
                      ),
                    ),
                    // Animated person at machine overlay
                    if (machine != null)
                      Positioned(
                        bottom: imageHeight * -0.15, 
                        left: 0, 
                        child: SizedBox(
                          width: dialogWidth, 
                          height: imageHeight * 1.0, 
                          child: _AnimatedPersonMachine(
                            zoneType: machine.zone.type,
                            machineId: machine.id,
                            dialogWidth: dialogWidth,
                            imageHeight: imageHeight,
                            onPurchase: (isSpecial) => _handlePurchase(ref, isSpecial), // Pass callback
                          ),
                        ),
                      ),
                    Positioned(
                      top: padding * AppConfig.machineStatusDialogHeaderImageTopPaddingFactor,
                      right: padding * AppConfig.machineStatusDialogHeaderImageTopPaddingFactor,
                      child: IconButton(
                        icon: Icon(Icons.close, color: Colors.white, size: dialogWidth * AppConfig.machineStatusDialogCloseButtonSizeFactor),
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(backgroundColor: Colors.black.withValues(alpha: 0.5), padding: EdgeInsets.all(padding * AppConfig.machineStatusDialogCloseButtonPaddingFactor)),
                      ),
                    ),
                  ],
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(padding),
                      child: _MachineStatusSection(machine: machine!, dialogWidth: dialogWidth),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MachineStatusSection extends ConsumerWidget {
  final sim.Machine machine;
  final double dialogWidth;

  const _MachineStatusSection({
    required this.machine,
    required this.dialogWidth,
  });

  double _getStockLevel(sim.Machine machine) {
    const maxCapacity = AppConfig.machineMaxCapacity;
    final currentStock = machine.totalInventory.toDouble();
    return (currentStock / maxCapacity).clamp(0.0, 1.0);
  }

  Color _getStockColor(sim.Machine machine) {
    final level = _getStockLevel(machine);
    if (level > 0.5) return Colors.green;
    if (level > 0.2) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stockLevel = _getStockLevel(machine);
    final stockColor = _getStockColor(machine);
    final zoneIcon = machine.zone.type.icon;
    final zoneColor = machine.zone.type.color;
    final isBroken = machine.isBroken;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: dialogWidth * AppConfig.machineStatusDialogZoneIconContainerSizeFactor,
              height: dialogWidth * AppConfig.machineStatusDialogZoneIconContainerSizeFactor,
              decoration: BoxDecoration(
                color: zoneColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                zoneIcon,
                color: zoneColor,
                size: dialogWidth * AppConfig.machineStatusDialogZoneIconSizeFactor,
              ),
            ),
            SizedBox(
              width: dialogWidth * AppConfig.machineStatusDialogZoneIconSpacingFactor,
            ),
            Expanded(
              child: Text(
                machine.name,
                style: TextStyle(
                  fontSize: dialogWidth * AppConfig.machineStatusDialogMachineNameFontSizeFactor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (isBroken)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'BROKEN',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: dialogWidth * 0.035,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(
          height: dialogWidth * AppConfig.machineStatusDialogSectionSpacingFactor,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stock: ${machine.totalInventory} items',
              style: TextStyle(
                fontSize: dialogWidth * AppConfig.machineStatusDialogStockTextFontSizeFactor,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(
              height: dialogWidth * AppConfig.machineStatusDialogStockProgressSpacingFactor,
            ),
            LinearProgressIndicator(
              value: stockLevel,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(stockColor),
              minHeight: dialogWidth * AppConfig.machineStatusDialogProgressBarHeightFactor,
            ),
          ],
        ),
        SizedBox(
          height: dialogWidth * AppConfig.machineStatusDialogSectionSpacingFactor,
        ),
        Container(
          padding: EdgeInsets.all(
            dialogWidth * AppConfig.machineStatusDialogInfoContainerPaddingFactor,
          ),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(
              dialogWidth * AppConfig.machineStatusDialogInfoContainerBorderRadiusFactor,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cash',
                    style: TextStyle(
                      fontSize: dialogWidth * AppConfig.machineStatusDialogInfoLabelFontSizeFactor,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    '\$${machine.currentCash.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: dialogWidth * AppConfig.machineStatusDialogInfoValueFontSizeFactor,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          height: dialogWidth * AppConfig.machineStatusDialogSectionSpacingFactor,
        ),
        Divider(
          height: dialogWidth * AppConfig.machineStatusDialogDividerHeightFactor,
        ),
        SizedBox(
          height: dialogWidth * AppConfig.machineStatusDialogSectionSpacingFactor,
        ),
        Text(
          'Stock Details:',
          style: TextStyle(
            fontSize: dialogWidth * AppConfig.machineStatusDialogStockDetailsTitleFontSizeFactor,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(
          height: dialogWidth * AppConfig.machineStatusDialogStockDetailsSpacingFactor,
        ),
        if (machine.inventory.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: dialogWidth * AppConfig.machineStatusDialogStockItemPaddingFactor,
            ),
            child: Text(
              'Empty',
              style: TextStyle(
                fontSize: dialogWidth * AppConfig.machineStatusDialogStockItemFontSizeFactor,
                fontStyle: FontStyle.italic,
                color: Colors.grey[600],
              ),
            ),
          )
        else
          ...machine.inventory.values.map((item) => Padding(
            padding: EdgeInsets.only(
              bottom: dialogWidth * AppConfig.machineStatusDialogStockItemPaddingFactor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.product.name,
                            style: TextStyle(
                              fontSize: dialogWidth * AppConfig.machineStatusDialogStockItemFontSizeFactor,
                            ),
                          ),
                          SizedBox(height: dialogWidth * AppConfig.machineStatusDialogStockItemPaddingFactor * 0.3),
                          Text(
                            '\$${item.product.basePrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: dialogWidth * AppConfig.machineStatusDialogStockItemFontSizeFactor * 0.85,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: dialogWidth * AppConfig.machineStatusDialogStockItemBadgePaddingHorizontalFactor,
                        vertical: dialogWidth * AppConfig.machineStatusDialogStockItemBadgePaddingVerticalFactor,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(
                          dialogWidth * AppConfig.machineStatusDialogStockItemBadgeBorderRadiusFactor,
                        ),
                      ),
                      child: Text(
                        '${item.quantity}',
                        style: TextStyle(
                          fontSize: dialogWidth * AppConfig.machineStatusDialogStockItemBadgeFontSizeFactor,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: dialogWidth * AppConfig.machineStatusDialogStockItemPaddingFactor * 0.5),
                // Customer Interest Progress Bar
                LinearProgressIndicator(
                  value: item.customerInterest,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    item.customerInterest > 0.7 
                      ? Colors.green 
                      : item.customerInterest > 0.4 
                        ? Colors.orange 
                        : Colors.blue,
                  ),
                  minHeight: dialogWidth * 0.008,
                ),
              ],
            ),
          )),
        SizedBox(
          height: dialogWidth * AppConfig.machineStatusDialogSectionSpacingFactor,
        ),
        
        // REPAIR BUTTON (Only if broken)
        if (isBroken)
          Padding(
            padding: EdgeInsets.only(bottom: dialogWidth * 0.03),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final controller = ref.read(gameControllerProvider.notifier);
                  // Assuming repairMachine exists in your controller/provider
                  // Since you mentioned you already implemented it.
                  controller.repairMachine(machine.id);
                  // Optionally close dialog or show snackbar
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Machine repaired!'), duration: Duration(seconds: 1)),
                  );
                },
                icon: Icon(
                  Icons.build,
                  size: dialogWidth * AppConfig.machineStatusDialogCashIconSizeFactor,
                ),
                label: Text(
                  'Repair Machine (\$150)',
                  style: TextStyle(
                    fontSize: dialogWidth * AppConfig.machineStatusDialogCashTextFontSizeFactor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    vertical: dialogWidth * AppConfig.machineStatusDialogCashButtonPaddingFactor,
                  ),
                ),
              ),
            ),
          ),

        // OPEN MACHINE BUTTON (Always visible now)
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              // Close current dialog and open interior dialog
              Navigator.of(context).pop();
              showDialog(
                context: context,
                barrierColor: Colors.black.withValues(alpha: 0.7),
                builder: (context) => MachineInteriorDialog(machine: machine),
              );
            },
            icon: Icon(
              Icons.open_in_new,
              size: dialogWidth * AppConfig.machineStatusDialogCashIconSizeFactor,
            ),
            label: Text(
              'Open Machine',
              style: TextStyle(
                fontSize: dialogWidth * AppConfig.machineStatusDialogCashTextFontSizeFactor,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                vertical: dialogWidth * AppConfig.machineStatusDialogCashButtonPaddingFactor,
              ),
            ),
          ),
        ),
        // Retrieve cash button removed - cash collection is now done via Open Machine dialog
      ],
    );
  }
}

/// Refactored Button Widget that handles the tap/drag distinction logic
class _PurchaseButton extends StatefulWidget {
  final VoidCallback onTap;
  final double size;

  const _PurchaseButton({
    required this.onTap,
    required this.size,
  });

  @override
  State<_PurchaseButton> createState() => _PurchaseButtonState();
}

class _PurchaseButtonState extends State<_PurchaseButton> {
  Offset? _pointerDownPosition;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        _pointerDownPosition = event.position;
      },
      onPointerUp: (event) {
        if (_pointerDownPosition != null) {
          // If the pointer moved less than 10 pixels, treat it as a tap
          final distance = (event.position - _pointerDownPosition!).distance;
          if (distance < 10.0) {
            widget.onTap();
          }
        }
        _pointerDownPosition = null;
      },
      onPointerCancel: (_) => _pointerDownPosition = null,
      behavior: HitTestBehavior.opaque,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            customBorder: const CircleBorder(),
            splashColor: Colors.green.shade300,
            highlightColor: Colors.green.shade200,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: ScreenUtils.relativeSize(context, 0.004),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: ScreenUtils.relativeSize(context, 0.008),
                    offset: Offset(0, ScreenUtils.relativeSize(context, 0.004)),
                  ),
                ],
              ),
              child: Icon(
                Icons.add,
                color: Colors.white,
                size: widget.size * 0.75,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialog for purchasing a machine (shown when machine doesn't exist yet)
class _MachinePurchaseDialog extends ConsumerWidget {
  final ZoneType zoneType;
  final double zoneX;
  final double zoneY;
  final String imagePath;
  final double price;
  final VoidCallback onPurchased;

  const _MachinePurchaseDialog({
    required this.zoneType,
    required this.zoneX,
    required this.zoneY,
    required this.imagePath,
    required this.price,
    required this.onPurchased,
  });

  String _getZoneName(ZoneType zoneType) {
    switch (zoneType) {
      case ZoneType.shop:
        return 'Shop';
      case ZoneType.school:
        return 'School';
      case ZoneType.gym:
        return 'Gym';
      case ZoneType.office:
        return 'Office';
      case ZoneType.subway:
        return 'Subway';
      case ZoneType.hospital:
        return 'Hospital';
      case ZoneType.university:
        return 'University';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cash = ref.watch(cashProvider);
    final canAfford = cash >= price;
    
    // Calculate the actual dialog width
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogMaxWidth = screenWidth * AppConfig.machineStatusDialogWidthFactor;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(
        ScreenUtils.relativeSize(context, AppConfig.machineStatusDialogInsetPaddingFactor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Use the actual constrained width for sizing
          final dialogWidth = constraints.maxWidth;
          final imageHeight = dialogWidth * AppConfig.machineStatusDialogImageHeightFactor;
          final borderRadius = dialogWidth * AppConfig.machineStatusDialogBorderRadiusFactor;
          final padding = dialogWidth * AppConfig.machineStatusDialogPaddingFactor;
          
          return Container(
            constraints: BoxConstraints(
              maxWidth: dialogMaxWidth,
              maxHeight: screenHeight * AppConfig.machineStatusDialogHeightFactor,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(borderRadius),
                        topRight: Radius.circular(borderRadius),
                      ),
                      child: Image.asset(
                        imagePath,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: imageHeight,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: double.infinity,
                            height: imageHeight,
                            color: Colors.grey[800],
                            child: Center(
                              child: Text(
                                'View image not found',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: dialogWidth * AppConfig.machineStatusDialogErrorTextFontSizeFactor,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      top: padding * AppConfig.machineStatusDialogHeaderImageTopPaddingFactor,
                      right: padding * AppConfig.machineStatusDialogHeaderImageTopPaddingFactor,
                      child: IconButton(
                        icon: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: dialogWidth * AppConfig.machineStatusDialogCloseButtonSizeFactor,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.5),
                          padding: EdgeInsets.all(
                            padding * AppConfig.machineStatusDialogCloseButtonPaddingFactor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(padding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: dialogWidth * AppConfig.machineStatusDialogZoneIconContainerSizeFactor,
                                height: dialogWidth * AppConfig.machineStatusDialogZoneIconContainerSizeFactor,
                                decoration: BoxDecoration(
                                  color: zoneType.color.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  zoneType.icon,
                                  color: zoneType.color,
                                  size: dialogWidth * AppConfig.machineStatusDialogZoneIconSizeFactor,
                                ),
                              ),
                              SizedBox(
                                width: dialogWidth * AppConfig.machineStatusDialogZoneIconSpacingFactor,
                              ),
                              Expanded(
                                child: Text(
                                  '${_getZoneName(zoneType)} Machine',
                                  style: TextStyle(
                                    fontSize: dialogWidth * AppConfig.machineStatusDialogMachineNameFontSizeFactor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            height: dialogWidth * AppConfig.machineStatusDialogSectionSpacingFactor,
                          ),
                          Container(
                            padding: EdgeInsets.all(
                              dialogWidth * AppConfig.machineStatusDialogInfoContainerPaddingFactor,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                dialogWidth * AppConfig.machineStatusDialogInfoContainerBorderRadiusFactor,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Price',
                                      style: TextStyle(
                                        fontSize: dialogWidth * AppConfig.machineStatusDialogInfoLabelFontSizeFactor,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      '\$${price.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: dialogWidth * AppConfig.machineStatusDialogInfoValueFontSizeFactor,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Your Cash',
                                      style: TextStyle(
                                        fontSize: dialogWidth * AppConfig.machineStatusDialogInfoLabelFontSizeFactor,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      '\$${cash.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: dialogWidth * AppConfig.machineStatusDialogInfoValueFontSizeFactor,
                                        fontWeight: FontWeight.bold,
                                        color: canAfford ? Colors.green : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (!canAfford) ...[
                            SizedBox(
                              height: dialogWidth * AppConfig.machineStatusDialogSectionSpacingFactor,
                            ),
                            Text(
                              'Insufficient funds',
                              style: TextStyle(
                                fontSize: dialogWidth * AppConfig.machineStatusDialogStockTextFontSizeFactor,
                                color: Colors.red,
                              ),
                            ),
                          ],
                          SizedBox(
                            height: dialogWidth * AppConfig.machineStatusDialogSectionSpacingFactor,
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: canAfford
                                  ? () {
                                      final controller = ref.read(gameControllerProvider.notifier);
                                      controller.buyMachineWithStock(zoneType, x: zoneX, y: zoneY);
                                      onPurchased();
                                    }
                                  : null,
                              icon: Icon(
                                Icons.shopping_cart,
                                size: dialogWidth * AppConfig.machineStatusDialogCashIconSizeFactor,
                              ),
                              label: Text(
                                'Buy Machine',
                                style: TextStyle(
                                  fontSize: dialogWidth * AppConfig.machineStatusDialogCashTextFontSizeFactor,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey,
                                disabledForegroundColor: Colors.grey[400],
                                padding: EdgeInsets.symmetric(
                                  vertical: dialogWidth * AppConfig.machineStatusDialogCashButtonPaddingFactor,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    dialogWidth * AppConfig.machineStatusDialogCashButtonBorderRadiusFactor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Widget that renders an animated pedestrian with sprite extraction
class _AnimatedPedestrian extends StatefulWidget {
  final int personId; // 0-9
  final String direction; // 'front' or 'back'
  final bool flipHorizontal;
  
  const _AnimatedPedestrian({
    required this.personId,
    required this.direction,
    required this.flipHorizontal,
  });
  
  @override
  State<_AnimatedPedestrian> createState() => _AnimatedPedestrianState();
}

class _AnimatedPedestrianState extends State<_AnimatedPedestrian> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<ImageProvider>? _frameImages;
  Size? _spriteSize;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000), // 10 frames * 100ms
      vsync: this,
    )..repeat();
    
    _loadFrames();
  }
  
  Future<void> _loadFrames() async {
    try {
      // Load first frame to get dimensions
      final firstFrameAsset = 'assets/images/pedestrian_walk/walk_${widget.direction}_0.png';
      final firstImage = AssetImage(firstFrameAsset);
      final completer = Completer<ImageInfo>();
      final stream = firstImage.resolve(const ImageConfiguration());
      late ImageStreamListener listener;
      listener = ImageStreamListener((info, synchronousCall) {
        completer.complete(info);
        stream.removeListener(listener);
      });
      stream.addListener(listener);
      final firstImageInfo = await completer.future;
      final firstImageSize = firstImageInfo.image.width;
      final firstImageHeight = firstImageInfo.image.height;
      
      // Calculate sprite size: 2 rows x 5 columns
      final spriteWidth = firstImageSize / 5;
      final spriteHeight = firstImageHeight / 2;
      _spriteSize = Size(spriteWidth, spriteHeight);
      
      // Load all 10 frames
      final frames = <ImageProvider>[];
      for (int i = 0; i < 10; i++) {
        frames.add(AssetImage('assets/images/pedestrian_walk/walk_${widget.direction}_$i.png'));
      }
      
      if (mounted) {
        setState(() {
          _frameImages = frames;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading pedestrian frames: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  void didUpdateWidget(_AnimatedPedestrian oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.direction != widget.direction) {
      _loadFrames();
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading || _frameImages == null || _spriteSize == null) {
      return Container(
        color: Colors.transparent,
        child: const SizedBox.shrink(),
      );
    }
    
    // Calculate grid position for this personId
    final row = widget.personId ~/ 5;
    final col = widget.personId % 5;
    
    // Calculate source rect for sprite extraction
    final srcLeft = col * _spriteSize!.width;
    final srcTop = row * _spriteSize!.height;
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Get current frame index (0-9)
        final frameIndex = ((_controller.value * 10) % 10).floor();
        final imageProvider = _frameImages![frameIndex];
        
        Widget image = CustomPaint(
          size: Size(_spriteSize!.width, _spriteSize!.height),
          painter: _PedestrianSpritePainter(
            imageProvider: imageProvider,
            srcRect: Rect.fromLTWH(
              srcLeft,
              srcTop,
              _spriteSize!.width,
              _spriteSize!.height,
            ),
          ),
        );
        
        if (widget.flipHorizontal) {
          image = Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..scale(-1.0, 1.0),
            child: image,
          );
        }
        
        return image;
      },
    );
  }
}

/// Custom painter that extracts a sprite from a larger image
class _PedestrianSpritePainter extends CustomPainter {
  final ImageProvider imageProvider;
  final Rect srcRect;
  ImageInfo? _imageInfo;
  
  _PedestrianSpritePainter({
    required this.imageProvider,
    required this.srcRect,
  }) {
    _loadImage();
  }
  
  void _loadImage() {
    final stream = imageProvider.resolve(const ImageConfiguration());
    stream.addListener(ImageStreamListener((info, synchronousCall) {
      _imageInfo = info;
    }));
  }
  
  @override
  void paint(Canvas canvas, Size size) {
    if (_imageInfo == null) return;
    
    final image = _imageInfo!.image;
    final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);
    
    canvas.drawImageRect(
      image,
      srcRect,
      dstRect,
      Paint(),
    );
  }
  
  @override
  bool shouldRepaint(_PedestrianSpritePainter oldDelegate) {
    return oldDelegate.imageProvider != imageProvider ||
           oldDelegate.srcRect != srcRect;
  }
}

enum _AnimationState {
  waiting,          // New state: Waiting for customer to appear
  walkingToMachine, 
  backAnimation,    
  pausing,          
  walkingAway,      
}

class _AnimatedPersonMachine extends StatefulWidget {
  final ZoneType zoneType;
  final String machineId; 
  final double dialogWidth; 
  final double imageHeight; 
  final Function(bool isSpecial) onPurchase; // Callback for purchase

  const _AnimatedPersonMachine({
    required this.zoneType,
    required this.machineId,
    required this.dialogWidth,
    required this.imageHeight,
    required this.onPurchase,
  });

  @override
  State<_AnimatedPersonMachine> createState() => _AnimatedPersonMachineState();
}

class _AnimatedPersonMachineState extends State<_AnimatedPersonMachine>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<ImageInfo>? _walkFrameImageInfos;
  List<ImageInfo>? _backFrameImageInfos;
  Size? _spriteSize;
  int? _personIndex;
  bool _isLoading = true;
  bool _isSpecial = false; 
  
  // State Management
  _AnimationState _currentState = _AnimationState.waiting; 
  Timer? _pauseTimer;
  Timer? _walkUpdateTimer; 
  Timer? _walkAwayTimer;   
  
  double _vendingMachinePosition = 0.0;
  DateTime? _walkStartTime; 
  double _walkProgress = 0.0;     
  double _walkAwayProgress = 0.0; 
  DateTime? _walkAwayStartTime;

  // --- CONFIGURATION CONSTANTS (TWEAK THESE) ---
  
  // 1. STOP POSITION: Machine is on LEFT side of image
  // Position is calculated as: dialogWidth * (factor + offsetFactor)
  // Lower values = more LEFT, Higher values = more RIGHT
  // NOTE: This position represents where the LEFT EDGE of the character stops
  // Both factor and offsetFactor are relative (0.0 to 1.0 = 0% to 100% of dialog width)
  // Machine is on far left, so character should be positioned very close to left edge
  static const double _vendingMachinePositionFactor = 0.0; // Base position factor (0% = left edge)
  static const double _stopPositionOffsetFactor = -0.25; // Relative offset factor (negative = left, positive = right)

  // 2. FLIP CORRECTION: Compensates for visual jump when sprite flips horizontally
  // When flipping, the sprite's anchor point may cause a visual offset
  static const double _flipCorrection = 0.0;
  
  // 3. ROW OFFSET: Adjust vertical position for 2nd row characters (indices 5-9)
  // 2nd row characters appear slightly higher in sprite sheet, so lower them
  static const double _secondRowVerticalOffset = 10.0; // Pixels to lower 2nd row characters
  
  // 4. COLUMN OFFSETS: Adjust horizontal position for each column (0-4) within sprite sheet
  // Each person in the 5 columns may be positioned differently within their sprite cell
  // These are relative offsets (as percentage of dialog width) to fine-tune horizontal position
  static const List<double> _columnHorizontalOffsets = [
    0.0,   // Column 0: no adjustment
    0.0,   // Column 1: no adjustment
    0.0,   // Column 2: no adjustment
    0.00,   // Column 3: no adjustment
    0.05,   // Column 4: no adjustment
  ];
  
  // 4. LOOP ANIMATION: Restart animation when character finishes walking away
  static const bool _loopAnimation = true;
  
  // 5. DEBUG: Show bounding box around character (set to true to visualize)
  static const bool _showDebugBox = false;

  // 3. ANIMATION SETTINGS
  static const double _spriteScaleX = 0.4; // Width scale
  static const Duration _walkToMachineDuration = Duration(seconds: 3); 
  static const Duration _walkAwayDuration = Duration(seconds: 2); // Faster walk away 

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000), 
      vsync: this,
    )..repeat();

    _calculatePersonIndex();
    _loadFrames();
  }

  @override
  void dispose() {
    _pauseTimer?.cancel();
    _walkUpdateTimer?.cancel();
    _walkAwayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _calculatePersonIndex() {
    final random = math.Random();
    
    // Hospital and Subway can use any customer type (shop, school, gym, office, or special)
    if (widget.zoneType == ZoneType.hospital || widget.zoneType == ZoneType.subway) {
      // Randomly select from all available customer types
      final customerType = random.nextInt(5); // 0-4 for shop, gym, school, office, special
      
      if (customerType == 4) {
        // Special customers (20% chance)
        _isSpecial = true;
        _personIndex = 8 + random.nextInt(2);
      } else {
        // Regular customer types (80% chance)
        _isSpecial = false;
        final baseIndex = customerType * 2; // 0, 2, 4, or 6
        _personIndex = baseIndex + random.nextInt(2);
      }
    } else {
      // 1. Determine if "Special" (Any Zone)
      // 20% chance for Special (Indices 8, 9)
      if (random.nextDouble() < 0.20) { 
        _isSpecial = true;
        _personIndex = 8 + random.nextInt(2); 
      } else {
        _isSpecial = false;
        // Zone specific (Normal)
        final baseIndex = _getBasePersonIndexForZone(widget.zoneType);
        _personIndex = baseIndex + random.nextInt(2); 
      }
    }
  }

  int _getBasePersonIndexForZone(ZoneType zoneType) {
    switch (zoneType) {
      case ZoneType.shop: return 0; // Uses indices 0-1
      case ZoneType.gym: return 2;  // Uses indices 2-3
      case ZoneType.school: return 4; // Uses indices 4-5
      case ZoneType.office: return 6; // Uses indices 6-7
      case ZoneType.university: return 0; // Uses indices 0-1 (same as shop)
      case ZoneType.subway: // Always uses special (8-9), handled in _calculatePersonIndex
      case ZoneType.hospital: // Always uses special (8-9), handled in _calculatePersonIndex
        return 0; // Fallback, but should not be reached
      // Indices 8-9 are special and can be used for any zone
    }
  }

  Future<void> _loadFrames() async {
    try {
      // 1. Load first frame to get dimensions
      final firstFrameAsset = 'assets/images/person_machine/person_machine_walk_0.png';
      final firstImage = AssetImage(firstFrameAsset);
      final completer = Completer<ImageInfo>();
      final stream = firstImage.resolve(const ImageConfiguration());
      
      late ImageStreamListener listener;
      listener = ImageStreamListener((info, synchronousCall) {
        completer.complete(info);
        stream.removeListener(listener);
      });
      stream.addListener(listener);
      final firstImageInfo = await completer.future;
      
      final spriteWidth = firstImageInfo.image.width / 5;
      final spriteHeight = firstImageInfo.image.height / 2;
      _spriteSize = Size(spriteWidth, spriteHeight);

      // 2. Preload Walk Frames
      final walkFrameImageInfos = <ImageInfo>[];
      for (int i = 0; i < 10; i++) {
        final frameAsset = 'assets/images/person_machine/person_machine_walk_$i.png';
        await _preloadImage(frameAsset).then((info) => walkFrameImageInfos.add(info));
      }

      // 3. Preload Back Frames
      final backFrameImageInfos = <ImageInfo>[];
      for (int i = 1; i <= 4; i++) {
        final frameAsset = 'assets/images/person_machine/person_machine_back_$i.png';
        await _preloadImage(frameAsset).then((info) => backFrameImageInfos.add(info));
      }

      _vendingMachinePosition = widget.dialogWidth * (_vendingMachinePositionFactor + _stopPositionOffsetFactor);
      
      if (mounted) {
        setState(() {
          _walkFrameImageInfos = walkFrameImageInfos;
          _backFrameImageInfos = backFrameImageInfos;
          _isLoading = false;
        });
        // Start waiting cycle instead of walking immediately
        _startWaiting();
      }
    } catch (e) {
      debugPrint('Error loading frames: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<ImageInfo> _preloadImage(String assetPath) async {
    final completer = Completer<ImageInfo>();
    final img = AssetImage(assetPath);
    final stream = img.resolve(const ImageConfiguration());
    late ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      completer.complete(info);
      stream.removeListener(listener);
    });
    stream.addListener(listener);
    return completer.future;
  }

  // --- LOGIC: WAITING ---
  void _startWaiting() {
    setState(() => _currentState = _AnimationState.waiting);
    // Random wait time (5 to 30 seconds) - customers appear less often
    final waitTime = Duration(milliseconds: 5000 + math.Random().nextInt(25000));
    
    _pauseTimer?.cancel();
    _pauseTimer = Timer(waitTime, () {
      if (mounted) {
        _walkStartTime = DateTime.now();
        _walkProgress = 0.0;
        _startWalkInTimer();
        setState(() => _currentState = _AnimationState.walkingToMachine);
      }
    });
  }

  // --- LOGIC: WALK IN ---
  void _startWalkInTimer() {
    _walkUpdateTimer?.cancel();
    _walkUpdateTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted || _currentState != _AnimationState.walkingToMachine) {
        timer.cancel();
        return;
      }

      final elapsed = DateTime.now().difference(_walkStartTime!);
      final progress = (elapsed.inMilliseconds / _walkToMachineDuration.inMilliseconds).clamp(0.0, 1.0);

      setState(() {
        _walkProgress = progress;
      });

      if (_walkProgress >= 1.0) {
        timer.cancel();
        _startBackAnimation();
      }
    });
  }

  // --- LOGIC: INTERACT ---
  void _startBackAnimation() {
    setState(() {
      _walkProgress = 1.0; 
      _currentState = _AnimationState.backAnimation;
    });
    
    // TRIGGER PURCHASE HERE
    widget.onPurchase(_isSpecial);

    _controller.duration = const Duration(milliseconds: 1000); 
    _controller.reset();
    _controller.forward().then((_) {
      if (mounted) {
        setState(() => _currentState = _AnimationState.pausing);
        _pauseTimer = Timer(const Duration(seconds: 1), () {
          if (mounted) _startWalkingAway();
        });
      }
    });
  }

  // --- LOGIC: WALK AWAY ---
  void _startWalkingAway() {
    setState(() {
      _currentState = _AnimationState.walkingAway;
      _walkAwayProgress = 0.0;
      _walkAwayStartTime = DateTime.now();
    });
    
    _controller.duration = const Duration(milliseconds: 1000); 
    _controller.repeat();
    
    _walkAwayTimer?.cancel();
    _walkAwayTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted || _currentState != _AnimationState.walkingAway) {
        timer.cancel();
        return;
      }

      final elapsed = DateTime.now().difference(_walkAwayStartTime!);
      final progress = (elapsed.inMilliseconds / _walkAwayDuration.inMilliseconds).clamp(0.0, 1.0);

      if (mounted) {
        setState(() {
          _walkAwayProgress = progress;
        });
      }

      // Stop timer when animation completes (character is off-screen)
      if (progress >= 1.0) {
        timer.cancel();
        // Ensure progress is exactly 1.0 to prevent stuck state
        if (mounted) {
          setState(() {
            _walkAwayProgress = 1.0;
          });
          
          // If looping is enabled, restart the animation after a brief delay
          if (_loopAnimation) {
            Timer(const Duration(milliseconds: 500), () {
              if (mounted) {
                _restartAnimation();
              }
            });
          }
        }
      }
    });
  }

  // --- LOGIC: RESTART ---
  void _restartAnimation() {
    if (!mounted) return;
    
    // Pick new person type for next appearance
    _calculatePersonIndex();
    
    // Go back to waiting state
    _startWaiting();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentState == _AnimationState.waiting || _isLoading || 
        _walkFrameImageInfos == null || _backFrameImageInfos == null || 
        _spriteSize == null || _personIndex == null) {
      return const SizedBox.shrink();
    }

    // Grid calculations
    final row = _personIndex! ~/ 5;
    final col = _personIndex! % 5;
    final srcRect = Rect.fromLTWH(
      col * _spriteSize!.width, 
      row * _spriteSize!.height, 
      _spriteSize!.width, 
      _spriteSize!.height
    );

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          ImageInfo imageInfo;
          double horizontalOffset = 0.0;
          bool flipHorizontal = true; 

          switch (_currentState) {
            case _AnimationState.waiting:
               return const SizedBox.shrink();

            case _AnimationState.walkingToMachine:
              // 1. Walking IN: From right to machine position (left side)
              final frameIndex = ((_controller.value * 10) % 10).floor();
              imageInfo = _walkFrameImageInfos![frameIndex];
              
              // Start from right side of dialog (90% from left = right side)
              final startPos = widget.dialogWidth * 0.9;
              // End at machine position on LEFT side
              final endPos = _vendingMachinePosition;
              
              // Interpolate: progress 0 = startPos (right), progress 1 = endPos (left)
              // Formula: startPos + (endPos - startPos) * progress
              // When progress=0: startPos (right side)
              // When progress=1: endPos (left side, machine position)
              horizontalOffset = startPos + (endPos - startPos) * _walkProgress.clamp(0.0, 1.0);
              flipHorizontal = true; 
              break;

            case _AnimationState.backAnimation:
              // 2. Interaction
              final frameIndex = (_controller.value * 4).floor().clamp(0, 3);
              imageInfo = _backFrameImageInfos![frameIndex];
              // Facing right, no flip correction needed
              horizontalOffset = _vendingMachinePosition;
              flipHorizontal = false; 
              break;

            case _AnimationState.pausing:
              // 3. Pausing
              imageInfo = _backFrameImageInfos![3]; 
              // Facing right, no flip correction needed (same as backAnimation)
              horizontalOffset = _vendingMachinePosition;
              flipHorizontal = false; 
              break;

            case _AnimationState.walkingAway:
              // 4. Walking OUT: From machine position (left side) to off-screen left
              final frameIndex = ((_controller.value * 10) % 10).floor();
              imageInfo = _walkFrameImageInfos![frameIndex];
              
              // Start from machine position (same as backAnimation/pausing)
              final startPos = _vendingMachinePosition;
              // End off-screen to the left (move further left to ensure fully exits dialogue)
              // Character is 128px wide, so need to move at least that much past left edge
              final endPos = -widget.dialogWidth * 0.8; // 50% past left edge to fully exit
              
              // Interpolate: as progress goes from 0 to 1, move from startPos to endPos
              // Clamp progress to ensure smooth movement even if timer continues
              final clampedProgress = _walkAwayProgress.clamp(0.0, 1.0);
              horizontalOffset = startPos + (endPos - startPos) * clampedProgress;
              flipHorizontal = true; 
              break;
          }

          // --- RENDER SPRITE ---
          // Calculate actual rendered size after scaling
          final scaledWidth = _spriteSize!.width * _spriteScaleX;
          final scaledHeight = _spriteSize!.height;
          
          final imageWidget = Transform.scale(
            scaleX: _spriteScaleX, 
            scaleY: 1.0, 
            alignment: Alignment.center,
            child: CustomPaint(
              size: _spriteSize!,
              painter: _PersonMachineSpritePainter(
                imageInfo: imageInfo,
                srcRect: srcRect,
              ),
            ),
          );

          // Calculate final visual position
          // When facing right (backAnimation/pausing): no correction needed
          // When facing left (walkingToMachine/walkingAway): apply flip correction if needed
          final baseVisualOffset = horizontalOffset + (flipHorizontal ? _flipCorrection : 0.0);
          
          // Calculate column-based horizontal adjustment
          // Each column (0-4) may need different horizontal positioning within the sprite cell
          final col = _personIndex! % 5;
          final columnOffset = widget.dialogWidth * _columnHorizontalOffsets[col];
          final visualOffset = baseVisualOffset + columnOffset;
          
          // Calculate vertical offset for 2nd row characters (indices 5-9)
          // Row 0 = indices 0-4, Row 1 = indices 5-9
          final row = _personIndex! ~/ 5;
          final verticalOffset = row == 1 ? _secondRowVerticalOffset : 0.0;
          
          // Debug output for position tracking
          if (_currentState == _AnimationState.backAnimation || _currentState == _AnimationState.pausing) {
            final percentFromLeft = (visualOffset / widget.dialogWidth * 100).toStringAsFixed(1);
            final characterCenter = visualOffset + scaledWidth / 2;
            final characterRight = visualOffset + scaledWidth;
            debugPrint('=== CHARACTER POSITION DEBUG ===');
            debugPrint('Machine target: ${_vendingMachinePosition.toStringAsFixed(1)}px (${(_vendingMachinePositionFactor * 100).toStringAsFixed(1)}% from left)');
            debugPrint('Character LEFT edge: ${visualOffset.toStringAsFixed(1)}px ($percentFromLeft% from left)');
            debugPrint('Character CENTER: ${characterCenter.toStringAsFixed(1)}px (${(characterCenter / widget.dialogWidth * 100).toStringAsFixed(1)}% from left)');
            debugPrint('Character RIGHT edge: ${characterRight.toStringAsFixed(1)}px (${(characterRight / widget.dialogWidth * 100).toStringAsFixed(1)}% from left)');
            debugPrint('Character size: ${scaledWidth.toStringAsFixed(1)}x${scaledHeight.toStringAsFixed(1)}px');
            debugPrint('Dialog width: ${widget.dialogWidth.toStringAsFixed(1)}px');
          }

          Widget characterWidget = Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..scale(flipHorizontal ? -1.0 : 1.0, 1.0),
            child: imageWidget,
          );
          
          // Add debug bounding box if enabled - overlay on top of sprite
          if (_showDebugBox) {
            characterWidget = Stack(
              clipBehavior: Clip.none,
              children: [
                characterWidget,
                // Debug bounding box - align with sprite (sprite is centered, so offset by half size)
                Positioned(
                  left: (_spriteSize!.width - scaledWidth) / 2, // Account for scaling offset
                  top: 0, // Align with top of sprite
                  child: Container(
                    width: scaledWidth,
                    height: scaledHeight,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.red,
                        width: 2.0,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Size label
                        Positioned(
                          top: 2,
                          left: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            color: Colors.red.withOpacity(0.8),
                            child: Text(
                              '${scaledWidth.toStringAsFixed(0)}x${scaledHeight.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        // Position label
                        Positioned(
                          bottom: 2,
                          left: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            color: Colors.blue.withOpacity(0.8),
                            child: Text(
                              'X: ${visualOffset.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return Transform.translate(
            offset: Offset(visualOffset, verticalOffset),
            child: characterWidget,
          );
        },
      ),
    );
  }
}

class _PersonMachineSpritePainter extends CustomPainter {
  final ImageInfo imageInfo;
  final Rect srcRect;

  _PersonMachineSpritePainter({required this.imageInfo, required this.srcRect});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      imageInfo.image,
      srcRect,
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint(),
    );
  }

  @override
  bool shouldRepaint(_PersonMachineSpritePainter oldDelegate) {
    return oldDelegate.imageInfo != imageInfo || oldDelegate.srcRect != srcRect;
  }
}