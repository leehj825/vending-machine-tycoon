import 'dart:math' as math;
import 'package:flutter/material.dart';

enum TileType {
  grass,
  road,
  shop,
  gym,
  office,
  school,
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

class TileCityScreen extends StatefulWidget {
  const TileCityScreen({super.key});

  @override
  State<TileCityScreen> createState() => _TileCityScreenState();
}

class _TileCityScreenState extends State<TileCityScreen> {
  static const int gridSize = 15;
  
  // Isometric tile dimensions (tweakable constants)
  // Reduced spacing to make tiles closer together
  static const double tileWidth = 64.0;
  static const double tileHeight = 32.0;
  static const double tileSpacingFactor = 0.88; // Reduced further to make tiles closer
  
  // Building image height (assumed taller than ground tiles)
  // Adjusted to make buildings larger
  static const double buildingImageHeight = 75.0; // Increased from 60.0
  static const double buildingScale = 0.95; // Increased from 0.75 to make buildings larger
  
  // Block dimensions - only 2x3 or 2x4
  static const int blockWidth = 2;
  static const int minBlockHeight = 3;
  static const int maxBlockHeight = 4;
  
  late List<List<TileType>> _grid;
  late List<List<RoadDirection?>> _roadDirections;
  late List<List<BuildingOrientation?>> _buildingOrientations;

  @override
  void initState() {
    super.initState();
    _generateMap();
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

    // Place building blocks
    _placeBuildingBlocks();
  }

  /// Generate a grid-based road system that forms rectangular blocks
  void _generateRoadGrid() {
    // Create a grid pattern with roads every few tiles
    // This creates rectangular blocks
    const int roadSpacing = 4; // Roads every 4 tiles (creates ~3x3 blocks)
    
    // Horizontal roads (running East-West in grid, diagonal in isometric)
    for (int y = roadSpacing; y < gridSize - roadSpacing; y += roadSpacing) {
      for (int x = 0; x < gridSize; x++) {
        _grid[y][x] = TileType.road;
      }
    }
    
    // Vertical roads (running North-South in grid, diagonal in isometric)
    for (int x = roadSpacing; x < gridSize - roadSpacing; x += roadSpacing) {
      for (int y = 0; y < gridSize; y++) {
        _grid[y][x] = TileType.road;
      }
    }
    
    // Update road directions
    _updateRoadDirections();
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

    final int connections = (hasNorth ? 1 : 0) +
        (hasSouth ? 1 : 0) +
        (hasEast ? 1 : 0) +
        (hasWest ? 1 : 0);

    // Intersection or corner (3+ connections)
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

    // Default to intersection for corners and dead ends
    return RoadDirection.intersection;
  }

  /// Place building blocks (2x3 or 2x4 tiles) in areas between roads
  /// Maximum 2 of each building type globally
  /// Within each block, no duplicate building types (can mix with grass)
  void _placeBuildingBlocks() {
    final random = math.Random();
    final buildingTypes = [
      TileType.shop,
      TileType.gym,
      TileType.office,
      TileType.school,
    ];

    // Track building type counts globally
    final buildingCounts = <TileType, int>{
      TileType.shop: 0,
      TileType.gym: 0,
      TileType.office: 0,
      TileType.school: 0,
    };

    // Find all rectangular areas that can fit building blocks (2x3 or 2x4)
    final validBlocks = <Map<String, dynamic>>[];
    
    for (int startY = 0; startY < gridSize; startY++) {
      for (int startX = 0; startX < gridSize; startX++) {
        // Try 2x3 and 2x4 blocks only
        for (int blockHeight = minBlockHeight; blockHeight <= maxBlockHeight; blockHeight++) {
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

    // Shuffle and place blocks
    validBlocks.shuffle(random);
    
    final placedTiles = <String>{}; // Track placed tiles as "x,y" strings to avoid overlaps
    
    for (final block in validBlocks) {
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
      
      // Shuffle block tiles to randomize placement
      blockTiles.shuffle(random);
      
      // Place buildings in some tiles (not all - can mix with grass)
      final numBuildings = random.nextInt(blockTiles.length ~/ 2) + 1; // At least 1, up to half
      
      for (int i = 0; i < numBuildings && i < blockTiles.length; i++) {
        final tile = blockTiles[i];
        final bx = tile[0];
        final by = tile[1];
        
        // Get available building types (not used in this block, and under global limit)
        final availableTypes = buildingTypes.where((type) => 
          !blockBuildingTypes.contains(type) && buildingCounts[type]! < 2
        ).toList();
        
        if (availableTypes.isEmpty) break; // No more types available
        
        final buildingType = availableTypes[random.nextInt(availableTypes.length)];
        buildingCounts[buildingType] = buildingCounts[buildingType]! + 1;
        blockBuildingTypes.add(buildingType);
        
        final orientation = random.nextBool() 
            ? BuildingOrientation.normal 
            : BuildingOrientation.flippedHorizontal;
        
        _grid[by][bx] = buildingType;
        _buildingOrientations[by][bx] = orientation;
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

  /// Convert grid coordinates to isometric screen coordinates
  /// Uses base tile as anchor point for alignment
  /// Reduced spacing factor to make tiles closer together
  Offset _gridToScreen(int gridX, int gridY) {
    // Isometric projection formula with spacing reduction
    // The base of the tile (bottom) is at this position
    final screenX = (gridX - gridY) * (tileWidth / 2) * tileSpacingFactor;
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
    }
  }

  bool _isBuilding(TileType tileType) {
    return tileType == TileType.shop ||
        tileType == TileType.gym ||
        tileType == TileType.office ||
        tileType == TileType.school;
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
          // Floating refresh button
          Positioned(
            top: 16,
            right: 16,
            child: FloatingActionButton.small(
              onPressed: () {
                setState(() {
                  _generateMap();
                });
              },
              child: const Icon(Icons.refresh),
              tooltip: 'Refresh Map',
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

        // Ground tile (grass or road) - anchored at base
        tiles.add(
          Positioned(
            left: positionedX,
            top: positionedY,
            width: tileWidth,
            height: tileHeight,
            child: _buildGroundTile(tileType, roadDir),
          ),
        );

      // Building tile (if applicable) - anchored at bottom-center, extends upward
      // Scaled down to fit better within tile bounds
      if (_isBuilding(tileType)) {
        final scaledBuildingHeight = buildingImageHeight * buildingScale;
        final buildingTop = positionedY - (scaledBuildingHeight - tileHeight);
        final scaledWidth = tileWidth * buildingScale;
        final centerOffsetX = (tileWidth - scaledWidth) / 2; // Center the scaled building
        
        tiles.add(
          Positioned(
            left: positionedX + centerOffsetX,
            top: buildingTop,
            width: scaledWidth,
            height: scaledBuildingHeight,
            child: _buildBuildingTile(tileType, buildingOrientation),
          ),
        );
      }
    }

    return tiles;
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
    }
  }
}
