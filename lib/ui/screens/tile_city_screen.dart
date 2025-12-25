import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/providers.dart';
import '../../state/city_map_state.dart';
import '../../simulation/models/zone.dart';
import '../../simulation/models/truck.dart' as sim;
import '../../simulation/models/machine.dart' as sim;
import '../theme/zone_ui.dart';
import '../utils/screen_utils.dart';
import 'route_planner_screen.dart';

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
  static const int gridSize = 10;
  
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
  
  static const double tileSpacingFactor = 0.80;
  static const double horizontalSpacingFactor = 0.70;
  
  static const double buildingScale = 0.81;
  
  static const double gasStationScale = 0.72;
  static const double parkScale = 0.72;
  static const double houseScale = 0.72;
  static const double warehouseScale = 0.72;
  
  double _getWarehouseVerticalOffset(BuildContext context) {
    return ScreenUtils.relativeSize(context, 0.007);
  }
  
  static const int minBlockSize = 2;
  static const int maxBlockSize = 3;
  
  late List<List<TileType>> _grid;
  late List<List<RoadDirection?>> _roadDirections;
  late List<List<BuildingOrientation?>> _buildingOrientations;
  
  int? _warehouseX;
  int? _warehouseY;
  
  late TransformationController _transformationController;
  
  // Track last tap time to prevent duplicate calls
  DateTime? _lastTapTime;
  String? _lastTappedButton;
  
  // Track pointer down positions for buttons to detect taps vs drags
  final Map<String, Offset> _buttonPointerDownPositions = {};

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
    const double sidePadding = 100.0;
    const double topPadding = 150.0;
    const double bottomPadding = 30.0; // Minimal internal padding
    
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
        const double targetBottomGap = 20.0; 
        // Logic: containerHeight - targetBottomGap = New Visual Bottom Position
        // Visual Bottom Position = (maxY + dy)
        // dy = containerHeight - targetBottomGap - maxY
        final offsetY = containerHeight - targetBottomGap - maxY;
        
        final centerOffset = Offset(offsetX, offsetY);

        // Calculate initial scale to zoom in (1.5x zoom for better visibility)
        final initialScale = 1.5;
        
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
        
        // Build tiles and buttons
        final tilesAndButtons = _buildTiles(context, centerOffset, tileWidth, tileHeight, buildingImageHeight);
        final tiles = tilesAndButtons['tiles'] as List<Widget>;
        final buttons = tilesAndButtons['buttons'] as List<Widget>;
        
        return Stack(
          children: [
            InteractiveViewer(
              transformationController: _transformationController,
              boundaryMargin: const EdgeInsets.all(200),
              minScale: 0.3,
              maxScale: 3.0,
              constrained: true, // Constraints ensure child fills viewport if smaller
              child: SizedBox(
                width: containerWidth,
                height: containerHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ...tiles,
                    // Buttons added last inside InteractiveViewer so they transform with the map
                    // but are on top of everything
                    ...buttons,
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Map<String, List<Widget>> _buildTiles(BuildContext context, Offset centerOffset, double tileWidth, double tileHeight, double buildingImageHeight) {
    final tileData = <Map<String, dynamic>>[];

    final warehouseVerticalOffset = _getWarehouseVerticalOffset(context);
    
    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        final tileType = _grid[y][x];
        final roadDir = _roadDirections[y][x];
        final buildingOrientation = _buildingOrientations[y][x];
        final screenPos = _gridToScreen(context, x, y);
        final positionedX = screenPos.dx + centerOffset.dx;
        final positionedY = screenPos.dy + centerOffset.dy;

        tileData.add({
          'x': x,
          'y': y,
          'tileType': tileType,
          'roadDir': roadDir,
          'buildingOrientation': buildingOrientation,
          'positionedX': positionedX,
          'positionedY': positionedY,
        });
      }
    }

    tileData.sort((a, b) {
      final depthA = (a['x'] as int) + (a['y'] as int);
      final depthB = (b['x'] as int) + (b['y'] as int);
      if (depthA != depthB) return depthA.compareTo(depthB);
      final yA = a['y'] as int;
      final yB = b['y'] as int;
      if (yA != yB) return yA.compareTo(yB);
      return (a['x'] as int).compareTo(b['x'] as int);
    });

    final tiles = <Widget>[];
    final buttons = <Widget>[]; // Collect buttons separately to add them last (on top)
    
    for (final data in tileData) {
      final tileType = data['tileType'] as TileType;
      final roadDir = data['roadDir'] as RoadDirection?;
      final buildingOrientation = data['buildingOrientation'] as BuildingOrientation?;
      final positionedX = data['positionedX'] as double;
      final positionedY = data['positionedY'] as double;

        if (tileType == TileType.warehouse) {
          final warehouseScaleFactor = warehouseScale;
          final scaledHeight = buildingImageHeight * warehouseScaleFactor;
          final scaledWidth = tileWidth * warehouseScaleFactor;
          final centerOffsetX = (tileWidth - scaledWidth) / 2;
          final top = positionedY - (scaledHeight - tileHeight) - warehouseVerticalOffset;
          
          tiles.add(
            Positioned(
              left: positionedX + centerOffsetX,
              top: top,
              width: scaledWidth,
              height: scaledHeight,
              child: _buildGroundTile(tileType, roadDir),
            ),
          );
        
        } else if (!_isBuilding(tileType)) {
          tiles.add(
            Positioned(
              left: positionedX,
              top: positionedY,
              width: tileWidth,
              height: tileHeight,
              child: _buildGroundTile(tileType, roadDir),
            ),
          );
        } else {
          tiles.add(
            Positioned(
              left: positionedX,
              top: positionedY,
              width: tileWidth,
              height: tileHeight,
              child: _buildGroundTile(TileType.grass, null),
            ),
          );
        }

      if (_isBuilding(tileType) && tileType != TileType.warehouse) {
        final buildingScaleFactor = _getBuildingScale(tileType);
        final scaledBuildingHeight = buildingImageHeight * buildingScaleFactor;
        final buildingTop = positionedY - (scaledBuildingHeight - tileHeight);
        final scaledWidth = tileWidth * buildingScaleFactor;
        final centerOffsetX = (tileWidth - scaledWidth) / 2;
        
        final verticalOffset = tileType == TileType.warehouse ? warehouseVerticalOffset : 0.0;
        
        // Determine if building is interactive or decorative
        final isInteractive = tileType == TileType.shop || 
                             tileType == TileType.gym || 
                             tileType == TileType.office || 
                             tileType == TileType.school;
        
        Widget buildingWidget = _buildBuildingTile(tileType, buildingOrientation);
        
        // Wrap decorative buildings in IgnorePointer so clicks pass through
        // Wrap interactive buildings in GestureDetector for tap detection
        if (isInteractive) {
          buildingWidget = GestureDetector(
            onTap: () {
              _handleBuildingTap(data['x'] as int, data['y'] as int, tileType);
            },
            behavior: HitTestBehavior.opaque,
            child: buildingWidget,
          );
        } else {
          buildingWidget = IgnorePointer(child: buildingWidget);
        }
        
        tiles.add(
          Positioned(
            left: positionedX + centerOffsetX,
            top: buildingTop - verticalOffset,
            width: scaledWidth,
            height: scaledBuildingHeight,
            child: buildingWidget,
          ),
        );

        if (_shouldShowPurchaseButton(data['x'] as int, data['y'] as int, tileType)) {
          final buttonSize = ScreenUtils.relativeSizeClamped(
            context,
            0.05, // Relative to screen width
            min: ScreenUtils.getSmallerDimension(context) * 0.04,
            max: ScreenUtils.getSmallerDimension(context) * 0.08,
          );
          final buttonTop = buildingTop - verticalOffset - buttonSize + ScreenUtils.relativeSize(context, 0.015);
          final buttonLeft = positionedX + (tileWidth / 2) - (buttonSize / 2);
          
          // Add button to buttons list (will be added last to ensure they're on top)
          // Use GestureDetector with opaque behavior to ensure button captures all taps
          final buttonReason = _getButtonDisabledReason(data['x'] as int, data['y'] as int, tileType);
          final isButtonEnabled = buttonReason == null;
          
          buttons.add(
            Positioned(
              left: buttonLeft,
              top: buttonTop,
              width: buttonSize,
              height: buttonSize,
              child: IgnorePointer(
                ignoring: false,
                child: Listener(
                onPointerDown: (event) {
                  final buttonKey = 'button_${data['x']}_${data['y']}';
                  _buttonPointerDownPositions[buttonKey] = event.position;
                },
                onPointerUp: (event) {
                  final buttonKey = 'button_${data['x']}_${data['y']}';
                  final downPosition = _buttonPointerDownPositions[buttonKey];
                  
                  if (downPosition != null) {
                    final distance = (event.position - downPosition).distance;
                    _buttonPointerDownPositions.remove(buttonKey);
                    
                    // Only treat as tap if movement was small (< 10 pixels)
                    if (distance < 10.0) {
                      if (!isButtonEnabled) {
                        // Show why button is disabled
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(buttonReason ?? 'Cannot purchase'),
                              duration: const Duration(seconds: 3),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                        return;
                      }
                      
                      final now = DateTime.now();
                      // Prevent duplicate calls within 300ms for the same button
                      if (_lastTappedButton != buttonKey || 
                          _lastTapTime == null || 
                          now.difference(_lastTapTime!) > const Duration(milliseconds: 300)) {
                        _lastTapTime = now;
                        _lastTappedButton = buttonKey;
                        _handleBuildingTap(data['x'] as int, data['y'] as int, tileType);
                      }
                    }
                  }
                },
                onPointerCancel: (event) {
                  final buttonKey = 'button_${data['x']}_${data['y']}';
                  _buttonPointerDownPositions.remove(buttonKey);
                },
                behavior: HitTestBehavior.opaque,
                child: GestureDetector(
                  onLongPress: () {
                    // Long press shows debug info
                    if (context.mounted) {
                      final debugInfo = _getButtonDebugInfo(data['x'] as int, data['y'] as int, tileType);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(debugInfo),
                          duration: const Duration(seconds: 5),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        if (!isButtonEnabled) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(buttonReason ?? 'Cannot purchase'),
                                duration: const Duration(seconds: 3),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                          return;
                        }
                        
                        final buttonKey = 'button_${data['x']}_${data['y']}';
                        final now = DateTime.now();
                        
                        if (_lastTappedButton != buttonKey || 
                            _lastTapTime == null || 
                            now.difference(_lastTapTime!) > const Duration(milliseconds: 300)) {
                          _lastTapTime = now;
                          _lastTappedButton = buttonKey;
                          _handleBuildingTap(data['x'] as int, data['y'] as int, tileType);
                        }
                      },
                      customBorder: const CircleBorder(),
                      splashColor: Colors.green.shade300,
                      highlightColor: Colors.green.shade200,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isButtonEnabled ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: ScreenUtils.relativeSize(context, 0.004),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: ScreenUtils.relativeSize(context, 0.008),
                              offset: Offset(0, ScreenUtils.relativeSize(context, 0.004)),
                            ),
                          ],
                        ),
                        child: Icon(
                          isButtonEnabled ? Icons.add : Icons.info_outline,
                          color: Colors.white,
                          size: buttonSize * 0.75, // 75% of button size
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              ),
            ),
          );
        }
      }
    }

    // Add machines and trucks to tiles list
    final gameMachines = ref.watch(machinesProvider);
    for (final machine in gameMachines) {
      tiles.add(_buildGameMachine(context, machine, centerOffset, tileWidth, tileHeight));
    }

    final gameTrucks = ref.watch(trucksProvider);
    for (final truck in gameTrucks) {
      tiles.add(_buildGameTruck(context, truck, centerOffset, tileWidth, tileHeight));
    }

    // Return tiles and buttons separately
    // Buttons will be added last in the Stack to ensure they're on top
    return {
      'tiles': tiles,
      'buttons': buttons,
    };
  }

  Widget _buildGameMachine(BuildContext context, sim.Machine machine, Offset centerOffset, double tileWidth, double tileHeight) {
    final gridPos = _zoneToGrid(machine.zone.x, machine.zone.y);
    final pos = _gridToScreenDouble(context, gridPos.dx, gridPos.dy);
    final positionedX = pos.dx + centerOffset.dx;
    final positionedY = pos.dy + centerOffset.dy;
    
    final double machineSize = tileWidth * 0.3;
    final left = positionedX + (tileWidth - machineSize) / 2;
    final top = positionedY + (tileHeight / 2) - machineSize;

    Color machineColor;
    switch (machine.zone.type) {
      case ZoneType.shop: machineColor = Colors.blue; break;
      case ZoneType.school: machineColor = Colors.purple; break;
      case ZoneType.gym: machineColor = Colors.red; break;
      case ZoneType.office: machineColor = Colors.orange; break;
    }

    final machineId = machine.id;

    return Positioned(
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
            border: Border.all(color: Colors.white, width: 2),
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
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => _MachineViewDialog(
        machineId: machineId,
        imagePath: imagePath,
      ),
    );
  }

  Offset _zoneToGrid(double zoneX, double zoneY) {
    // Clamp to valid grid coordinates (0-9)
    final gridX = (zoneX - 1.0).clamp(0.0, (gridSize - 1).toDouble());
    final gridY = (zoneY - 1.0).clamp(0.0, (gridSize - 1).toDouble());
    return Offset(gridX, gridY);
  }
  
  Widget _buildGameTruck(BuildContext context, sim.Truck truck, Offset centerOffset, double tileWidth, double tileHeight) {
    // Use exact truck coordinates for smooth movement (don't clamp - it causes jumps)
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
                0.032, // Relative to screen width
                min: ScreenUtils.getSmallerDimension(context) * 0.025,
                max: ScreenUtils.getSmallerDimension(context) * 0.045,
              ),
              color: Colors.white,
            ),
          ),
        );
      },
    );

    Widget truckWidget = img;
    if (flip) {
      truckWidget = Transform(
        alignment: Alignment.center, 
        transform: Matrix4.identity()..scale(-1.0, 1.0), 
        child: img
      );
    }
    
    // Wrap truck widget in Listener for tap detection
    truckWidget = Listener(
      onPointerDown: (event) {
        final key = 'truck_${truck.id}';
        _buttonPointerDownPositions[key] = event.position;
      },
      onPointerUp: (event) {
        final key = 'truck_${truck.id}';
        final downPosition = _buttonPointerDownPositions[key];
        if (downPosition != null) {
          final distance = (event.position - downPosition).distance;
          _buttonPointerDownPositions.remove(key);
          if (distance < 10.0) {
            _handleTruckTap(truck);
          }
        }
      },
      behavior: HitTestBehavior.translucent,
      child: truckWidget,
    );
    
    return Positioned(
      left: left,
      top: top,
      width: truckSize,
      height: truckSize,
      child: truckWidget,
    );
  }

  void _handleTruckTap(sim.Truck truck) {
    try {
      // Update selected truck state
      ref.read(selectedTruckIdProvider).selectTruck(truck.id);
      
      // Show snackbar
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Truck ${truck.name} selected! Check Fleet tab.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error handling truck tap: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
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

      if (!_canPurchaseMachine(zoneType)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_getProgressionMessage(zoneType)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Check if player has enough cash
      final gameState = ref.read(gameControllerProvider);
      final price = _getMachinePrice(zoneType);
      if (gameState.cash < price) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Insufficient funds! Need \$${price.toStringAsFixed(2)}, have \$${gameState.cash.toStringAsFixed(2)}'),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Read machines to check if one already exists at this location
      final machines = ref.read(machinesProvider);
      final hasExistingMachine = machines.any(
        (m) => (m.zone.x - zoneX).abs() < 0.1 && (m.zone.y - zoneY).abs() < 0.1,
      );
      
      if (hasExistingMachine) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('A machine already exists at this location'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      controller.buyMachineWithStock(zoneType, x: zoneX, y: zoneY);
    } catch (e) {
      // Handle any errors gracefully
      print('Error handling building tap: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: const Duration(seconds: 2),
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

    // Always show button if it's an interactive building type
    // The button will be disabled/enabled based on conditions
    return true;
  }
  
  /// Get reason why button is disabled, or null if enabled
  String? _getButtonDisabledReason(int gridX, int gridY, TileType tileType) {
    final zoneX = (gridX + 1).toDouble() + 0.5;
    final zoneY = (gridY + 1).toDouble() + 0.5;

    final zoneType = _tileTypeToZoneType(tileType);
    if (zoneType == null) return 'Not a valid building type';

    // Check progression requirements
    if (!_canPurchaseMachine(zoneType)) {
      return _getProgressionMessage(zoneType);
    }

    // Check if machine already exists
    final machines = ref.watch(machinesProvider);
    final hasExistingMachine = machines.any(
      (m) => (m.zone.x - zoneX).abs() < 0.1 && (m.zone.y - zoneY).abs() < 0.1,
    );
    
    if (hasExistingMachine) {
      return 'Machine already exists here';
    }

    // Check funds
    final gameState = ref.read(gameControllerProvider);
    final price = _getMachinePrice(zoneType);
    if (gameState.cash < price) {
      return 'Need \$${price.toStringAsFixed(2)}, have \$${gameState.cash.toStringAsFixed(2)}';
    }

    return null; // Button is enabled
  }
  
  /// Get debug info for button (long press)
  String _getButtonDebugInfo(int gridX, int gridY, TileType tileType) {
    final zoneX = (gridX + 1).toDouble() + 0.5;
    final zoneY = (gridY + 1).toDouble() + 0.5;
    final zoneType = _tileTypeToZoneType(tileType);
    final gameState = ref.read(gameControllerProvider);
    final machines = ref.watch(machinesProvider);
    final hasExistingMachine = machines.any(
      (m) => (m.zone.x - zoneX).abs() < 0.1 && (m.zone.y - zoneY).abs() < 0.1,
    );
    
    final reason = _getButtonDisabledReason(gridX, gridY, tileType);
    final price = zoneType != null ? _getMachinePrice(zoneType) : 0.0;
    
    return 'Grid: ($gridX, $gridY) | Zone: ($zoneX, $zoneY) | '
           'Type: ${zoneType?.name ?? "N/A"} | '
           'Price: \$${price.toStringAsFixed(2)} | '
           'Cash: \$${gameState.cash.toStringAsFixed(2)} | '
           'Has Machine: $hasExistingMachine | '
           'Status: ${reason ?? "ENABLED"}';
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

  double _getMachinePrice(ZoneType zoneType) {
    const basePrice = 400.0;
    const zoneMultipliers = {
      ZoneType.office: 1.75,
      ZoneType.school: 1.5,
      ZoneType.gym: 1.25,
      ZoneType.shop: 1.0,
    };
    return basePrice * (zoneMultipliers[zoneType] ?? 1.0);
  }

  bool _canPurchaseMachine(ZoneType zoneType) {
    final machines = ref.read(machinesProvider);
    final shopMachines = machines.where((m) => m.zone.type == ZoneType.shop).length;
    final schoolMachines = machines.where((m) => m.zone.type == ZoneType.school).length;
    final gymMachines = machines.where((m) => m.zone.type == ZoneType.gym).length;
    final officeMachines = machines.where((m) => m.zone.type == ZoneType.office).length;

    switch (zoneType) {
      case ZoneType.shop: return shopMachines < 2;
      case ZoneType.school: return shopMachines >= 2 && schoolMachines < 2;
      case ZoneType.gym: return schoolMachines >= 2 && gymMachines < 2;
      case ZoneType.office: return gymMachines >= 2 && officeMachines < 2;
    }
  }

  String _getProgressionMessage(ZoneType zoneType) {
    final machines = ref.read(machinesProvider);
    final shopMachines = machines.where((m) => m.zone.type == ZoneType.shop).length;
    final schoolMachines = machines.where((m) => m.zone.type == ZoneType.school).length;
    final gymMachines = machines.where((m) => m.zone.type == ZoneType.gym).length;
    final officeMachines = machines.where((m) => m.zone.type == ZoneType.office).length;
    
    switch (zoneType) {
      case ZoneType.shop:
        if (shopMachines >= 2) return 'Shop limit reached (have $shopMachines/2). Buy 2 school machines next.';
        return 'Can purchase shop machines ($shopMachines/2)';
      case ZoneType.school:
        if (shopMachines < 2) return 'Need 2 shop machines first (have $shopMachines/2)';
        if (schoolMachines >= 2) return 'School limit reached (have $schoolMachines/2). Buy 2 gym machines next.';
        return 'Can purchase school machines ($schoolMachines/2)';
      case ZoneType.gym:
        if (schoolMachines < 2) return 'Need 2 school machines first (have $schoolMachines/2)';
        if (gymMachines >= 2) return 'Gym limit reached (have $gymMachines/2). Buy office machines next.';
        return 'Can purchase gym machines ($gymMachines/2)';
      case ZoneType.office:
        if (gymMachines < 2) return 'Need 2 gym machines first (have $gymMachines/2)';
        if (officeMachines >= 2) return 'Office limit reached (have $officeMachines/2). Maximum machines reached.';
        return 'Can purchase office machines ($officeMachines/2)';
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
            style: const TextStyle(fontSize: 8),
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
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Text(
              _getTileLabel(tileType),
              style: const TextStyle(fontSize: 10),
            ),
          ),
        );
      },
    );

    if (orientation == BuildingOrientation.flippedHorizontal) {
      return Transform(
        alignment: Alignment.bottomCenter,
        transform: Matrix4.identity()..scale(-1.0, 1.0),
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
                    0.045,
                    min: ScreenUtils.getSmallerDimension(context) * 0.035,
                    max: ScreenUtils.getSmallerDimension(context) * 0.065,
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
                    0.032,
                    min: ScreenUtils.getSmallerDimension(context) * 0.025,
                    max: ScreenUtils.getSmallerDimension(context) * 0.045,
                  ),
                ),
              ),
              SizedBox(height: ScreenUtils.relativeSize(context, 0.01)),
              Text(
                'Total machines: ${machines.length}',
                style: TextStyle(
                  fontSize: ScreenUtils.relativeFontSize(
                    context,
                    0.032,
                    min: ScreenUtils.getSmallerDimension(context) * 0.025,
                    max: ScreenUtils.getSmallerDimension(context) * 0.045,
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
                      0.025,
                      min: ScreenUtils.getSmallerDimension(context) * 0.02,
                      max: ScreenUtils.getSmallerDimension(context) * 0.035,
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
                      0.032,
                      min: ScreenUtils.getSmallerDimension(context) * 0.025,
                      max: ScreenUtils.getSmallerDimension(context) * 0.045,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Calculate the actual dialog width (clamped)
    final dialogMaxWidth = ScreenUtils.relativeSizeClamped(
      context,
      0.9, // 90% of screen width
      min: 300,
      max: 600,
    );
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(ScreenUtils.relativeSize(context, 0.04)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Use the actual constrained width for sizing
          final dialogWidth = constraints.maxWidth;
          final imageHeight = (dialogWidth * 0.5).clamp(120.0, 300.0);
          final borderRadius = (dialogWidth * 0.04).clamp(12.0, 24.0);
          final padding = (dialogWidth * 0.04).clamp(12.0, 24.0);
          
          return Container(
            constraints: BoxConstraints(
              maxWidth: dialogMaxWidth,
              maxHeight: ScreenUtils.relativeSizeClamped(
                context,
                0.8, // 80% of screen height
                min: 400,
                max: 800,
              ),
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
                                  fontSize: (dialogWidth * 0.045).clamp(14.0, 28.0),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      top: padding * 0.5,
                      right: padding * 0.5,
                      child: IconButton(
                        icon: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: (dialogWidth * 0.08).clamp(24.0, 48.0),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withOpacity(0.5),
                          padding: EdgeInsets.all(padding * 0.3),
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
    const maxCapacity = 50.0;
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: (dialogWidth * 0.15).clamp(36.0, 90.0),
              height: (dialogWidth * 0.15).clamp(36.0, 90.0),
              decoration: BoxDecoration(
                color: zoneColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                zoneIcon,
                color: zoneColor,
                size: (dialogWidth * 0.08).clamp(24.0, 48.0),
              ),
            ),
            SizedBox(width: (dialogWidth * 0.03).clamp(8.0, 18.0)),
            Expanded(
              child: Text(
                machine.name,
                style: TextStyle(
                  fontSize: (dialogWidth * 0.055).clamp(16.0, 33.0),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: (dialogWidth * 0.03).clamp(8.0, 18.0)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stock: ${machine.totalInventory} items',
              style: TextStyle(
                fontSize: (dialogWidth * 0.04).clamp(12.0, 24.0),
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: (dialogWidth * 0.015).clamp(4.0, 9.0)),
            LinearProgressIndicator(
              value: stockLevel,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(stockColor),
              minHeight: (dialogWidth * 0.02).clamp(6.0, 12.0),
            ),
          ],
        ),
        SizedBox(height: (dialogWidth * 0.03).clamp(8.0, 18.0)),
        Container(
          padding: EdgeInsets.all((dialogWidth * 0.04).clamp(12.0, 24.0)),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(
              (dialogWidth * 0.02).clamp(6.0, 12.0),
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
                      fontSize: (dialogWidth * 0.03).clamp(9.0, 18.0),
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    '\$${machine.currentCash.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: (dialogWidth * 0.06).clamp(18.0, 36.0),
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: (dialogWidth * 0.03).clamp(8.0, 18.0)),
        Divider(height: (dialogWidth * 0.003).clamp(1.0, 2.0)),
        SizedBox(height: (dialogWidth * 0.03).clamp(8.0, 18.0)),
        Text(
          'Stock Details:',
          style: TextStyle(
            fontSize: (dialogWidth * 0.055).clamp(16.0, 33.0),
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: (dialogWidth * 0.02).clamp(6.0, 12.0)),
        if (machine.inventory.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: (dialogWidth * 0.015).clamp(4.0, 8.0),
            ),
            child: Text(
              'Empty',
              style: TextStyle(
                fontSize: (dialogWidth * 0.04).clamp(12.0, 24.0),
                fontStyle: FontStyle.italic,
                color: Colors.grey[600],
              ),
            ),
          )
        else
          ...machine.inventory.values.map((item) => Padding(
            padding: EdgeInsets.only(
              bottom: (dialogWidth * 0.015).clamp(4.0, 8.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.product.name,
                    style: TextStyle(
                      fontSize: (dialogWidth * 0.04).clamp(12.0, 24.0),
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: (dialogWidth * 0.02).clamp(6.0, 12.0),
                    vertical: (dialogWidth * 0.01).clamp(3.0, 6.0),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${item.quantity}',
                    style: TextStyle(
                      fontSize: (dialogWidth * 0.04).clamp(12.0, 20.0),
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
          )),
        SizedBox(height: (dialogWidth * 0.03).clamp(8.0, 18.0)),
        if (machine.currentCash > 0)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                ref.read(gameControllerProvider.notifier).retrieveCash(machine.id);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Retrieved \$${machine.currentCash.toStringAsFixed(2)} from ${machine.name}',
                    ),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: Icon(
                Icons.account_balance_wallet,
                size: (dialogWidth * 0.04).clamp(16.0, 24.0),
              ),
              label: Text(
                'Retrieve \$${machine.currentCash.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: (dialogWidth * 0.04).clamp(14.0, 20.0),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  vertical: (dialogWidth * 0.025).clamp(10.0, 16.0),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    (dialogWidth * 0.015).clamp(6.0, 12.0),
                  ),
                ),
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              vertical: (dialogWidth * 0.025).clamp(10.0, 16.0),
            ),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(
                (dialogWidth * 0.015).clamp(6.0, 12.0),
              ),
            ),
            child: Center(
              child: Text(
                'No cash to retrieve',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: (dialogWidth * 0.04).clamp(12.0, 20.0),
                ),
              ),
            ),
          ),
      ],
    );
  }
}