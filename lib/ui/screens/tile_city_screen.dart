import 'dart:math' as math;
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

class TileCityScreen extends ConsumerStatefulWidget {
  const TileCityScreen({super.key});

  @override
  ConsumerState<TileCityScreen> createState() => _TileCityScreenState();
}

class _TileCityScreenState extends ConsumerState<TileCityScreen> {
  static const int gridSize = 10; // Using AppConfig.cityGridSize value
  
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
  
  static const int minBlockSize = AppConfig.minBlockSize;
  static const int maxBlockSize = AppConfig.maxBlockSize;
  
  late List<List<TileType>> _grid;
  late List<List<RoadDirection?>> _roadDirections;
  late List<List<BuildingOrientation?>> _buildingOrientations;
  
  int? _warehouseX;
  int? _warehouseY;
  
  late TransformationController _transformationController;
  
  // Debounce tracking
  DateTime? _lastTapTime;
  String? _lastTappedButton;
  
  // Draggable message position (null = use default position)
  Offset? _messagePosition;
  Offset? _messageDragStartPosition; // Position when drag started
  Offset _messageDragAccumulatedDelta = Offset.zero; // Accumulated delta during current drag
  bool _previousRushHourState = false; // Track previous rush hour state to detect transitions

  @override
  void initState() {
    super.initState();
    // Initialize with a zoomed-in view (scale 1.5)
    _transformationController = TransformationController();
    
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
    _transformationController.dispose();
    super.dispose();
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
    int currentY = 3;
    while (currentY < gridSize - 2) {
      for (int x = 0; x < gridSize; x++) {
        _grid[currentY][x] = TileType.road;
      }
      currentY += 3;
    }
    
    int currentX = 3;
    while (currentX < gridSize - 2) {
      for (int y = 0; y < gridSize; y++) {
        _grid[y][currentX] = TileType.road;
      }
      currentX += 3;
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
    ];

    final buildingCounts = <TileType, int>{
      TileType.shop: 0, TileType.gym: 0, TileType.office: 0, TileType.school: 0,
      TileType.gasStation: 0, TileType.park: 0, TileType.house: 0,
    };
    
    final maxBuildingCounts = <TileType, int>{
      TileType.shop: 2, TileType.gym: 2, TileType.office: 2, TileType.school: 2,
      TileType.gasStation: 2, TileType.park: 4, TileType.house: 4,
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
    }
  }

