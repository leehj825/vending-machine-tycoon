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
  static const int gridSize = 20;
  
  // Isometric tile dimensions (tweakable constants)
  static const double tileWidth = 64.0;
  static const double tileHeight = 32.0;
  
  // Building image height (assumed taller than ground tiles)
  static const double buildingImageHeight = 80.0;
  
  // Block dimensions
  static const int minBlockWidth = 2;
  static const int maxBlockWidth = 4;
  static const int minBlockHeight = 2;
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
    final random = math.Random();
    
    // Create a grid pattern with roads every few tiles
    // This creates rectangular blocks
    const int roadSpacing = 4; // Roads every 4 tiles (creates ~3x3 blocks)
    
    // Horizontal roads (running East-West in grid, diagonal in isometric)
    for (int y = roadSpacing; y < gridSize - roadSpacing; y += roadSpacing) {
      for (int x = 0; x < gridSize; x++) {
        if (x >= 0 && x < gridSize) {
          _grid[y][x] = TileType.road;
        }
      }
    }
    
    // Vertical roads (running North-South in grid, diagonal in isometric)
    for (int x = roadSpacing; x < gridSize - roadSpacing; x += roadSpacing) {
      for (int y = 0; y < gridSize; y++) {
        if (y >= 0 && y < gridSize) {
          _grid[y][x] = TileType.road;
        }
      }
    }
    
    // Add some random additional roads for variety
    for (int i = 0; i < 10; i++) {
      final x = random.nextInt(gridSize);
      final y = random.nextInt(gridSize);
      if (_grid[y][x] != TileType.road) {
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
  void _placeBuildingBlocks() {
    final random = math.Random();
    final buildingTypes = [
      TileType.shop,
      TileType.gym,
      TileType.office,
      TileType.school,
    ];

    // Find all rectangular areas that can fit building blocks
    final validBlocks = <Map<String, dynamic>>[];
    
    for (int startY = 0; startY < gridSize; startY++) {
      for (int startX = 0; startX < gridSize; startX++) {
        // Try different block sizes
        for (int blockWidth = minBlockWidth; blockWidth <= maxBlockWidth; blockWidth++) {
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
    }

    // Shuffle and place blocks
    validBlocks.shuffle(random);
    
    final placedBlocks = <List<int>>[]; // Track placed tiles to avoid overlaps
    
    for (final block in validBlocks) {
      final startX = block['x'] as int;
      final startY = block['y'] as int;
      final blockWidth = block['width'] as int;
      final blockHeight = block['height'] as int;
      
      // Check if this block overlaps with already placed blocks
      bool overlaps = false;
      for (int by = startY; by < startY + blockHeight && !overlaps; by++) {
        for (int bx = startX; bx < startX + blockWidth && !overlaps; bx++) {
          if (placedBlocks.any((tile) => tile[0] == bx && tile[1] == by)) {
            overlaps = true;
          }
        }
      }
      
      if (overlaps) continue;
      
      // Determine building type and orientation (50% chance of flipping)
      final buildingType = buildingTypes[random.nextInt(buildingTypes.length)];
      final orientation = random.nextBool() 
          ? BuildingOrientation.normal 
          : BuildingOrientation.flippedHorizontal;
      
      // Place the building block
      for (int by = startY; by < startY + blockHeight && by < gridSize; by++) {
        for (int bx = startX; bx < startX + blockWidth && bx < gridSize; bx++) {
          _grid[by][bx] = buildingType;
          _buildingOrientations[by][bx] = orientation;
          placedBlocks.add([bx, by]);
        }
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
  /// Adjusted to ensure proper alignment between adjacent tiles
  Offset _gridToScreen(int gridX, int gridY) {
    // Center the tile at the calculated position for better alignment
    final screenX = (gridX - gridY) * (tileWidth / 2);
    final screenY = (gridX + gridY) * (tileHeight / 2);
    // Small adjustment to ensure tiles align perfectly
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
    // Calculate map bounds for centering
    // First, find the bounds of ground tiles
    final topLeft = _gridToScreen(0, 0);
    final topRight = _gridToScreen(gridSize - 1, 0);
    final bottomLeft = _gridToScreen(0, gridSize - 1);
    final bottomRight = _gridToScreen(gridSize - 1, gridSize - 1);
    
    double minX = math.min(math.min(topLeft.dx, topRight.dx), math.min(bottomLeft.dx, bottomRight.dx));
    double maxX = math.max(math.max(topLeft.dx, topRight.dx), math.max(bottomLeft.dx, bottomRight.dx));
    double minY = math.min(math.min(topLeft.dy, topRight.dy), math.min(bottomLeft.dy, bottomRight.dy));
    double maxY = math.max(math.max(topLeft.dy, topRight.dy), math.max(bottomLeft.dy, bottomRight.dy));
    
    // Account for building heights that extend above ground tiles
    // Buildings are positioned at: positionedY - (buildingImageHeight - tileHeight)
    // So we need to subtract the extra height from minY
    final buildingOverhang = buildingImageHeight - tileHeight;
    minY -= buildingOverhang;
    
    // Add padding to ensure nothing is clipped
    const double padding = 50.0;
    minX -= padding;
    maxX += padding + tileWidth;
    minY -= padding;
    maxY += padding + tileHeight;
    
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
      appBar: AppBar(
        title: const Text('Tile City Map'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _generateMap();
              });
            },
            tooltip: 'Refresh Map',
          ),
        ],
      ),
      body: InteractiveViewer(
        boundaryMargin: const EdgeInsets.all(100),
        minScale: 0.5,
        maxScale: 3.0,
        child: SizedBox(
          width: mapWidth,
          height: mapHeight,
          child: Stack(
            children: _buildTiles(centerOffset),
          ),
        ),
      ),
    );
  }

  /// Build all tiles in correct render order (Y loop, then X loop for painter's algorithm)
  List<Widget> _buildTiles(Offset centerOffset) {
    final tiles = <Widget>[];

    // Render in depth order: Y from 0 to max, then X from 0 to max
    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        final tileType = _grid[y][x];
        final roadDir = _roadDirections[y][x];
        final buildingOrientation = _buildingOrientations[y][x];
        final screenPos = _gridToScreen(x, y);
        final positionedX = screenPos.dx + centerOffset.dx;
        final positionedY = screenPos.dy + centerOffset.dy;

        // Ground tile (grass or road)
        // Adjust positioning to center the tile properly for better alignment
        tiles.add(
          Positioned(
            left: positionedX,
            top: positionedY,
            width: tileWidth,
            height: tileHeight,
            child: _buildGroundTile(tileType, roadDir),
          ),
        );

        // Building tile (if applicable) - anchored at bottom-center
        if (_isBuilding(tileType)) {
          // Building extends upward from the ground tile
          final buildingTop = positionedY - (buildingImageHeight - tileHeight);
          tiles.add(
            Positioned(
              left: positionedX,
              top: buildingTop,
              width: tileWidth,
              height: buildingImageHeight,
              child: _buildBuildingTile(tileType, buildingOrientation),
            ),
          );
        }
      }
    }

    return tiles;
  }

  Widget _buildGroundTile(TileType tileType, RoadDirection? roadDir) {
    final isRoad = tileType == TileType.road;
    final needsFlip = isRoad && roadDir == RoadDirection.vertical;

    Widget imageWidget = Image.asset(
      _getTileAssetPath(tileType, roadDir),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: _getFallbackColor(tileType),
          child: Center(
            child: Text(
              _getTileLabel(tileType),
              style: const TextStyle(fontSize: 8),
            ),
          ),
        );
      },
    );

    // Flip road sprites instead of rotating
    if (needsFlip) {
      return Transform(
        alignment: Alignment.center,
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

    // Apply horizontal flip based on orientation
    if (orientation == BuildingOrientation.flippedHorizontal) {
      return Transform(
        alignment: Alignment.bottomCenter,
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
