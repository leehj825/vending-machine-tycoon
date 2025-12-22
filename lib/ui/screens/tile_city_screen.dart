import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/providers.dart';
import '../../simulation/models/zone.dart';
import '../../simulation/models/truck.dart' as sim;
import '../../simulation/models/machine.dart' as sim;

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
  vertical, // Connects (X, Y-1) and (X, Y+1) in isometric view
  horizontal, // Connects (X-1, Y) and (X+1, Y) in isometric view
  intersection,
}

enum BuildingOrientation {
  normal,
  flippedHorizontal,
}

// Removed local Truck class - using simulation trucks from providers

class TileCityScreen extends ConsumerStatefulWidget {
  const TileCityScreen({super.key});

  @override
  ConsumerState<TileCityScreen> createState() => _TileCityScreenState();
}

class _TileCityScreenState extends ConsumerState<TileCityScreen> {
  static const int gridSize = 10;
  
  // Isometric tile dimensions (tweakable constants)
  // Reduced spacing to make tiles closer together
  static const double tileWidth = 64.0;
  static const double tileHeight = 32.0;
  static const double tileSpacingFactor = 0.80; // Vertical spacing (up/down)
  static const double horizontalSpacingFactor = 0.70; // Horizontal spacing (side to side) - reduced more
  
  // Building image height (assumed taller than ground tiles)
  // Adjusted to make buildings larger
  static const double buildingImageHeight = 65.0; // Increased from 60.0
  static const double buildingScale = 0.81; // Increased from 0.75 to make buildings larger
  
  // Individual building scales (adjustable separately for different image sizes)
  static const double gasStationScale = 0.72; // Adjust for gas_station.png
  static const double parkScale = 0.72; // Adjust for park.png
  static const double houseScale = 0.72; // Adjust for house.png
  static const double warehouseScale = 0.72; // Adjust for warehouse.png
  
  // Vertical offset for warehouse (negative to lower it, positive to raise it)
  static const double warehouseVerticalOffset = 3.0; // Raise warehouse slightly above ground
  
  // Block dimensions - minimum 2x2, maximum 2x3 or 3x2
  static const int minBlockSize = 2;
  static const int maxBlockSize = 3;
  
  late List<List<TileType>> _grid;
  late List<List<RoadDirection?>> _roadDirections;
  late List<List<BuildingOrientation?>> _buildingOrientations;
  
  // Warehouse position (grid coordinates)
  int? _warehouseX;
  int? _warehouseY;

  @override
  void initState() {
    super.initState();
    _generateMap();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _generateMap() {
    // Initialize grid with grass
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

    // Generate grid-based road system
    _generateRoadGrid();

    // Place warehouse (only one, anywhere)
    _placeWarehouse();

    // Place building blocks
    _placeBuildingBlocks();
  }

  /// Generate a grid-based road system that forms rectangular blocks
  /// Roads are spaced to create maximum 2x3 or 3x2 blocks
  /// Roads must be at least 2 tiles apart (minimum 2 grass tiles between roads)
  void _generateRoadGrid() {
    // Create a grid pattern with roads spaced at least 3 tiles apart
    // This ensures at least 2 grass tiles between roads (spacing of 3 means: road, grass, grass, road)
    // Use spacing of 3 or 4 to create blocks of 2x2, 2x3, or 3x2
    int currentY = 3;
    
    // Horizontal roads (running East-West in grid, diagonal in isometric)
    while (currentY < gridSize - 2) {
      for (int x = 0; x < gridSize; x++) {
        _grid[currentY][x] = TileType.road;
      }
      // Space roads at least 3 tiles apart (ensures 2 grass tiles between)
      currentY += 3;
    }
    
    int currentX = 3;
    
    // Vertical roads (running North-South in grid, diagonal in isometric)
    while (currentX < gridSize - 2) {
      for (int y = 0; y < gridSize; y++) {
        _grid[y][currentX] = TileType.road;
      }
      // Space roads at least 3 tiles apart (ensures 2 grass tiles between)
      currentX += 3;
    }
    
    // Update road directions
    _updateRoadDirections();
  }

  /// Place warehouse (only one instance, anywhere in town)
  void _placeWarehouse() {
    final random = math.Random();
    final validSpots = <List<int>>[];
    
    // Find all grass tiles adjacent to roads
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
      
      // Find the nearest road tile and store it in game state
      _updateWarehouseRoadPosition();
    }
  }