  bool _isBuilding(TileType tileType) {
    return tileType == TileType.shop || tileType == TileType.gym ||
        tileType == TileType.office || tileType == TileType.school ||
        tileType == TileType.gasStation || tileType == TileType.park ||
        tileType == TileType.house || tileType == TileType.warehouse;
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
                    // Buttons on top
                    ...components['buttons']!,
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
    final tileData = <Map<String, dynamic>>[];
    final warehouseVerticalOffset = _getWarehouseVerticalOffset(context);
    
    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        final screenPos = _gridToScreen(context, x, y);
        tileData.add({
          'x': x,
          'y': y,
          'tileType': _grid[y][x],
          'roadDir': _roadDirections[y][x],
          'buildingOrientation': _buildingOrientations[y][x],
          'positionedX': screenPos.dx + centerOffset.dx,
          'positionedY': screenPos.dy + centerOffset.dy,
        });
      }
    }

    // Sort for Painter's Algorithm (Back to Front)
    tileData.sort((a, b) {
      final depthA = (a['x'] as int) + (a['y'] as int);
      final depthB = (b['x'] as int) + (b['y'] as int);
      if (depthA != depthB) return depthA.compareTo(depthB);
      return (a['y'] as int).compareTo(b['y'] as int);
    });

    final tiles = <Widget>[];
    final buttons = <Widget>[];
    
    for (final data in tileData) {
      final int x = data['x'];
      final int y = data['y'];
      final TileType tileType = data['tileType'];
      final double posX = data['positionedX'];
      final double posY = data['positionedY'];
      
      // 1. Build Ground/Building Tile
      tiles.add(_buildSingleTileWidget(
        context, x, y, tileType, data['roadDir'], data['buildingOrientation'],
        posX, posY, tileWidth, tileHeight, buildingImageHeight, warehouseVerticalOffset
      ));

      // 2. Build Purchase Button (if applicable)
      if (_isBuilding(tileType) && tileType != TileType.warehouse && _shouldShowPurchaseButton(x, y, tileType)) {
        //final buildingScaleFactor = _getBuildingScale(tileType);
        //final scaledHeight = buildingImageHeight * buildingScaleFactor;
        //final buildingTop = posY - (scaledHeight - tileHeight);
        
        final buttonSize = ScreenUtils.relativeSizeClamped(
          context, 0.05,
          min: ScreenUtils.getSmallerDimension(context) * 0.04,
          max: ScreenUtils.getSmallerDimension(context) * 0.08,
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


    // Add Machines and Trucks
    final gameMachines = ref.watch(machinesProvider);
    for (final machine in gameMachines) {
      tiles.add(_buildGameMachine(context, machine, centerOffset, tileWidth, tileHeight));
    }
    final gameTrucks = ref.watch(trucksProvider);
    for (final truck in gameTrucks) {
      tiles.add(_buildGameTruck(context, truck, centerOffset, tileWidth, tileHeight));
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
          top: posY - (h - tileHeight),
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
    final top = positionedY + (tileHeight / 2) - truckSize;

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
      default: return null;
    }
  }

  bool _canPurchaseMachine(ZoneType zoneType) {
    final machines = ref.read(machinesProvider);
    final shopMachines = machines.where((m) => m.zone.type == ZoneType.shop).length;
    final schoolMachines = machines.where((m) => m.zone.type == ZoneType.school).length;
    final gymMachines = machines.where((m) => m.zone.type == ZoneType.gym).length;
    final officeMachines = machines.where((m) => m.zone.type == ZoneType.office).length;

    switch (zoneType) {
      case ZoneType.shop: return shopMachines < AppConfig.machineLimitPerType;
      case ZoneType.school: return shopMachines >= AppConfig.machineLimitPerType && schoolMachines < AppConfig.machineLimitPerType;
      case ZoneType.gym: return schoolMachines >= AppConfig.machineLimitPerType && gymMachines < AppConfig.machineLimitPerType;
      case ZoneType.office: return gymMachines >= AppConfig.machineLimitPerType && officeMachines < AppConfig.machineLimitPerType;
    }
  }

  String _getProgressionMessage(ZoneType zoneType) {
    final machines = ref.read(machinesProvider);
    final shopMachines = machines.where((m) => m.zone.type == ZoneType.shop).length;
    final schoolMachines = machines.where((m) => m.zone.type == ZoneType.school).length;
    final gymMachines = machines.where((m) => m.zone.type == ZoneType.gym).length;
    final officeMachines = machines.where((m) => m.zone.type == ZoneType.office).length;
    
    final limit = AppConfig.machineLimitPerType;
    switch (zoneType) {
      case ZoneType.shop:
        if (shopMachines >= limit) return 'Shop limit reached (have $shopMachines/$limit). Buy $limit school machines next.';
        return 'Can purchase shop machines ($shopMachines/$limit)';
      case ZoneType.school:
        if (shopMachines < limit) return 'Need $limit shop machines first (have $shopMachines/$limit)';
        if (schoolMachines >= limit) return 'School limit reached (have $schoolMachines/$limit). Buy $limit gym machines next.';
        return 'Can purchase school machines ($schoolMachines/$limit)';
      case ZoneType.gym:
        if (schoolMachines < limit) return 'Need $limit school machines first (have $schoolMachines/$limit)';
        if (gymMachines >= limit) return 'Gym limit reached (have $gymMachines/$limit). Buy office machines next.';
        return 'Can purchase gym machines ($gymMachines/$limit)';
      case ZoneType.office:
        if (gymMachines < limit) return 'Need $limit gym machines first (have $gymMachines/$limit)';
        if (officeMachines >= limit) return 'Office limit reached (have $officeMachines/$limit). Maximum machines reached.';
        return 'Can purchase office machines ($officeMachines/$limit)';
    }
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final machines = ref.watch(machinesProvider);
    
    sim.Machine? machine;
    try {
      machine = machines.firstWhere(
        (m) => m.id == machineId,
      );
    } catch (e) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(ScreenUtils.relativeSize(context, 0.04)),
        child: Container(
          padding: EdgeInsets.all(ScreenUtils.relativeSize(context, 0.04)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              ScreenUtils.relativeSize(context, 0.03),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Machine not found',
                style: TextStyle(
                  fontSize: ScreenUtils.relativeFontSize(
                    context,
                    AppConfig.fontSizeFactorLarge,
                    min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                    max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                  ),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: ScreenUtils.relativeSize(context, 0.01)),
              Text(
                'Looking for ID: $machineId',
                style: TextStyle(
                  fontSize: ScreenUtils.relativeFontSize(
                    context,
                    AppConfig.fontSizeFactorNormal,
                    min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                    max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                  ),
                ),
              ),
              SizedBox(height: ScreenUtils.relativeSize(context, 0.01)),
              Text(
                'Total machines: ${machines.length}',
                style: TextStyle(
                  fontSize: ScreenUtils.relativeFontSize(
                    context,
                    AppConfig.fontSizeFactorNormal,
                    min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                    max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                  ),
                ),
              ),
              if (machines.isNotEmpty) ...[
                SizedBox(height: ScreenUtils.relativeSize(context, 0.01)),
                Text(
                  'Available IDs: ${machines.map((m) => m.id).join(', ')}',
                  style: TextStyle(
                    fontSize: ScreenUtils.relativeFontSize(
                      context,
                      AppConfig.fontSizeFactorSmall,
                      min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                      max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                    ),
                  ),
                ),
              ],
              SizedBox(height: ScreenUtils.relativeSize(context, 0.02)),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Close',
                  style: TextStyle(
                    fontSize: ScreenUtils.relativeFontSize(
                      context,
                      AppConfig.fontSizeFactorNormal,
                      min: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMinMultiplier,
                      max: ScreenUtils.getSmallerDimension(context) * AppConfig.fontSizeMaxMultiplier,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
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
                      child: _MachineStatusSection(
                        machine: machine!,
                        dialogWidth: dialogWidth,
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