  /// Find the nearest road tile to warehouse and update game state
  /// This is called after the build phase to avoid modifying providers during widget lifecycle
  void _updateWarehouseRoadPosition() {
    if (_warehouseX == null || _warehouseY == null) return;
    
    // Find the nearest road tile (check all four directions)
    double? nearestRoadX;
    double? nearestRoadY;
    double minDistance = double.infinity;
    
    // Check all four directions for roads
    final directions = [
      [-1, 0], [1, 0], [0, -1], [0, 1], // Left, Right, Up, Down
    ];
    
    for (final dir in directions) {
      final checkX = (_warehouseX! + dir[0]).toInt();
      final checkY = (_warehouseY! + dir[1]).toInt();
      
      if (checkX >= 0 && checkX < gridSize && 
          checkY >= 0 && checkY < gridSize &&
          _grid[checkY][checkX] == TileType.road) {
        // Found a road - convert grid coordinates to zone coordinates
        // Grid: 0-9, Zone: 1.0-10.0 (roads are at integers)
        final zoneX = (checkX + 1).toDouble();
        final zoneY = (checkY + 1).toDouble();
        
        // Calculate distance (Manhattan for simplicity)
        final distance = (checkX - _warehouseX!).abs().toDouble() + (checkY - _warehouseY!).abs().toDouble();
        
        if (distance < minDistance) {
          minDistance = distance;
          nearestRoadX = zoneX;
          nearestRoadY = zoneY;
        }
      }
    }
    
    // If we found a road, update game state after the build phase
    if (nearestRoadX != null && nearestRoadY != null) {
      // Delay the update until after the build phase is complete
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final controller = ref.read(gameControllerProvider.notifier);
        controller.setWarehouseRoadPosition(nearestRoadX!, nearestRoadY!);
      });
    }
  }

  // Removed local truck movement methods - using real trucks from simulation

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

    final int connections = (hasNorth ? 1 : 0) +
        (hasSouth ? 1 : 0) +
        (hasEast ? 1 : 0) +
        (hasWest ? 1 : 0);

    // At edges, don't use intersection - continue with 2-way road
    if (isAtEdge) {
      // Straight roads at edges
      if (hasNorth && hasSouth) {
        return RoadDirection.vertical;
      }
      if (hasEast && hasWest) {
        return RoadDirection.horizontal;
      }
      // If only one direction, use that direction
      if (hasNorth || hasSouth) {
        return RoadDirection.vertical;
      }
      if (hasEast || hasWest) {
        return RoadDirection.horizontal;
      }
      // Default to horizontal for edge roads
      return RoadDirection.horizontal;
    }

    // Intersection or corner (3+ connections) - only for non-edge tiles
    if (connections >= 3) {
      return RoadDirection.intersection;
    }

    // Straight roads
    if (hasNorth && hasSouth) {
      return RoadDirection.vertical;
    }
    if (hasEast && hasWest) {
      return RoadDirection.horizontal;
    }

    // Default to intersection for corners and dead ends (non-edge only)
    return RoadDirection.intersection;
  }

  /// Place building blocks (2x3 or 3x2 tiles) in areas between roads
  /// Maximum 2 of each building type globally
  /// Within each block, no duplicate building types (can mix with grass)
  /// Buildings face toward the nearest road
  void _placeBuildingBlocks() {
    final random = math.Random();
    final buildingTypes = [
      TileType.shop,
      TileType.gym,
      TileType.office,
      TileType.school,
      TileType.gasStation,
      TileType.park,
      TileType.house,
    ];

    // Track building type counts globally
    // Houses and parks can have more instances (up to 5 each)
    final buildingCounts = <TileType, int>{
      TileType.shop: 0,
      TileType.gym: 0,
      TileType.office: 0,
      TileType.school: 0,
      TileType.gasStation: 0,
      TileType.park: 0,
      TileType.house: 0,
    };
    
    // Maximum counts for each building type
    final maxBuildingCounts = <TileType, int>{
      TileType.shop: 2,
      TileType.gym: 2,
      TileType.office: 2,
      TileType.school: 2,
      TileType.gasStation: 2,
      TileType.park: 4, // More parks
      TileType.house: 4, // More houses
    };

    // Find all rectangular areas that can fit building blocks (2x3 or 3x2)
    final validBlocks = <Map<String, dynamic>>[];
    
    for (int startY = 0; startY < gridSize; startY++) {
      for (int startX = 0; startX < gridSize; startX++) {
        // Try different block sizes: 2x3, 3x2, 2x2, 3x3
        for (int blockWidth = minBlockSize; blockWidth <= maxBlockSize; blockWidth++) {
          for (int blockHeight = minBlockSize; blockHeight <= maxBlockSize; blockHeight++) {
            // Only allow 2x3 or 3x2 (not 3x3)
            if (blockWidth == 3 && blockHeight == 3) continue;
            if (_canPlaceBlock(startX, startY, blockWidth, blockHeight)) {
              validBlocks.add({
                'x': startX,
                'y': startY,
                'width': blockWidth,
                'height': blockHeight,
              });
            }
          }
        }
      }
    }

    // Sort blocks to prioritize empty blocks (blocks with no buildings)
    // This spreads buildings across the map instead of clustering them
    validBlocks.sort((a, b) {
      // Check if blocks have buildings - prioritize empty blocks
      final aHasBuildings = _blockHasBuildings(a['x'] as int, a['y'] as int, a['width'] as int, a['height'] as int);
      final bHasBuildings = _blockHasBuildings(b['x'] as int, b['y'] as int, b['width'] as int, b['height'] as int);
      if (aHasBuildings != bHasBuildings) {
        return aHasBuildings ? 1 : -1; // Empty blocks first
      }
      return 0; // Keep original order if both are same
    });
    
    // Shuffle blocks with same priority to add some randomness
    final emptyBlocks = validBlocks.where((b) => !_blockHasBuildings(b['x'] as int, b['y'] as int, b['width'] as int, b['height'] as int)).toList();
    final blocksWithBuildings = validBlocks.where((b) => _blockHasBuildings(b['x'] as int, b['y'] as int, b['width'] as int, b['height'] as int)).toList();
    emptyBlocks.shuffle(random);
    blocksWithBuildings.shuffle(random);
    final sortedBlocks = [...emptyBlocks, ...blocksWithBuildings];
    
    final placedTiles = <String>{}; // Track placed tiles as "x,y" strings to avoid overlaps
    
    for (final block in sortedBlocks) {
      final startX = block['x'] as int;
      final startY = block['y'] as int;
      final blockWidth = block['width'] as int;
      final blockHeight = block['height'] as int;
      
      // Check if this block overlaps with already placed buildings
      bool overlaps = false;
      for (int by = startY; by < startY + blockHeight && !overlaps; by++) {
        for (int bx = startX; bx < startX + blockWidth && !overlaps; bx++) {
          if (placedTiles.contains('$bx,$by')) {
            overlaps = true;
          }
        }
      }
      
      if (overlaps) continue;
      
      // Track building types used in this block (to avoid duplicates within block)
      final blockBuildingTypes = <TileType>{};
      
      // Place buildings in this block - mix with grass, no duplicates in block
      final blockTiles = <List<int>>[];
      for (int by = startY; by < startY + blockHeight && by < gridSize; by++) {
        for (int bx = startX; bx < startX + blockWidth && bx < gridSize; bx++) {
          blockTiles.add([bx, by]);
        }
      }
      
      // Sort tiles: prefer tiles that are NOT adjacent to other buildings
      // This spreads buildings within blocks
      blockTiles.sort((a, b) {
        final aAdjacent = _isTileAdjacentToBuilding(a[0], a[1], placedTiles);
        final bAdjacent = _isTileAdjacentToBuilding(b[0], b[1], placedTiles);
        if (aAdjacent != bAdjacent) {
          return aAdjacent ? 1 : -1; // Non-adjacent tiles first
        }
        return 0;
      });
      
      // Limit buildings per block to spread them out (max 1-2 per block)
      final maxBuildingsPerBlock = 2;
      final numBuildings = math.min(math.min(blockTiles.length, maxBuildingsPerBlock), buildingTypes.length);
      
      // First, prioritize placing gas_station, park, and house if they haven't been placed yet
      final priorityTypes = [
        TileType.gasStation,
        TileType.park,
        TileType.house,
        TileType.shop,
        TileType.gym,
        TileType.office,
        TileType.school,
      ];
      
      for (int i = 0; i < numBuildings && i < blockTiles.length; i++) {
        final tile = blockTiles[i];
        final bx = tile[0];
        final by = tile[1];
        
        // Only place buildings on tiles that are directly adjacent to a road
        if (!_isTileAdjacentToRoad(bx, by)) {
          continue; // Skip this tile if not adjacent to road
        }
        
        // Get available building types (not used in this block, and under global limit)
        // Prioritize types that haven't been placed yet
        final availableTypes = buildingTypes.where((type) => 
          !blockBuildingTypes.contains(type) && buildingCounts[type]! < maxBuildingCounts[type]!
        ).toList();
        
        if (availableTypes.isEmpty) break; // No more types available
        
        // Prefer houses and parks first (they can have more instances)
        final housesAndParks = availableTypes.where((type) => 
          (type == TileType.house || type == TileType.park) && buildingCounts[type]! < maxBuildingCounts[type]!
        ).toList();
        
        // Use houses and parks if available, otherwise use other priority types
        final priorityAvailable = housesAndParks.isNotEmpty 
            ? housesAndParks
            : availableTypes.where((type) => 
                priorityTypes.contains(type) && buildingCounts[type]! < maxBuildingCounts[type]!
              ).toList();
        
        // Use priority types if available, otherwise use any available type
        final buildingType = priorityAvailable.isNotEmpty 
            ? priorityAvailable[random.nextInt(priorityAvailable.length)]
            : availableTypes[random.nextInt(availableTypes.length)];
        
        buildingCounts[buildingType] = buildingCounts[buildingType]! + 1;
        blockBuildingTypes.add(buildingType);
        
        // Always use normal orientation (no flipping)
        _grid[by][bx] = buildingType;
        _buildingOrientations[by][bx] = BuildingOrientation.normal;
        placedTiles.add('$bx,$by');
      }
    }
  }

  /// Check if a block can be placed at the given position
  bool _canPlaceBlock(int startX, int startY, int width, int height) {
    // Check bounds
    if (startX + width > gridSize || startY + height > gridSize) {
      return false;
    }
    
    // Check that all tiles in the block are grass (not road or already a building)
    for (int y = startY; y < startY + height; y++) {
      for (int x = startX; x < startX + width; x++) {
        if (_grid[y][x] != TileType.grass) {
          return false;
        }
      }
    }
    
    // Check that at least one edge of the block is adjacent to a road
    bool adjacentToRoad = false;
    
    // Check top edge
    if (startY > 0) {
      for (int x = startX; x < startX + width; x++) {
        if (_grid[startY - 1][x] == TileType.road) {
          adjacentToRoad = true;
          break;
        }
      }
    }
    
    // Check bottom edge
    if (!adjacentToRoad && startY + height < gridSize) {
      for (int x = startX; x < startX + width; x++) {
        if (_grid[startY + height][x] == TileType.road) {
          adjacentToRoad = true;
          break;
        }
      }
    }
    
    // Check left edge
    if (!adjacentToRoad && startX > 0) {
      for (int y = startY; y < startY + height; y++) {
        if (_grid[y][startX - 1] == TileType.road) {
          adjacentToRoad = true;
          break;
        }
      }
    }
    
    // Check right edge
    if (!adjacentToRoad && startX + width < gridSize) {
      for (int y = startY; y < startY + height; y++) {
        if (_grid[y][startX + width] == TileType.road) {
          adjacentToRoad = true;
          break;
        }
      }
    }
    
    return adjacentToRoad;
  }

  /// Check if a specific tile is adjacent to a road
  bool _isTileAdjacentToRoad(int x, int y) {
    // Check all four directions
    if (x > 0 && _grid[y][x - 1] == TileType.road) return true;
    if (x < gridSize - 1 && _grid[y][x + 1] == TileType.road) return true;
    if (y > 0 && _grid[y - 1][x] == TileType.road) return true;
    if (y < gridSize - 1 && _grid[y + 1][x] == TileType.road) return true;
    return false;
  }

  /// Check if a block has any buildings in it
  bool _blockHasBuildings(int startX, int startY, int width, int height) {
    for (int y = startY; y < startY + height && y < gridSize; y++) {
      for (int x = startX; x < startX + width && x < gridSize; x++) {
        if (_isBuilding(_grid[y][x])) {
          return true;
        }
      }
    }
    return false;
  }

  /// Check if a tile is adjacent to an existing building
  bool _isTileAdjacentToBuilding(int x, int y, Set<String> placedTiles) {
    // Check all four directions
    if (x > 0 && placedTiles.contains('${x - 1},$y')) return true;
    if (x < gridSize - 1 && placedTiles.contains('${x + 1},$y')) return true;
    if (y > 0 && placedTiles.contains('$x,${y - 1}')) return true;
    if (y < gridSize - 1 && placedTiles.contains('$x,${y + 1}')) return true;
    return false;
  }

  /// Convert grid coordinates to isometric screen coordinates
  /// Uses base tile as anchor point for alignment
  /// Separate spacing factors for horizontal and vertical to control side-to-side spacing independently
  Offset _gridToScreen(int gridX, int gridY) {
    // Isometric projection formula with separate spacing factors
    // The base of the tile (bottom) is at this position
    // screenX controls horizontal (side-to-side) spacing
    // screenY controls vertical (up-down) spacing
    final screenX = (gridX - gridY) * (tileWidth / 2) * horizontalSpacingFactor;
    final screenY = (gridX + gridY) * (tileHeight / 2) * tileSpacingFactor;
    return Offset(screenX, screenY);
  }

  /// Convert grid coordinates (double) to isometric screen coordinates for smooth truck movement
  Offset _gridToScreenDouble(double gridX, double gridY) {
    final screenX = (gridX - gridY) * (tileWidth / 2) * horizontalSpacingFactor;
    final screenY = (gridX + gridY) * (tileHeight / 2) * tileSpacingFactor;
    return Offset(screenX, screenY);
  }

  String _getTileAssetPath(TileType tileType, RoadDirection? roadDir) {
    switch (tileType) {
      case TileType.grass:
        return 'assets/images/tiles/grass.png';
      case TileType.road:
        if (roadDir == RoadDirection.intersection) {
          return 'assets/images/tiles/road_4way.png';
        } else {
          return 'assets/images/tiles/road_2way.png';
        }
      case TileType.shop:
        return 'assets/images/tiles/shop.png';
      case TileType.gym:
        return 'assets/images/tiles/gym.png';
      case TileType.office:
        return 'assets/images/tiles/office.png';
      case TileType.school:
        return 'assets/images/tiles/school.png';
      case TileType.gasStation:
        return 'assets/images/tiles/gas_station.png';
      case TileType.park:
        return 'assets/images/tiles/park.png';
      case TileType.house:
        return 'assets/images/tiles/house.png';
      case TileType.warehouse:
        return 'assets/images/tiles/warehouse.png';
    }
  }

  bool _isBuilding(TileType tileType) {
    return tileType == TileType.shop ||
        tileType == TileType.gym ||
        tileType == TileType.office ||
        tileType == TileType.school ||
        tileType == TileType.gasStation ||
        tileType == TileType.park ||
        tileType == TileType.house ||
        tileType == TileType.warehouse;
  }

  /// Get the scale factor for a specific building type
  double _getBuildingScale(TileType tileType) {
    switch (tileType) {
      case TileType.gasStation:
        return gasStationScale;
      case TileType.park:
        return parkScale;
      case TileType.house:
        return houseScale;
      case TileType.warehouse:
        return warehouseScale;
      default:
        return buildingScale; // Default scale for other buildings
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate map bounds - need to find the actual bounds including all tile content
    // Check all tiles to find the true min/max positions
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    
    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        final screenPos = _gridToScreen(x, y);
        
        // Ground tile bounds
        minX = math.min(minX, screenPos.dx);
        maxX = math.max(maxX, screenPos.dx + tileWidth);
        minY = math.min(minY, screenPos.dy);
        maxY = math.max(maxY, screenPos.dy + tileHeight);
        
        // Building bounds (if present) - extend upward
        if (_isBuilding(_grid[y][x])) {
          final buildingTop = screenPos.dy - (buildingImageHeight - tileHeight);
          minY = math.min(minY, buildingTop);
        }
      }
    }
    
    // Add generous padding to ensure nothing is clipped
    // Extra padding at top for buildings that extend upward
    const double sidePadding = 100.0;
    const double topPadding = 150.0; // Very generous padding for building tops
    const double bottomPadding = 100.0;
    
    minX -= sidePadding;
    maxX += sidePadding;
    minY -= topPadding;
    maxY += bottomPadding;
    
    final mapWidth = maxX - minX;
    final mapHeight = maxY - minY;
    
    // Get available viewport size (accounting for AppBar)
    final viewportWidth = MediaQuery.of(context).size.width;
    final viewportHeight = MediaQuery.of(context).size.height;
    final appBarHeight = AppBar().preferredSize.height + MediaQuery.of(context).padding.top;
    final availableHeight = viewportHeight - appBarHeight;
    
    // Center offset to position map in viewport
    final centerOffset = Offset(
      (viewportWidth - mapWidth) / 2 - minX,
      (availableHeight - mapHeight) / 2 - minY,
    );

    return Scaffold(
      // AppBar removed - MainScreen already provides one
      body: Stack(
        children: [
          InteractiveViewer(
            boundaryMargin: const EdgeInsets.all(200),
            minScale: 0.3,
            maxScale: 3.0,
            child: SizedBox(
              width: mapWidth,
              height: mapHeight,
              child: Stack(
                clipBehavior: Clip.none, // Don't clip content
                children: _buildTiles(centerOffset),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build all tiles in correct render order
  /// Render from farthest (top) to closest (bottom) using painter's algorithm
  /// Sort by depth: (x+y) ascending, then y ascending, then x ascending
  List<Widget> _buildTiles(Offset centerOffset) {
    final tileData = <Map<String, dynamic>>[];

    // Collect all tile data with their positions
    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        final tileType = _grid[y][x];
        final roadDir = _roadDirections[y][x];
        final buildingOrientation = _buildingOrientations[y][x];
        final screenPos = _gridToScreen(x, y);
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

    // Sort by depth: farthest (lowest x+y) to closest (highest x+y)
    // Then by y, then by x for consistent ordering
    tileData.sort((a, b) {
      final depthA = (a['x'] as int) + (a['y'] as int);
      final depthB = (b['x'] as int) + (b['y'] as int);
      if (depthA != depthB) return depthA.compareTo(depthB);
      final yA = a['y'] as int;
      final yB = b['y'] as int;
      if (yA != yB) return yA.compareTo(yB);
      return (a['x'] as int).compareTo(b['x'] as int);
    });

    // Build tiles in sorted order (farthest to closest)
    final tiles = <Widget>[];
    for (final data in tileData) {
      final tileType = data['tileType'] as TileType;
      final roadDir = data['roadDir'] as RoadDirection?;
      final buildingOrientation = data['buildingOrientation'] as BuildingOrientation?;
      final positionedX = data['positionedX'] as double;
      final positionedY = data['positionedY'] as double;

        // --- UPDATED WAREHOUSE LOGIC START ---
        if (tileType == TileType.warehouse) {
          // Use building-style dimensions so the tall image fits
          final warehouseScaleFactor = warehouseScale;
          
          // 1. Calculate scaled dimensions (using buildingImageHeight, not tileHeight)
          final scaledHeight = buildingImageHeight * warehouseScaleFactor;
          final scaledWidth = tileWidth * warehouseScaleFactor;
          
          // 2. Center horizontally
          final centerOffsetX = (tileWidth - scaledWidth) / 2;
          
          // 3. Calculate Top Position
          // Anchored at bottom (positionedY) but raised by the height difference
          // and the specific warehouseVerticalOffset
          final top = positionedY - (scaledHeight - tileHeight) - warehouseVerticalOffset;
          
          tiles.add(
            Positioned(
              left: positionedX + centerOffsetX,
              top: top,
              width: scaledWidth,
              height: scaledHeight,
              // Reuse _buildGroundTile as it sets up the image correctly
              child: _buildGroundTile(tileType, roadDir),
            ),
          );
        // --- UPDATED WAREHOUSE LOGIC END ---
        
        } else if (!_isBuilding(tileType)) {
          // Regular ground tiles (grass, road)
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
          // For other buildings, show grass as the ground tile underneath
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

      // Building tile (if applicable) - anchored at bottom-center, extends upward
      // Scaled down to fit better within tile bounds
      // Each building type can have its own scale factor
      // Skip warehouse here since it's rendered as a ground tile above
      if (_isBuilding(tileType) && tileType != TileType.warehouse) {
        final buildingScaleFactor = _getBuildingScale(tileType);
        final scaledBuildingHeight = buildingImageHeight * buildingScaleFactor;
        final buildingTop = positionedY - (scaledBuildingHeight - tileHeight);
        final scaledWidth = tileWidth * buildingScaleFactor;
        final centerOffsetX = (tileWidth - scaledWidth) / 2; // Center the scaled building
        
        // Apply vertical offset for warehouse to raise it to match other buildings
        final verticalOffset = tileType == TileType.warehouse ? warehouseVerticalOffset : 0.0;
        
        tiles.add(
          Positioned(
            left: positionedX + centerOffsetX,
            top: buildingTop - verticalOffset,
            width: scaledWidth,
            height: scaledBuildingHeight,
            child: GestureDetector(
              onTap: () => _handleBuildingTap(data['x'] as int, data['y'] as int, tileType),
              child: _buildBuildingTile(tileType, buildingOrientation),
            ),
          ),
        );

        // Add "+" purchase button indicator above building if machine can be purchased
        if (_shouldShowPurchaseButton(data['x'] as int, data['y'] as int, tileType)) {
          final buttonSize = 24.0;
          final buttonTop = buildingTop - verticalOffset - buttonSize + 8.0; // Lowered: 8px above building (was -4px)
          final buttonLeft = positionedX + (tileWidth / 2) - (buttonSize / 2); // Centered above building
          
          tiles.add(
            Positioned(
              left: buttonLeft,
              top: buttonTop,
              width: buttonSize,
              height: buttonSize,
              child: GestureDetector(
                onTap: () => _handleBuildingTap(data['x'] as int, data['y'] as int, tileType),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          );
        }
      }
    }

    // Add real machines from simulation on top of tiles
    final gameMachines = ref.watch(machinesProvider);
    for (final machine in gameMachines) {
      tiles.add(_buildGameMachine(machine, centerOffset));
    }

    // Add real trucks from simulation on top of tiles (above machines)
    final gameTrucks = ref.watch(trucksProvider);
    for (final truck in gameTrucks) {
      tiles.add(_buildGameTruck(truck, centerOffset));
    }

    return tiles;
  }

  /// Build positioned game machine widget
  Widget _buildGameMachine(sim.Machine machine, Offset centerOffset) {
    // Convert zone coordinates to grid coordinates
    final gridPos = _zoneToGrid(machine.zone.x, machine.zone.y);
    
    // Get screen coordinates from grid position
    final pos = _gridToScreenDouble(gridPos.dx, gridPos.dy);
    final positionedX = pos.dx + centerOffset.dx;
    final positionedY = pos.dy + centerOffset.dy;
    
    // Machine indicator size
    final double machineSize = tileWidth * 0.3;
    
    // Center on tile
    final left = positionedX + (tileWidth - machineSize) / 2;
    final top = positionedY + (tileHeight / 2) - machineSize;

    // Determine machine color based on type
    Color machineColor;
    switch (machine.zone.type) {
      case ZoneType.park: // Shop
        machineColor = Colors.blue;
        break;
      case ZoneType.school:
        machineColor = Colors.purple;
        break;
      case ZoneType.gym:
        machineColor = Colors.red;
        break;
      case ZoneType.office:
        machineColor = Colors.orange;
        break;
      default:
        machineColor = Colors.grey;
    }

    return Positioned(
      left: left,
      top: top,
      width: machineSize,
      height: machineSize,
      child: Container(
        decoration: BoxDecoration(
          color: machineColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Center(
          child: Icon(
            Icons.shopping_cart,
            color: Colors.white,
            size: machineSize * 0.6,
          ),
        ),
      ),
    );
  }

  /// Convert zone coordinates (1.0-10.0) to grid coordinates (0-9)
  /// Zone coordinates: machines at .5 positions (1.5, 2.5, etc.), roads at integers
  /// Grid coordinates: 0-9 for tile positions
  Offset _zoneToGrid(double zoneX, double zoneY) {
    // Zone coordinates start at 1.0, grid starts at 0
    // Zone 1.0-2.0 maps to grid 0, Zone 2.0-3.0 maps to grid 1, etc.
    final gridX = (zoneX - 1.0).clamp(0.0, (gridSize - 1).toDouble());
    final gridY = (zoneY - 1.0).clamp(0.0, (gridSize - 1).toDouble());
    return Offset(gridX, gridY);
  }

  /// Build positioned game truck widget
  Widget _buildGameTruck(sim.Truck truck, Offset centerOffset) {
    // Convert zone coordinates to grid coordinates
    final gridPos = _zoneToGrid(truck.currentX, truck.currentY);
    
    // Get screen coordinates from grid position
    final pos = _gridToScreenDouble(gridPos.dx, gridPos.dy);
    final positionedX = pos.dx + centerOffset.dx;
    final positionedY = pos.dy + centerOffset.dy;
    
    // Size & Centering Logic
    final double truckSize = tileWidth * 0.4; 
    
    // Center logic:
    // X: Tile Left + (TileWidth - TruckWidth) / 2
    // Y: Tile Top + (TileHeight / 2) - TruckHeight (sit on middle of diamond)
    final left = positionedX + (tileWidth - truckSize) / 2;
    final top = positionedY + (tileHeight / 2) - truckSize;

    // Determine truck direction based on movement
    // truck_front faces left down (no flip) - used for South
    // truck_front flipped faces right down - used for East
    // truck_back faces left up (no flip) - used for West
    // truck_back flipped faces right up - used for North
    String asset = 'assets/images/tiles/truck_front.png';
    bool flip = false;
    
    // Calculate direction - prefer using path waypoints if available for more accurate direction
    double dx = 0.0;
    double dy = 0.0;
    
    if (truck.path.isNotEmpty && truck.pathIndex < truck.path.length) {
      // Use next waypoint in path for direction
      final nextWaypoint = truck.path[truck.pathIndex];
      dx = nextWaypoint.x - truck.currentX;
      dy = nextWaypoint.y - truck.currentY;
    } else {
      // Fall back to target direction
      dx = truck.targetX - truck.currentX;
      dy = truck.targetY - truck.currentY;
    }
    
    // Only update direction if truck is actually moving
    if (dx.abs() > 0.01 || dy.abs() > 0.01) {
      // Determine primary direction (horizontal vs vertical)
      if (dx.abs() > dy.abs()) {
        // Moving primarily horizontally
        if (dx > 0) {
          // Moving right (East) - use truck_front flipped (right down)
          asset = 'assets/images/tiles/truck_front.png';
          flip = true;
        } else {
          // Moving left (West) - use truck_back (left up)
          asset = 'assets/images/tiles/truck_back.png';
          flip = false;
        }
      } else {
        // Moving primarily vertically
        if (dy > 0) {
          // Moving down (South) - use truck_front (left down)
          asset = 'assets/images/tiles/truck_front.png';
          flip = false;
        } else {
          // Moving up (North) - use truck_back flipped (right up)
          asset = 'assets/images/tiles/truck_back.png';
          flip = true;
        }
      }
    }
    // If not moving (dx and dy are both near 0), keep last direction

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
            style: const TextStyle(fontSize: 12, color: Colors.white),
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

  Widget _buildGroundTile(TileType tileType, RoadDirection? roadDir) {
    final isRoad = tileType == TileType.road;
    final needsFlip = isRoad && roadDir == RoadDirection.vertical;

    Widget imageWidget = Image.asset(
      _getTileAssetPath(tileType, roadDir),
      fit: BoxFit.contain, // Changed from cover to contain to show full image
      alignment: Alignment.bottomCenter, // Anchor at bottom
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

    // Flip road sprites instead of rotating
    if (needsFlip) {
      return Transform(
        alignment: Alignment.bottomCenter, // Flip around bottom center
        transform: Matrix4.identity()..scale(-1.0, 1.0), // Flip horizontally
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildBuildingTile(TileType tileType, BuildingOrientation? orientation) {
    Widget imageWidget = Image.asset(
      _getTileAssetPath(tileType, null),
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter, // Anchor at bottom-center
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

    // Apply horizontal flip based on orientation
    if (orientation == BuildingOrientation.flippedHorizontal) {
      return Transform(
        alignment: Alignment.bottomCenter, // Flip around bottom center
        transform: Matrix4.identity()..scale(-1.0, 1.0), // Flip horizontally
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Color _getFallbackColor(TileType tileType) {
    switch (tileType) {
      case TileType.grass:
        return Colors.green.shade300;
      case TileType.road:
        return Colors.grey.shade600;
      case TileType.shop:
        return Colors.blue.shade300;
      case TileType.gym:
        return Colors.red.shade300;
      case TileType.office:
        return Colors.orange.shade300;
      case TileType.school:
        return Colors.purple.shade300;
      case TileType.gasStation:
        return Colors.yellow.shade300;
      case TileType.park:
        return Colors.green.shade400;
      case TileType.house:
        return Colors.brown.shade300;
      case TileType.warehouse:
        return Colors.grey.shade400;
    }
  }

  String _getTileLabel(TileType tileType) {
    switch (tileType) {
      case TileType.grass:
        return 'G';
      case TileType.road:
        return 'R';
      case TileType.shop:
        return 'S';
      case TileType.gym:
        return 'G';
      case TileType.office:
        return 'O';
      case TileType.school:
        return 'Sc';
      case TileType.gasStation:
        return 'GS';
      case TileType.park:
        return 'P';
      case TileType.house:
        return 'H';
      case TileType.warehouse:
        return 'W';
    }
  }

  /// Handle building tap - purchase machine at this location
  void _handleBuildingTap(int gridX, int gridY, TileType tileType) {
    // Convert grid coordinates to zone coordinates
    // Grid: 0-9, Zone: 1.0-10.0 (machines at .5 positions)
    final zoneX = (gridX + 1).toDouble() + 0.5;
    final zoneY = (gridY + 1).toDouble() + 0.5;

    // Map TileType to ZoneType
    final zoneType = _tileTypeToZoneType(tileType);
    if (zoneType == null) {
      // Building type doesn't support machines
      return;
    }

    // Check if this building type can be purchased (progression check)
    if (!_canPurchaseMachine(zoneType)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getProgressionMessage(zoneType)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Check if there's already a machine at this location
    final controller = ref.read(gameControllerProvider.notifier);
    final machines = ref.read(machinesProvider);
    final hasExistingMachine = machines.any(
      (m) => (m.zone.x - zoneX).abs() < 0.1 && (m.zone.y - zoneY).abs() < 0.1,
    );
    
    if (hasExistingMachine) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A machine already exists at this location'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Purchase machine with auto-stocking
    controller.buyMachineWithStock(zoneType, x: zoneX, y: zoneY);
  }

  /// Check if a building should show the "+" purchase indicator
  bool _shouldShowPurchaseButton(int gridX, int gridY, TileType tileType) {
    // Convert grid coordinates to zone coordinates
    final zoneX = (gridX + 1).toDouble() + 0.5;
    final zoneY = (gridY + 1).toDouble() + 0.5;

    // Check if building type supports machines
    final zoneType = _tileTypeToZoneType(tileType);
    if (zoneType == null) {
      return false;
    }

    // Check if machine can be purchased (progression check)
    if (!_canPurchaseMachine(zoneType)) {
      return false;
    }

    // Check if there's already a machine at this location
    final machines = ref.watch(machinesProvider);
    final hasExistingMachine = machines.any(
      (m) => (m.zone.x - zoneX).abs() < 0.1 && (m.zone.y - zoneY).abs() < 0.1,
    );

    return !hasExistingMachine;
  }

  /// Map TileType to ZoneType
  ZoneType? _tileTypeToZoneType(TileType tileType) {
    switch (tileType) {
      case TileType.shop:
        return ZoneType.park; // Shop maps to park zone
      case TileType.school:
        return ZoneType.school;
      case TileType.gym:
        return ZoneType.gym;
      case TileType.office:
        return ZoneType.office;
      default:
        return null; // Other building types don't support machines
    }
  }

  /// Check if machine type can be purchased based on progression
  /// Progression: Shop (2) -> School (2) -> Gym (2) -> Office (2)
  bool _canPurchaseMachine(ZoneType zoneType) {
    final machines = ref.read(machinesProvider);
    final shopMachines = machines.where((m) => m.zone.type == ZoneType.park).length;
    final schoolMachines = machines.where((m) => m.zone.type == ZoneType.school).length;
    final gymMachines = machines.where((m) => m.zone.type == ZoneType.gym).length;
    final officeMachines = machines.where((m) => m.zone.type == ZoneType.office).length;

    switch (zoneType) {
      case ZoneType.park: // Shop
        return shopMachines < 2;
      case ZoneType.school:
        return shopMachines >= 2 && schoolMachines < 2;
      case ZoneType.gym:
        return schoolMachines >= 2 && gymMachines < 2;
      case ZoneType.office:
        return gymMachines >= 2 && officeMachines < 2;
      default:
        return false;
    }
  }

  /// Get progression message for locked machine types
  String _getProgressionMessage(ZoneType zoneType) {
    final machines = ref.read(machinesProvider);
    final shopMachines = machines.where((m) => m.zone.type == ZoneType.park).length;
    final schoolMachines = machines.where((m) => m.zone.type == ZoneType.school).length;
    final gymMachines = machines.where((m) => m.zone.type == ZoneType.gym).length;
    final officeMachines = machines.where((m) => m.zone.type == ZoneType.office).length;
    
    switch (zoneType) {
      case ZoneType.park: // Shop
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
      default:
        return 'Cannot purchase this machine type';
    }
  }
}
