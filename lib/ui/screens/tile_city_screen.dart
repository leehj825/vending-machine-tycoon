import 'dart:convert';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/providers.dart';
import '../../state/selectors.dart';
import '../../state/city_map_state.dart';
import '../../simulation/city_roads.dart';
import '../../simulation/models/zone.dart';
import '../../simulation/models/machine.dart' as sim;
import '../../simulation/models/product.dart';
import '../../simulation/models/weather.dart';
import '../../simulation/models/pricing.dart';
import '../../config.dart';
import '../theme/zone_ui.dart';
import '../utils/screen_utils.dart';
import '../widgets/machine_interior_dialog.dart';
import '../widgets/marketing_button.dart';
import '../three_d/city_scene_3d.dart';
import '../three_d/city_web_protocol.dart';
import '../three_d/people_look.dart';
import '../three_d/city_webview.dart';
import '../three_d/lowpoly_engine.dart';
import '../theme/vex_theme.dart';
import '../theme/vex_widgets.dart';
import '../three_d/human_rig.dart';
import '../three_d/vending_machine_3d.dart';

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
/// Scale from the figure's own size to a tile: a person is about a machine's height.
const double _walkerScale = 0.13;

class _PedestrianState {
  final int personId; // 0-9
  double gridX;
  double gridY;
  double? targetGridX;
  double? targetGridY;
  double? previousGridX; // Previous position to avoid going back and forth
  double? previousGridY; // Previous position to avoid going back and forth
  String direction; // 'front', 'back'
  bool flipHorizontal;
  int stepsWalked; // Track how many steps the pedestrian has taken
  bool isHeadingToShop; // Whether pedestrian is heading to a machine (forced by tap)
  int stuckCounter; // Track how many frames the pedestrian hasn't moved (for stuck detection)
  int? lastTileX; // Last tile X position (for stuck detection)
  int? lastTileY; // Last tile Y position (for stuck detection)
  int sameTileCounter; // How many frames the pedestrian has been in the same tile
  String? targetMachineId; // ID of machine to visit when isHeadingToShop is true
  int? jumpStartStep; // Step count when jump animation started (for jump effect)
  List<({int x, int y})> path; // Path waypoints through road tiles (A* pathfinding)
  int pathIndex; // Current index in path
  final HumanPose pose = HumanPose(); // Walk cycle state for the 3D figure
  int walkSide = 0; // +1 walks on the right of their heading, -1 on the left; 0 until placed
  // Where they stand, as an offset from their tile centre. It eases toward the side they
  // walk on, so turning or changing sides slides them over instead of jumping.
  double offsetX = 0;
  double offsetZ = 0;
  // The tile the side was last chosen on. The side is chosen again only on a new tile, so
  // a walker does not swap sides, and cross the road, each time the pavement test flips.
  int? sideTileX;
  int? sideTileY;
  // Set when the walker is going into a building or off the map. They are removed there.
  int? enterX;
  int? enterY;
  
  _PedestrianState({
    required this.personId,
    required this.gridX,
    required this.gridY,
    this.targetGridX,
    this.targetGridY,
    this.previousGridX,
    this.previousGridY,
    this.direction = 'front',
    this.flipHorizontal = false,
    this.stepsWalked = 0,
    this.isHeadingToShop = false,
    this.stuckCounter = 0,
    this.lastTileX,
    this.lastTileY,
    this.sameTileCounter = 0,
    this.targetMachineId,
    this.jumpStartStep,
    this.path = const [],
    this.pathIndex = 0,
  });
}

class TileCityScreen extends ConsumerStatefulWidget {
  const TileCityScreen({super.key});

  @override
  ConsumerState<TileCityScreen> createState() => _TileCityScreenState();
}

class _TileCityScreenState extends ConsumerState<TileCityScreen> with TickerProviderStateMixin {
  static const int gridSize = 15; // Using AppConfig.cityGridSize value
  
  // Tile dimensions will be calculated relative to screen size
  
  
  // Road tile dimensions (scaled relative to regular tiles)
  // These multipliers scale road tiles proportionally with regular tiles
  
  
  // Road tile position offsets (adjust to shift road tiles)
  // Made density-independent by using relative sizing
  
  
  
  
  
  
  // Horizontal offsets (relative size multipliers)
  



  
  
  late List<List<TileType>> _grid;
  late List<List<RoadDirection?>> _roadDirections;
  late List<List<BuildingOrientation?>> _buildingOrientations;
  
  // Sprite sheet for road tiles
  
  int? _warehouseX;
  int? _warehouseY;
  
  late TransformationController _transformationController;
  bool _isPanning = false;
  Timer? _panEndTimer;
  
  // Debounce tracking
  DateTime? _lastTapTime;
  String? _lastTappedButton;
  
  // Tutorial state
  bool _showPedestrianTutorial = false;
  _PedestrianState? _tutorialPedestrian;
  AnimationController? _tutorialBlinkController;
  
  // Draggable message position (null = use default position)
  
  // Pedestrian management
  final List<_PedestrianState> _pedestrians = [];
  Timer? _pedestrianUpdateTimer;
  final Map<int, int> _personIdCounts = {}; // Track count of each personId (max 1 per personId - 10 unique pedestrians max)
  final math.Random _pedestrianRandom = math.Random();

  // The city draws as a 3D lowpoly scene by default. The 2D isometric map stays
  // available through the toggle in the top-right corner.
  final CityWebController _mapController = CityWebController();
  // The machine whose details panel is open over the map, and whether it is minimized.
  String? _openMachineId;
  bool _machinePanelMinimized = false;
  // The static city as JSON, sent to the page when it changes.
  String? _scene3D;
  List<List<TileType>>? _scene3DGrid;
  // What the scene shows: the machines as drawn, and the lighting. The machines list
  // is replaced on every simulation tick, so its identity says nothing about the scene.
  String? _scene3DSignature;
  // Customers who walk past each machine on the pavement. Each machine has its own
  // walker, and its own record of the last time a customer bought from it.
  // When each machine last sold to a walker passing its front.
  final Map<String, DateTime> _customerSoldAt = {};
  final GlobalKey<MarketingButtonState> _marketingKey = GlobalKey<MarketingButtonState>();

  @override
  void initState() {
    super.initState();
    // Initialize with a zoomed-in view (scale 1.5)
    _transformationController = TransformationController();
    
    // Listen to transformation changes to detect panning
    _transformationController.addListener(_onTransformationChanged);
    
    // Load road tiles sprite sheet
    
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
      _personIdCounts.clear();
      _pedestrians.clear();
      _spawnPedestrians();
      
      // Start pedestrian update timer
      _pedestrianUpdateTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        if (mounted) {
          _updatePedestrians();
          setState(() {}); // Trigger rebuild to show movement
        }
      });
      
      // Initialize tutorial blink animation
      _tutorialBlinkController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
      )..repeat(reverse: true);
      
      // Check if tutorial should be shown (when machines exist)
      _checkAndShowTutorial(); // Async function, will handle SharedPreferences check
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
    _tutorialBlinkController?.dispose();
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

    _loadMap(math.Random());
    _placeBuildings();
    
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

  /// Lays out the roads with a fresh random network, then sets the tile types.
  void _loadMap(math.Random random) {
    final roads = generateRoadMask(gridSize, random);
    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        _grid[y][x] = roads[y][x] ? TileType.road : TileType.grass;
      }
    }

    // Update bitmasks for road rendering
    _updateRoadDirections();
  }

  /// Helper function to calculate distance between two points
  double _distance(int x1, int y1, int x2, int y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    return math.sqrt(dx * dx + dy * dy);
  }
  
  /// Helper function to find the best spot that's far from existing buildings of the SAME type
  List<int>? _findSpreadOutSpot(
    List<List<int>> availableSpots,
    Map<TileType, List<List<int>>> buildingsByType,
    TileType buildingType,
    double minDistance,
    math.Random random,
  ) {
    if (availableSpots.isEmpty) return null;
    
    // Get only buildings of the same type
    final sameTypeBuildings = buildingsByType[buildingType] ?? [];
    
    // If no buildings of this type exist yet, just pick a random spot
    if (sameTypeBuildings.isEmpty) {
      availableSpots.shuffle(random);
      return availableSpots[0];
    }
    
    // Shuffle to add randomness
    final shuffled = List<List<int>>.from(availableSpots);
    shuffled.shuffle(random);
    
    // Try to find a spot that's at least minDistance away from all buildings of the same type
    for (final spot in shuffled) {
      bool tooClose = false;
      for (final building in sameTypeBuildings) {
        final dist = _distance(spot[0], spot[1], building[0], building[1]);
        if (dist < minDistance) {
          tooClose = true;
          break;
        }
      }
      if (!tooClose) {
        return spot;
      }
    }
    
    // If no spot meets the distance requirement, find the one that's farthest from same-type buildings
    List<int>? bestSpot;
    double maxMinDistance = -1;
    for (final spot in shuffled) {
      double minDistToAnyBuilding = double.infinity;
      for (final building in sameTypeBuildings) {
        final dist = _distance(spot[0], spot[1], building[0], building[1]);
        if (dist < minDistToAnyBuilding) {
          minDistToAnyBuilding = dist;
        }
      }
      if (minDistToAnyBuilding > maxMinDistance) {
        maxMinDistance = minDistToAnyBuilding;
        bestSpot = spot;
      }
    }
    
    return bestSpot ?? shuffled[0];
  }

  /// Place buildings randomly on grass tiles adjacent to roads, spread out evenly
  void _placeBuildings() {
    final random = math.Random();
    
    // Step A: Find Valid Spots (grass tiles adjacent to at least one road)
    final validSpots = <List<int>>[];
    final northSpots = <List<int>>[]; // Spots in top rows (for gas stations)
    final southSpots = <List<int>>[]; // Spots in bottom rows (for gas stations)
    final otherSpots = <List<int>>[]; // Other spots (for other buildings)
    
    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        if (_grid[y][x] == TileType.grass) {
          // Check if at least one neighbor is a road
          bool hasRoadNeighbor = false;
          if (y > 0 && _grid[y - 1][x] == TileType.road) hasRoadNeighbor = true;
          if (y < gridSize - 1 && _grid[y + 1][x] == TileType.road) hasRoadNeighbor = true;
          if (x > 0 && _grid[y][x - 1] == TileType.road) hasRoadNeighbor = true;
          if (x < gridSize - 1 && _grid[y][x + 1] == TileType.road) hasRoadNeighbor = true;
          
          if (hasRoadNeighbor) {
            validSpots.add([x, y]);
            // Categorize spots for gas station placement
            if (y < 3) {
              // Top 3 rows - north area
              northSpots.add([x, y]);
            } else if (y >= gridSize - 3) {
              // Bottom 3 rows - south area
              southSpots.add([x, y]);
            } else {
              // Middle area
              otherSpots.add([x, y]);
            }
          }
        }
      }
    }
    
    // Track buildings by type for distance checking (only same-type buildings need spacing)
    final buildingsByType = <TileType, List<List<int>>>{};
    final minDistance = 2.5; // Minimum distance between buildings of the SAME type (in grid units)
    
    // Helper to add a building to the tracking map
    void addBuilding(TileType type, List<int> spot) {
      if (!buildingsByType.containsKey(type)) {
        buildingsByType[type] = [];
      }
      buildingsByType[type]!.add(spot);
    }
    
    // Step B: Place Items (in specific order with strict counts, spread out)
    
    // Warehouse: Exactly 1 (Critical - place first, near center if possible)
    if (validSpots.isNotEmpty) {
      // Prefer center area for warehouse
      final centerSpots = validSpots.where((spot) {
        final centerX = gridSize ~/ 2;
        final centerY = gridSize ~/ 2;
        final dist = _distance(spot[0], spot[1], centerX, centerY);
        return dist < gridSize / 3;
      }).toList();
      
      final spot = centerSpots.isNotEmpty 
          ? centerSpots[random.nextInt(centerSpots.length)]
          : validSpots[random.nextInt(validSpots.length)];
      
      _grid[spot[1]][spot[0]] = TileType.warehouse;
      _warehouseX = spot[0];
      _warehouseY = spot[1];
      _updateWarehouseRoadPosition();
      addBuilding(TileType.warehouse, spot);
      validSpots.remove(spot);
      otherSpots.remove(spot);
      northSpots.remove(spot);
      southSpots.remove(spot);
    }
    
    // Gas Stations: Exactly 2 - Place far north and south, spread out from each other
    if (northSpots.isNotEmpty) {
      final spot = _findSpreadOutSpot(northSpots, buildingsByType, TileType.gasStation, minDistance, random) ?? northSpots[0];
      _grid[spot[1]][spot[0]] = TileType.gasStation;
      addBuilding(TileType.gasStation, spot);
      validSpots.remove(spot);
      otherSpots.remove(spot);
      northSpots.remove(spot);
    }
    if (southSpots.isNotEmpty) {
      final spot = _findSpreadOutSpot(southSpots, buildingsByType, TileType.gasStation, minDistance, random) ?? southSpots[0];
      _grid[spot[1]][spot[0]] = TileType.gasStation;
      addBuilding(TileType.gasStation, spot);
      validSpots.remove(spot);
      otherSpots.remove(spot);
      southSpots.remove(spot);
    }
    
    // Machine Locations: Exactly 4 of EACH type (Shop, Office, School, Gym, Hospital, University, Subway)
    final machineTypes = [
      TileType.shop,
      TileType.office,
      TileType.school,
      TileType.gym,
      TileType.hospital,
      TileType.university,
      TileType.subway,
    ];
    
    // Place 4 of each machine type, spread out from each other (but can be next to different types)
    // Use ALL valid spots (including outer areas) to avoid clustering around loops
    for (final machineType in machineTypes) {
      for (int i = 0; i < 4; i++) {
        // Use all valid spots across the entire map, not just middle area
        final spot = _findSpreadOutSpot(validSpots, buildingsByType, machineType, minDistance, random);
        
        if (spot != null) {
          _grid[spot[1]][spot[0]] = machineType;
          addBuilding(machineType, spot);
          validSpots.remove(spot);
          otherSpots.remove(spot);
          northSpots.remove(spot);
          southSpots.remove(spot);
        }
      }
    }
    
    // Houses: Up to 6, spread out from each other - use all valid spots
    for (int i = 0; i < 6; i++) {
      final spot = _findSpreadOutSpot(validSpots, buildingsByType, TileType.house, minDistance, random);
      
      if (spot != null) {
        _grid[spot[1]][spot[0]] = TileType.house;
        addBuilding(TileType.house, spot);
        validSpots.remove(spot);
        otherSpots.remove(spot);
        northSpots.remove(spot);
        southSpots.remove(spot);
      }
    }
    
    // Parks: Up to 6, spread out from each other - use all valid spots
    for (int i = 0; i < 6; i++) {
      final spot = _findSpreadOutSpot(validSpots, buildingsByType, TileType.park, minDistance, random);
      
      if (spot != null) {
        _grid[spot[1]][spot[0]] = TileType.park;
        addBuilding(TileType.park, spot);
        validSpots.remove(spot);
        otherSpots.remove(spot);
        northSpots.remove(spot);
        southSpots.remove(spot);
      }
    }
    
    // Remaining spots: Leave as Grass (TileType.grass) - already set
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


  








  bool _hasShownGameOver = false; // Track if we've already shown the game over dialog

  @override
  Widget build(BuildContext context) {
    // Watch machines provider to ensure rebuild when machines change
    ref.watch(machinesProvider);

    // Watch game state for game over condition
    final gameState = ref.watch(gameStateProvider);

    // Show game over dialog when game over flag is set
    if (gameState.isGameOver && !_hasShownGameOver) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _hasShownGameOver = true;
        _showGameOverDialog(context);
      });
    }

    final isNight = gameState.hourOfDay < 6 || gameState.hourOfDay >= 20;
    final weather = gameState.weather;

    return Stack(
      children: [
        // Not Positioned: a Stack needs one unpositioned child to size itself,
        // and without it the whole city collapses to nothing.
        // The map and the machine panel share a column, so the panel never sits on top of
        // the map's platform view. Opening it shrinks the map above; closing it grows the map
        // back. A panel laid over the WebView left the map black when it closed.
        Column(
          children: [
            Expanded(child: _build3DCity(isNight)),
            if (_openMachineId != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Center(
                  child: _MachineViewPanel(
                    machineId: _openMachineId!,
                    minimized: _machinePanelMinimized,
                    onToggleMinimized: () =>
                        setState(() => _machinePanelMinimized = !_machinePanelMinimized),
                    onClose: _closeMachineView,
                  ),
                ),
              ),
          ],
        ),

        // Rain overlay (full screen)
        if (weather == WeatherType.rainy || weather == WeatherType.stormy)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: RainPainter(
                  intensity: weather == WeatherType.stormy ? 1.0 : 0.5,
                  time: DateTime.now().millisecondsSinceEpoch.toDouble(),
                ),
              ),
            ),
          ),

        // Tutorial hint: tap a pedestrian to make them buy
        if (_showPedestrianTutorial)
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: IgnorePointer(
              child: VexPanel(
                borderColor: VexColors.gold,
                child: const Text(
                  'Tap pedestrians to make them buy items!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: VexColors.gold, fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),

        // Camera controls on the right
        Positioned(
          right: 10,
          top: 0,
          bottom: 0,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                VexIconButton(icon: Icons.add, tooltip: 'Zoom in', onPressed: () => _mapController.zoomBy(0.75)),
                const SizedBox(height: 6),
                VexIconButton(icon: Icons.remove, tooltip: 'Zoom out', onPressed: () => _mapController.zoomBy(1.35)),
                const SizedBox(height: 6),
                VexIconButton(icon: Icons.center_focus_strong, tooltip: 'Reset view', onPressed: _mapController.reset),
              ],
            ),
          ),
        ),

        // The marketing button keeps its timers here, and the 3D marker shows it.
        if (gameState.marketingButtonGridX != null && gameState.marketingButtonGridY != null)
          Positioned(
            left: 0,
            top: 0,
            child: MarketingButton(
              key: _marketingKey,
              gridX: gameState.marketingButtonGridX!,
              gridY: gameState.marketingButtonGridY!,
              screenPosition: Offset.zero,
              tileWidth: 0,
              tileHeight: 0,
              visible: false,
            ),
          ),
      ],
    );
  }

  /// The 3D lowpoly city. A tap on a building or machine uses the same handler
  /// as the 2D map, so purchases and machine views work the same way.
  Widget _build3DCity(bool isNight) {
    final machines = ref.watch(machinesProvider);
    final brightness = isNight ? cityNightBrightness : 1.0;
    final background = isNight ? cityNightSky : cityDaySky;
    // Encoding the scene is the costly part, so reuse it until the grid, the
    // machines or the lighting change. Grid edits happen only while the map is
    // generated, and that reassigns _grid first.
    final signature = '$brightness|${_machinesSignature(machines)}';
    final mapChanged = !identical(_scene3DGrid, _grid);
    if (_scene3D == null || mapChanged || signature != _scene3DSignature) {
      final scene = buildCityScene(
        grid: _grid,
        roadDirections: _roadDirections,
        machines: machines,
        brightness: brightness,
      );
      _scene3D = jsonEncode(cityScenePayload(
        objects: scene,
        sky: background,
        home: defaultCityCamera(gridSize),
        minDistance: 6,
        maxDistance: 60,
        resetCamera: mapChanged || _scene3DGrid == null,
      ));
      _scene3DGrid = _grid;
      _scene3DSignature = signature;
    }
    final gameState = ref.watch(gameStateProvider);
    final trucks = ref.watch(trucksProvider);
    final marketingX = gameState.marketingButtonGridX;
    final marketingY = gameState.marketingButtonGridY;
    final soups = <LowPolyObject>[
      for (final truck in trucks) buildTruckObject(truck, brightness),
      if (marketingX != null && marketingY != null)
        ...buildMarketingMarker(
          gridX: marketingX,
          gridY: marketingY,
          rushHour: gameState.isRushHour,
          brightness: brightness,
        ),
    ];
    final frame = jsonEncode(cityFrameJson(
      walkers: [
        ..._pedestrianWalkers(brightness),
      ],
      soups: soups,
    ));
    return CityWebView(
      scene: _scene3D!,
      frame: frame,
      controller: _mapController,
      background: background,
      onTap: _onCityTap,
    );
  }

  /// The parts of the machines the city draws: where each stands, what it is, and how
  /// full its slots are. Sales change these, and nothing else on the list matters here.
  String _machinesSignature(List<sim.Machine> machines) {
    final out = StringBuffer();
    for (final machine in machines) {
      out
        ..write(machine.id)
        ..write(machine.zone.type.name)
        ..write(machine.zone.x)
        ..write(machine.zone.y)
        ..write(machine.isBroken ? 'b' : 'w')
        ..write(machine.currentCash > 0 ? 'c' : 'n');
      for (final item in machine.inventory.values) {
        out
          ..write(item.product.name)
          ..write(item.quantity);
      }
      out.write(';');
    }
    return out.toString();
  }

  /// A tap in the city, as the page reports it.
  void _onCityTap(Map<String, Object?> target) {
    switch (target['kind']) {
      case 'cell':
        final x = target['x']! as int;
        final y = target['y']! as int;
        _handleDebouncedBuildingTap(x, y, _grid[y][x]);
      case 'pedestrian':
        final key = target['key']! as String;
        for (final pedestrian in _pedestrians) {
          if ('p${pedestrian.personId}' == key) {
            _handlePedestrianTap(pedestrian);
            return;
          }
        }
      case 'marketing':
        _marketingKey.currentState?.tap();
    }
  }

  /// A machine sells to a walker who reaches the road in front of it. Each machine waits
  /// this long between sales to walkers, so a busy street does not drain it at once.
  static const Duration _customerCooldown = Duration(seconds: 10);

  /// Sells from each machine when a walker stands on the road in front of it.
  void _updateCustomers() {
    final machines = ref.read(machinesProvider);
    final now = DateTime.now();
    for (final machine in machines) {
      final gx = (machine.zone.x - 1).floor();
      final gy = (machine.zone.y - 1).floor();
      final front = frontTile(_grid, gx, gy);
      if (front == null) continue;
      final soldAt = _customerSoldAt[machine.id];
      if (soldAt != null && now.difference(soldAt) < _customerCooldown) continue;
      final walkerHere = _pedestrians.any((p) =>
          !p.isHeadingToShop &&
          (p.gridX + 0.5).floor() == front.$1 &&
          (p.gridY + 0.5).floor() == front.$2);
      if (!walkerHere) continue;
      _customerSoldAt[machine.id] = now;
      sellToCustomer(ref, machine.id, math.Random().nextDouble() < 0.2);
    }
  }

  /// Walkers on the pavement, as frame entries. A tap on one is found by its key.
  List<Map<String, Object?>> _pedestrianWalkers(double brightness) {
    const tutorialShirt = Color(0xFFFFEB3B);
    final now = DateTime.now();
    final walkers = <Map<String, Object?>>[];
    for (final pedestrian in _pedestrians) {
      final cx = pedestrian.gridX + 0.5 + pedestrian.offsetX;
      final cz = pedestrian.gridY + 0.5 + pedestrian.offsetZ;
      final look = personLook(pedestrian.personId);
      // The tutorial walker is yellow, so it is easy to find.
      final isTutorial = pedestrian == _tutorialPedestrian;
      // Walks while moving, and runs once a tap sends them to a machine.
      final running = pedestrian.isHeadingToShop;
      final moving = advanceHumanPose(pedestrian.pose, cx, cz, running, now);
      walkers.add(walkerJson(
        key: 'p${pedestrian.personId}',
        x: cx,
        z: cz,
        yaw: pedestrian.pose.yaw,
        scale: _walkerScale,
        look: PersonLook(
          shirt: isTutorial ? tutorialShirt : look.shirt,
          pants: look.pants,
          skin: look.skin,
          hair: look.hair,
          hat: look.hat,
          bag: look.bag,
        ),
        brightness: brightness,
        bones: humanBoneValues(pedestrian.pose, running, moving),
      ));
    }
    return walkers;
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

  /// Show game over dialog when player goes bankrupt
  void _showGameOverDialog(BuildContext context) {
    final gameState = ref.read(gameStateProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: ScreenUtils.relativeSizeClamped(context, 0.06)),
            SizedBox(width: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall)),
            Expanded(
              child: Text(
                'Game Over',
                style: TextStyle(
                  fontSize: ScreenUtils.relativeFontSize(context, AppConfig.fontSizeFactorLarge),
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade900,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your business went bankrupt!',
              style: TextStyle(
                fontSize: ScreenUtils.relativeFontSize(context, AppConfig.fontSizeFactorNormal),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorMedium)),
            Text(
              'Final Cash: \$${gameState.cash.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: ScreenUtils.relativeFontSize(context, AppConfig.fontSizeFactorNormal),
                color: Colors.red.shade700,
              ),
            ),
            SizedBox(height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorSmall)),
            Text(
              'Day ${gameState.dayCount}',
              style: TextStyle(
                fontSize: ScreenUtils.relativeFontSize(context, AppConfig.fontSizeFactorSmall),
                color: VexColors.muted,
              ),
            ),
            SizedBox(height: ScreenUtils.relativeSize(context, AppConfig.spacingFactorMedium)),
            Text(
              'Try to manage your expenses better next time!',
              style: TextStyle(
                fontSize: ScreenUtils.relativeFontSize(context, AppConfig.fontSizeFactorSmall),
                color: VexColors.muted,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop(); // Go back to menu
            },
            child: Text(
              'Back to Menu',
              style: TextStyle(
                fontSize: ScreenUtils.relativeFontSize(context, AppConfig.fontSizeFactorNormal),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // Reset game
              controller.resetGame();
              _hasShownGameOver = false;
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'New Game',
              style: TextStyle(
                fontSize: ScreenUtils.relativeFontSize(context, AppConfig.fontSizeFactorNormal),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMachineView(sim.Machine machine) {
    // Glide the 3D camera to the machine's tile, so the machine is in front of the
    // building, then open its details beside that view. The overview comes back on close.
    final gx = math.min(math.max((machine.zone.x - 1).floor(), 0), gridSize - 1);
    final gy = math.min(math.max((machine.zone.y - 1).floor(), 0), gridSize - 1);
    // Look at the machine from the road it faces, so the building is behind it, not in
    // the way. Close in on it so the machine fills the view.
    final (ax, az) = machineAnchor(_grid, gx, gy);
    final front = frontTile(_grid, gx, gy);
    final yaw = front == null ? 0.0 : math.atan2((front.$1 - gx).toDouble(), (front.$2 - gy).toDouble());
    // A steep view keeps the camera over the road. A lower one lands the camera inside the
    // building across the road, which blocks the machine.
    _mapController.focusOn(Vec3(ax, 0.3, az), distance: 1.3, pitch: 0.85, yaw: yaw);
    setState(() {
      _openMachineId = machine.id;
      _machinePanelMinimized = true;
    });
  }

  void _closeMachineView() {
    setState(() => _openMachineId = null);
    _mapController.reset();
  }

  void _showMachinePurchaseDialog(BuildContext context, ZoneType zoneType, double zoneX, double zoneY) {
    final price = MachinePrices.getPrice(zoneType);
    
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (dialogContext) => _MachinePurchaseDialog(
        zoneType: zoneType,
        zoneX: zoneX,
        zoneY: zoneY,
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
                _showMachineView(machine);
              } catch (e) {
                // Machine not found yet, just close
              }
            }
          });
        },
      ),
    );
  }


  // --- PEDESTRIAN MANAGEMENT ---
  
  /// Spawn random number (1-10) of pedestrians, one of each personId (max 10 unique pedestrians)
  void _spawnPedestrians() {
    // Find all road tiles that are next to buildings (or any road tiles as fallback)
    final validTiles = _findRoadTilesNextToBuildings();
    
    if (validTiles.isEmpty) {
      print('⚠️ PEDESTRIAN SPAWN: No valid road tiles found for spawning');
      return;
    }
    
    print('✅ PEDESTRIAN SPAWN: Found ${validTiles.length} valid road tiles');
    
    // Spawn random number of pedestrians (1-10, but limited by available unique personIds)
    final numToSpawn = math.min(_pedestrianRandom.nextInt(10) + 1, 10 - _pedestrians.length);
    
    // Get available personIds (0-9) that are not currently spawned (max 1 per personId)
    final availablePersonIds = List.generate(10, (i) => i).where((id) => 
      (_personIdCounts[id] ?? 0) < 1
    ).toList();
    
    // Track occupied grid positions to prevent same personId at same block
    final occupiedPositions = <String>{}; // Format: "x,y"
    
    // Shuffle available personIds for variety
    availablePersonIds.shuffle(_pedestrianRandom);
    
    int spawned = 0;
    int attempts = 0;
    const maxAttempts = 100; // Prevent infinite loop
    
    while (spawned < numToSpawn && attempts < maxAttempts) {
      attempts++;
      
      // Get a personId (only one of each can exist)
      if (availablePersonIds.isEmpty) break;
      final personId = availablePersonIds[_pedestrianRandom.nextInt(availablePersonIds.length)];
      
      // Find a valid tile that's not occupied
      final availableTiles = validTiles.where((tile) {
        final posKey = '${tile.x},${tile.y}';
        // Check if this position is already occupied
        return !occupiedPositions.contains(posKey);
      }).toList();
      
      if (availableTiles.isEmpty) {
        // No available tiles for this personId, try next
        continue;
      }
      
      final validTile = availableTiles[_pedestrianRandom.nextInt(availableTiles.length)];
      final posKey = '${validTile.x},${validTile.y}';
      
      _pedestrians.add(_PedestrianState(
        personId: personId,
        gridX: validTile.x.toDouble(),
        gridY: validTile.y.toDouble(),
        lastTileX: validTile.x,
        lastTileY: validTile.y,
        sameTileCounter: 0,
      ));
      
      // Update count
      _personIdCounts[personId] = (_personIdCounts[personId] ?? 0) + 1;
      
      // Mark position as occupied by this personId
      occupiedPositions.add(posKey);
      
      spawned++;
      
      // Remove personId from available list if we've reached max (1)
      if (_personIdCounts[personId]! >= 1) {
        availablePersonIds.remove(personId);
      }
    }
    
    print('✅ PEDESTRIAN SPAWN: Spawned $spawned pedestrians (total: ${_pedestrians.length})');
  }
  
  /// Spawn a single pedestrian at a random road tile next to a building
  /// Only one of each personId can appear at a time (max 10 unique pedestrians)
  void _spawnSinglePedestrian() {
    // Find all road tiles that are next to buildings
    final validTiles = _findRoadTilesNextToBuildings();
    
    if (validTiles.isEmpty) return;
    
    // Get available personIds that are not currently spawned (max 1 per personId)
    final availablePersonIds = List.generate(10, (i) => i).where((id) => 
      (_personIdCounts[id] ?? 0) < 1
    ).toList();
    
    if (availablePersonIds.isEmpty) return; // All 10 personIds are already spawned
    
    final personId = availablePersonIds[_pedestrianRandom.nextInt(availablePersonIds.length)];
    
    // Find a valid tile that's not occupied by the same personId
    final availableTiles = validTiles.where((tile) {
      // Check if this position is already occupied by the same personId
      return !_pedestrians.any((p) => p.personId == personId && 
                                      p.gridX.floor() == tile.x && 
                                      p.gridY.floor() == tile.y);
    }).toList();
    
    if (availableTiles.isEmpty) return; // No available positions for this personId
    
    final validTile = availableTiles[_pedestrianRandom.nextInt(availableTiles.length)];
    
    _pedestrians.add(_PedestrianState(
      personId: personId,
      gridX: validTile.x.toDouble(),
      gridY: validTile.y.toDouble(),
      lastTileX: validTile.x,
      lastTileY: validTile.y,
      sameTileCounter: 0,
    ));
    
    // Update count
    _personIdCounts[personId] = (_personIdCounts[personId] ?? 0) + 1;
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
    
    // If no road tiles next to buildings, use any road tiles as fallback
    if (spawnTiles.isEmpty) {
      for (int y = 0; y < _grid.length; y++) {
        for (int x = 0; x < _grid[y].length; x++) {
          if (_grid[y][x] == TileType.road) {
            spawnTiles.add((x: x, y: y));
          }
        }
      }
    }
    
    return spawnTiles;
  }
  
  /// Check if tutorial should be shown and select a pedestrian to highlight
  void _checkAndShowTutorial() {
    if (_openMachineId != null) return;
    final machines = ref.read(machinesProvider);
    final gameState = ref.read(gameStateProvider);
    
    // Check if tutorial has been seen before (from game state)
    final hasSeenTutorial = gameState.hasSeenPedestrianTapTutorial;
    
    // Show tutorial if machines exist, tutorial hasn't been dismissed, and user hasn't seen it before
    if (machines.isNotEmpty && _showPedestrianTutorial && _tutorialPedestrian == null && !hasSeenTutorial) {
      // Select the first non-moving pedestrian (not heading to shop) for tutorial
      final availablePedestrians = _pedestrians.where((p) => !p.isHeadingToShop).toList();
      if (availablePedestrians.isNotEmpty) {
        _tutorialPedestrian = availablePedestrians.first;
        setState(() {});
      }
    } else if (machines.isEmpty || hasSeenTutorial) {
      // Hide tutorial if no machines or if already seen
      _showPedestrianTutorial = false;
      _tutorialPedestrian = null;
      setState(() {});
    }
  }
  
  /// Update pedestrian positions and find new targets
  /// How far a walker's offset may move per update. Walkers cover 0.01 tiles per update,
  /// so this lets them slide across the road in about a second.
  static const double _maxOffsetStep = 0.02;
  static const double _walkOffset = 0.4;

  /// Eases a walker's offset toward the pavement they walk on: the right of their
  /// heading, or the left when the right has no pavement at that spot.
  void _easeWalkerOffset(_PedestrianState pedestrian) {
    final heading = pedestrian.pose.yaw;
    final rightX = -math.cos(heading);
    final rightZ = math.sin(heading);
    final centreX = pedestrian.gridX + 0.5;
    final centreZ = pedestrian.gridY + 0.5;
    final tileX = centreX.floor();
    final tileY = centreZ.floor();
    if (pedestrian.walkSide == 0 || pedestrian.sideTileX != tileX || pedestrian.sideTileY != tileY) {
      // Keep the current side while it is pavement, else take the other side if that is
      // pavement. A new walker starts on the right of their heading.
      var side = pedestrian.walkSide == 0 ? 1 : pedestrian.walkSide;
      bool onPavement(int s) => isPavementAt(
            _grid,
            centreX + rightX * _walkOffset * s,
            centreZ + rightZ * _walkOffset * s,
          );
      if (!onPavement(side) && onPavement(-side)) side = -side;
      pedestrian.walkSide = side;
      pedestrian.sideTileX = tileX;
      pedestrian.sideTileY = tileY;
    }
    final side = pedestrian.walkSide;
    // Going in, a walker moves onto the centre line, so they walk straight into the building.
    final going = pedestrian.enterX != null;
    final targetX = going ? 0.0 : rightX * _walkOffset * side;
    final targetZ = going ? 0.0 : rightZ * _walkOffset * side;
    // A new walker starts on the pavement, rather than sliding in from the tile centre.
    if (pedestrian.offsetX == 0 && pedestrian.offsetZ == 0) {
      pedestrian.offsetX = targetX;
      pedestrian.offsetZ = targetZ;
      return;
    }
    final dx = targetX - pedestrian.offsetX;
    final dz = targetZ - pedestrian.offsetZ;
    final dist = math.sqrt(dx * dx + dz * dz);
    if (dist <= _maxOffsetStep) {
      pedestrian.offsetX = targetX;
      pedestrian.offsetZ = targetZ;
    } else {
      pedestrian.offsetX += dx / dist * _maxOffsetStep;
      pedestrian.offsetZ += dz / dist * _maxOffsetStep;
    }
  }

  /// Sends a walker into the building of [machine], where they then disappear.
  void _startEntering(_PedestrianState pedestrian, {required String? machine}) {
    final found = ref.read(machinesProvider).where((m) => m.id == machine);
    if (found.isEmpty) return;
    pedestrian
      ..enterX = (found.first.zone.x - 1).floor()
      ..enterY = (found.first.zone.y - 1).floor();
  }

  /// Picks a new neighbouring road tile for a walker who has been standing still. On the
  /// map's edge, a walker may instead walk off the map.
  void _rerouteWalker(_PedestrianState pedestrian) {
    final x = pedestrian.gridX.floor();
    final y = pedestrian.gridY.floor();
    final last = gridSize - 1;
    final onEdge = x == 0 || y == 0 || x == last || y == last;
    if (onEdge && _pedestrianRandom.nextDouble() < 0.5) {
      pedestrian
        ..enterX = x == 0 ? -1 : (x == last ? gridSize : x)
        ..enterY = y == 0 ? -1 : (y == last ? gridSize : y);
      return;
    }
    final options = _getAdjacentValidTilesForPedestrian(x, y);
    if (options.isEmpty) return;
    final next = options[_pedestrianRandom.nextInt(options.length)];
    pedestrian
      ..targetGridX = next.x.toDouble()
      ..targetGridY = next.y.toDouble();
  }

  void _updatePedestrians() {
    _updateCustomers();
    for (final pedestrian in _pedestrians) {
      _easeWalkerOffset(pedestrian);
    }
    const double normalSpeed = 0.01; // Grid units per update (50ms = 0.2 grid units per second) - slower
    const double fastSpeed = 0.03; // Faster speed when heading to shop (3x normal speed)
    const double arrivalThreshold = 0.1;
    
    // Check if tutorial should be shown
    final machines = ref.read(machinesProvider);
    final gameState = ref.read(gameStateProvider);
    // The tutorial waits for the machine panel to close, so it appears on the map.
    if (machines.isNotEmpty && !_showPedestrianTutorial && !gameState.hasSeenPedestrianTapTutorial &&
        _openMachineId == null) {
      _showPedestrianTutorial = true;
      _checkAndShowTutorial();
    }
    
    // Track pedestrians to remove after forced sale
    final pedestriansToRemove = <_PedestrianState>[];
    
    for (final pedestrian in _pedestrians) {
      // Clamp position to stay within map bounds
      final enterX = pedestrian.enterX;
      final enterY = pedestrian.enterY;
      if (enterX != null && enterY != null) {
        final dx = enterX - pedestrian.gridX;
        final dy = enterY - pedestrian.gridY;
        final distance = math.sqrt(dx * dx + dy * dy);
        if (distance < 0.12) {
          pedestriansToRemove.add(pedestrian);
        } else {
          pedestrian.gridX += dx / distance * fastSpeed * 0.6;
          pedestrian.gridY += dy / distance * fastSpeed * 0.6;
        }
        continue;
      }
      final previousX = pedestrian.gridX;
      final previousY = pedestrian.gridY;
      pedestrian.gridX = pedestrian.gridX.clamp(0.0, (gridSize - 1).toDouble());
      pedestrian.gridY = pedestrian.gridY.clamp(0.0, (gridSize - 1).toDouble());
      
      // Check if pedestrian is stuck in the same tile for too long
      final currentTileX = pedestrian.gridX.floor();
      final currentTileY = pedestrian.gridY.floor();
      
      if (pedestrian.lastTileX == currentTileX && pedestrian.lastTileY == currentTileY) {
        // Still in the same tile, increment counter
        pedestrian.sameTileCounter++;
        
        // Stuck on one tile for 7.5 seconds: pick a new way to go. Walkers are not removed
        // here, since a walker that vanishes on the street reads as a bug.
        if (pedestrian.sameTileCounter > 150 && !pedestrian.isHeadingToShop) {
          pedestrian.sameTileCounter = 0;
          _rerouteWalker(pedestrian);
        }
      } else {
        // Moved to a different tile, reset counter and update last tile
        pedestrian.lastTileX = currentTileX;
        pedestrian.lastTileY = currentTileY;
        pedestrian.sameTileCounter = 0;
      }
      
      // Check if pedestrian is heading to shop (forced by tap)
      if (pedestrian.isHeadingToShop && pedestrian.targetMachineId != null) {
        // When heading to shop, only recalculate target if we've reached the current one
        // This prevents jumping back when tapped
        if (pedestrian.targetGridX != null && pedestrian.targetGridY != null) {
          // Check if we've reached the current target
          final dx = pedestrian.targetGridX! - pedestrian.gridX;
          final dy = pedestrian.targetGridY! - pedestrian.gridY;
          final distanceToTarget = math.sqrt(dx * dx + dy * dy);
          
          if (distanceToTarget < arrivalThreshold) {
            // We've reached the current intermediate target, find next one toward final destination
            final targetRoadX = pedestrian.targetGridX!.floor();
            final targetRoadY = pedestrian.targetGridY!.floor();
            
            // Find adjacent road tiles that move us closer to the final target
            final currentX = pedestrian.gridX.floor();
            final currentY = pedestrian.gridY.floor();
            final adjacentRoads = _getAdjacentValidTilesForPedestrian(currentX, currentY);
            
            if (adjacentRoads.isNotEmpty) {
              // Choose the road tile that's closest to the final target
              double minDist = double.infinity;
              ({int x, int y})? bestTile;
              
              for (final roadTile in adjacentRoads) {
                final dx2 = targetRoadX - roadTile.x;
                final dy2 = targetRoadY - roadTile.y;
                final dist = math.sqrt(dx2 * dx2 + dy2 * dy2);
                
                if (dist < minDist) {
                  minDist = dist;
                  bestTile = roadTile;
                }
              }
              
              if (bestTile != null) {
                pedestrian.targetGridX = bestTile.x.toDouble();
                pedestrian.targetGridY = bestTile.y.toDouble();
              }
            }
          }
          // If we haven't reached the target yet, keep moving toward it (don't recalculate)
        }
      } else {
        // Normal wandering logic - check if we need a new target
      if (pedestrian.targetGridX == null || pedestrian.targetGridY == null ||
          ((pedestrian.gridX - pedestrian.targetGridX!).abs() < arrivalThreshold &&
           (pedestrian.gridY - pedestrian.targetGridY!).abs() < arrivalThreshold)) {
        
        // Save current position as previous before moving
        pedestrian.previousGridX = pedestrian.gridX;
        pedestrian.previousGridY = pedestrian.gridY;
        
        // Find adjacent valid tiles (road tiles only)
        final adjacentTiles = _getAdjacentValidTilesForPedestrian(
          pedestrian.gridX.floor(),
          pedestrian.gridY.floor(),
        );
        
        // Filter out the previous position to avoid going back and forth
        // But if it's the only option, allow it (prevents getting stuck)
        final availableTiles = adjacentTiles.where((tile) {
          if (pedestrian.previousGridX != null && pedestrian.previousGridY != null) {
            final prevX = pedestrian.previousGridX!.floor();
            final prevY = pedestrian.previousGridY!.floor();
            // Don't go back to the previous tile unless it's the only option
            return !(tile.x == prevX && tile.y == prevY);
          }
          return true;
        }).toList();
        
        if (availableTiles.isNotEmpty) {
          final random = math.Random();
          final target = availableTiles[random.nextInt(availableTiles.length)];
          pedestrian.targetGridX = target.x.toDouble();
          pedestrian.targetGridY = target.y.toDouble();
        } else if (adjacentTiles.isNotEmpty) {
          // If all adjacent tiles are the previous one, clear previous position and allow going back
          // This prevents getting stuck in a dead-end
          pedestrian.previousGridX = null;
          pedestrian.previousGridY = null;
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
            // Clear previous position when using nearby tile to prevent getting stuck
            pedestrian.previousGridX = null;
            pedestrian.previousGridY = null;
            pedestrian.targetGridX = nearbyTile.x.toDouble();
            pedestrian.targetGridY = nearbyTile.y.toDouble();
          } else {
            // Last resort: clear target and previous to allow fresh start
            pedestrian.targetGridX = null;
            pedestrian.targetGridY = null;
            pedestrian.previousGridX = null;
            pedestrian.previousGridY = null;
          }
        }
        }
      }
      
      // Move towards target
      if (pedestrian.targetGridX != null && pedestrian.targetGridY != null) {
        // If heading to shop and has a path, follow the path
        if (pedestrian.isHeadingToShop && pedestrian.path.isNotEmpty) {
          // Use faster speed when heading to shop
          final speed = fastSpeed;
          
          // Follow path waypoints
          while (pedestrian.pathIndex < pedestrian.path.length) {
            final waypoint = pedestrian.path[pedestrian.pathIndex];
            final waypointX = waypoint.x.toDouble();
            final waypointY = waypoint.y.toDouble();
            
            final dx = waypointX - pedestrian.gridX;
            final dy = waypointY - pedestrian.gridY;
            final distance = math.sqrt(dx * dx + dy * dy);
            
            if (distance < arrivalThreshold) {
              // Reached waypoint, move to next
              pedestrian.gridX = waypointX;
              pedestrian.gridY = waypointY;
              pedestrian.pathIndex++;
            } else {
              // Move toward waypoint
              final normalizedDx = dx / distance;
              final normalizedDy = dy / distance;
              pedestrian.gridX += normalizedDx * speed;
              pedestrian.gridY += normalizedDy * speed;
              break;
            }
          }
          
          // If reached end of path, trigger sale and disappear on the road tile
          if (pedestrian.pathIndex >= pedestrian.path.length) {
            // Only set position to end waypoint once when we first reach it
            if (pedestrian.pathIndex == pedestrian.path.length && pedestrian.path.isNotEmpty) {
              final endWaypoint = pedestrian.path.last;
              pedestrian.gridX = endWaypoint.x.toDouble();
              pedestrian.gridY = endWaypoint.y.toDouble();
              pedestrian.pathIndex++; // Mark that we've processed the end waypoint
              
              // Trigger sale immediately when reaching the road tile next to building
              if (pedestrian.targetMachineId != null) {
                final controller = ref.read(gameControllerProvider.notifier);
                final success = controller.simulationEngine.forceSale(pedestrian.targetMachineId!);
                
                if (success) {
                  // Show visual feedback
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sale Forced!'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
                
                // Mark pedestrian for removal - they disappear on the road tile next to building
                _startEntering(pedestrian, machine: pedestrian.targetMachineId);
              }
            }
          }
        } else if (pedestrian.isHeadingToShop && pedestrian.path.isEmpty) {
          // Fallback: if path is empty but heading to shop, find nearest road tile to building
          if (pedestrian.targetMachineId != null) {
            final machines = ref.read(machinesProvider);
            final machine = machines.firstWhere(
              (m) => m.id == pedestrian.targetMachineId,
              orElse: () => machines.first,
            );
            
            final machineGridX = machine.zone.x - 1.0;
            final machineGridY = machine.zone.y - 1.0;
            
            // Find the road tile next to the building
            final nearestRoadTile = _findClosestRoadTileToBuilding(machineGridX.floor(), machineGridY.floor());
            
            if (nearestRoadTile != null) {
              final roadX = nearestRoadTile.x.toDouble();
              final roadY = nearestRoadTile.y.toDouble();
              
              final dx = roadX - pedestrian.gridX;
              final dy = roadY - pedestrian.gridY;
              final distance = math.sqrt(dx * dx + dy * dy);
              
              if (distance < arrivalThreshold) {
                // Reached road tile next to building - trigger sale and disappear
                pedestrian.gridX = roadX;
                pedestrian.gridY = roadY;
                
                final controller = ref.read(gameControllerProvider.notifier);
                final success = controller.simulationEngine.forceSale(pedestrian.targetMachineId!);
                
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sale Forced!'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
                
                _startEntering(pedestrian, machine: pedestrian.targetMachineId);
              } else {
                // Move towards the road tile next to building
                final normalizedDx = dx / distance;
                final normalizedDy = dy / distance;
                pedestrian.gridX += normalizedDx * fastSpeed;
                pedestrian.gridY += normalizedDy * fastSpeed;
              }
            }
          }
        } else {
          // Normal movement (no path or not heading to shop)
          final targetX = pedestrian.targetGridX!.clamp(0.0, (gridSize - 1).toDouble());
          final targetY = pedestrian.targetGridY!.clamp(0.0, (gridSize - 1).toDouble());
          
          // Check if pedestrian is currently on a road tile
          final currentGridX = pedestrian.gridX.floor();
          final currentGridY = pedestrian.gridY.floor();
          final isOnRoad = currentGridY >= 0 && currentGridY < _grid.length &&
                          currentGridX >= 0 && currentGridX < _grid[currentGridY].length &&
                          _grid[currentGridY][currentGridX] == TileType.road;
          
          // If not on a road tile, find a nearby road tile (but don't teleport aggressively)
          if (!isOnRoad) {
            // Only teleport if we've been off-road for a while (stuck counter > 100)
            if (pedestrian.stuckCounter > 100) {
              final nearbyTile = _findNearbyValidTileForPedestrian(currentGridX, currentGridY);
              if (nearbyTile != null) {
                pedestrian.gridX = nearbyTile.x.toDouble();
                pedestrian.gridY = nearbyTile.y.toDouble();
                pedestrian.targetGridX = null;
                pedestrian.targetGridY = null;
                pedestrian.previousGridX = null;
                pedestrian.previousGridY = null;
                pedestrian.stuckCounter = 0;
              } else {
                // Last resort: find any road tile
                final anyRoadTile = _findAnyRoadTile();
                if (anyRoadTile != null) {
                  pedestrian.gridX = anyRoadTile.x.toDouble();
                  pedestrian.gridY = anyRoadTile.y.toDouble();
                  pedestrian.targetGridX = null;
                  pedestrian.targetGridY = null;
                  pedestrian.previousGridX = null;
                  pedestrian.previousGridY = null;
                  pedestrian.stuckCounter = 0;
                }
              }
            } else {
              // Increment stuck counter when off-road
              pedestrian.stuckCounter++;
            }
          } else {
            // Reset stuck counter when on road
            if (pedestrian.stuckCounter > 0) {
              pedestrian.stuckCounter = 0;
            }
          }
          
          // Only proceed with normal movement if on road
          if (isOnRoad) {
            // Pedestrian is on a road tile, proceed with normal movement
            final dx = targetX - pedestrian.gridX;
            final dy = targetY - pedestrian.gridY;
            final distance = math.sqrt(dx * dx + dy * dy);
            
            if (distance > arrivalThreshold) {
              final normalizedDx = dx / distance;
              final normalizedDy = dy / distance;
              
              final speed = normalSpeed;
              var newX = pedestrian.gridX + normalizedDx * speed;
              var newY = pedestrian.gridY + normalizedDy * speed;
              
              // Only move on road tiles
              final newGridX = newX.floor();
              final newGridY = newY.floor();
              
              if (newGridY >= 0 && newGridY < _grid.length &&
                  newGridX >= 0 && newGridX < _grid[newGridY].length &&
                  _grid[newGridY][newGridX] == TileType.road) {
                pedestrian.gridX = newX;
                pedestrian.gridY = newY;
              } else {
                // If not a road tile, reset target to find a new one
                pedestrian.targetGridX = null;
                pedestrian.targetGridY = null;
              }
            } else {
              // Arrived at target for normal wandering
              pedestrian.gridX = targetX;
              pedestrian.gridY = targetY;
              pedestrian.targetGridX = null;
              pedestrian.targetGridY = null;
            }
          }
        }
          
          // Clamp position after movement to stay within bounds
          final finalX = pedestrian.gridX.clamp(0.0, (gridSize - 1).toDouble());
          final finalY = pedestrian.gridY.clamp(0.0, (gridSize - 1).toDouble());
          
          // Check if pedestrian actually moved (for stuck detection)
          final movedDistance = math.sqrt(
            (finalX - previousX) * (finalX - previousX) +
            (finalY - previousY) * (finalY - previousY)
          );
          
          // Only check stuck if pedestrian has a target and is trying to move
          // Only increment stuck counter if pedestrian is on a road tile but not moving
          if (pedestrian.targetGridX != null && pedestrian.targetGridY != null) {
            final currentGridX = finalX.floor();
            final currentGridY = finalY.floor();
            final isOnRoad = currentGridY >= 0 && currentGridY < _grid.length &&
                            currentGridX >= 0 && currentGridX < _grid[currentGridY].length &&
                            _grid[currentGridY][currentGridX] == TileType.road;
            
            if (isOnRoad && movedDistance < 0.1) {
              // Pedestrian is on road but hasn't moved much, increment stuck counter
              pedestrian.stuckCounter++;
            } else if (movedDistance >= 0.1) {
              // Pedestrian moved significantly, reset stuck counter
              pedestrian.stuckCounter = 0;
            }
            
            // If stuck for more than 200 frames (10 seconds at 50ms updates), use recovery mechanism
            // Only for normal wandering, not when heading to shop
            if (pedestrian.stuckCounter > 200 && !pedestrian.isHeadingToShop && isOnRoad) {
              // Find any nearby road tile and teleport there
              final nearbyTile = _findNearbyValidTileForPedestrian(currentGridX, currentGridY);
              if (nearbyTile != null && (nearbyTile.x != currentGridX || nearbyTile.y != currentGridY)) {
                // Only teleport if the nearby tile is different from current position
                pedestrian.gridX = nearbyTile.x.toDouble();
                pedestrian.gridY = nearbyTile.y.toDouble();
                pedestrian.targetGridX = null;
                pedestrian.targetGridY = null;
                pedestrian.previousGridX = null;
                pedestrian.previousGridY = null;
                pedestrian.stuckCounter = 0;
              }
            }
          } else {
            // No target, reset stuck counter
            pedestrian.stuckCounter = 0;
          }
          
          pedestrian.gridX = finalX;
          pedestrian.gridY = finalY;
          pedestrian.stepsWalked++; // Increment step counter
        
        // Calculate movement direction for animation
        double dirDx = 0.0;
        double dirDy = 0.0;
        
        if (pedestrian.isHeadingToShop && pedestrian.path.isNotEmpty && pedestrian.pathIndex < pedestrian.path.length) {
          // Calculate direction from current position to next waypoint
          final waypoint = pedestrian.path[pedestrian.pathIndex];
          dirDx = waypoint.x.toDouble() - pedestrian.gridX;
          dirDy = waypoint.y.toDouble() - pedestrian.gridY;
        } else if (pedestrian.targetGridX != null && pedestrian.targetGridY != null) {
          // Calculate direction from current position to target
          dirDx = pedestrian.targetGridX! - pedestrian.gridX;
          dirDy = pedestrian.targetGridY! - pedestrian.gridY;
        }
          
          // Update direction and flip based on movement
          // Upper right (dy < 0, dx > 0): walk_back flipped
          // Upper left (dy < 0, dx < 0): walk_back original
          // Down right (dy > 0, dx > 0): walk_front original
          // Down left (dy > 0, dx < 0): walk_front flipped

        if (dirDx.abs() > 0.001 || dirDy.abs() > 0.001) {
          if (dirDy.abs() > dirDx.abs()) {
            // Moving primarily vertical on grid
            if (dirDy < 0) {
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
            if (dirDx < 0) {
              // Moving Left (Grid X-) -> Visual Upper Left
              pedestrian.direction = 'front';
              pedestrian.flipHorizontal = true;
            } else {
              // Moving Right (Grid X+) -> Visual Down Right
              pedestrian.direction = 'front';
              pedestrian.flipHorizontal = false;
            }
          }
        }
      }
    }
    
    // Remove pedestrians that completed forced sales
    for (final pedestrian in pedestriansToRemove) {
      _pedestrians.remove(pedestrian);
      // Decrement personId count
      final count = _personIdCounts[pedestrian.personId] ?? 0;
      if (count > 0) {
        _personIdCounts[pedestrian.personId] = count - 1;
      }
    }
    
    // Spawn new pedestrians after removal (if we have available personIds and slots)
    // Increased spawn rate to ensure pedestrians appear, especially after force sales
    if (_pedestrians.length < 10) {
      // Higher spawn rate if we have fewer pedestrians (more aggressive spawning)
      final spawnChance = _pedestrians.length < 3 ? 0.05 : 0.02; // 5% if < 3, 2% otherwise
      if (_pedestrianRandom.nextDouble() < spawnChance) {
        _spawnSinglePedestrian();
        // Check tutorial after spawning
        final gameState = ref.read(gameStateProvider);
        if (machines.isNotEmpty && _showPedestrianTutorial && _tutorialPedestrian == null && !gameState.hasSeenPedestrianTapTutorial) {
          _checkAndShowTutorial();
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
  
  /// Find any road tile on the map (last resort for stuck pedestrians)
  ({int x, int y})? _findAnyRoadTile() {
    // Search in a random order to avoid always teleporting to the same place
    final random = math.Random();
    final positions = <({int x, int y})>[];
    
    for (int y = 0; y < _grid.length; y++) {
      for (int x = 0; x < _grid[y].length; x++) {
        if (_isValidTileForPedestrian(_grid[y][x])) {
          positions.add((x: x, y: y));
        }
      }
    }
    
    if (positions.isEmpty) return null;
    
    // Return a random road tile
    positions.shuffle(random);
    return positions.first;
  }
  

  /// Handle pedestrian tap - force pedestrian to walk to nearest machine and buy
  void _handlePedestrianTap(_PedestrianState pedestrian) {
    // Dismiss tutorial when any pedestrian is tapped and mark as seen
    if (_showPedestrianTutorial) {
      _showPedestrianTutorial = false;
      _tutorialPedestrian = null;
      // Mark tutorial as seen in game state
      final controller = ref.read(gameControllerProvider.notifier);
      final currentState = controller.state;
      controller.state = currentState.copyWith(hasSeenPedestrianTapTutorial: true);
      setState(() {});
    }
    
    final machines = ref.read(machinesProvider);
    
    if (machines.isEmpty) {
      return; // No machines available
    }

    // Calculate distances to all user-owned machines
    double minDistance = double.infinity;
    sim.Machine? nearestMachine;
    
    for (final machine in machines) {
      // Convert machine zone coordinates to grid coordinates (zone is 1-based, grid is 0-based)
      final machineGridX = machine.zone.x - 1.0;
      final machineGridY = machine.zone.y - 1.0;
      
      // Calculate distance
      final dx = machineGridX - pedestrian.gridX;
      final dy = machineGridY - pedestrian.gridY;
      final distance = math.sqrt(dx * dx + dy * dy);
      
      if (distance < minDistance) {
        minDistance = distance;
        nearestMachine = machine;
      }
    }

    if (nearestMachine == null) {
      return; // No machine found
    }

    // Find nearest road tile to the machine (pedestrians must walk on sidewalks/roads)
    // Prioritize road tiles that are adjacent to the building for closer approach
    final machineGridX = nearestMachine.zone.x - 1.0;
    final machineGridY = nearestMachine.zone.y - 1.0;
    final nearestRoadTile = _findClosestRoadTileToBuilding(machineGridX.floor(), machineGridY.floor());
    
    if (nearestRoadTile == null) {
      return; // No road tile found near machine
    }

    // Set pedestrian to head to the nearest road tile to the machine
    pedestrian.isHeadingToShop = true;
    pedestrian.targetMachineId = nearestMachine.id;
    pedestrian.targetGridX = nearestRoadTile.x.toDouble();
    pedestrian.targetGridY = nearestRoadTile.y.toDouble();
    // Start jump animation (lasts for 5 steps)
    pedestrian.jumpStartStep = pedestrian.stepsWalked;
    
    // Calculate path using A* pathfinding through road tiles
    final startX = pedestrian.gridX.floor();
    final startY = pedestrian.gridY.floor();
    final endX = nearestRoadTile.x;
    final endY = nearestRoadTile.y;
    pedestrian.path = _findPathForPedestrian(startX, startY, endX, endY);
    pedestrian.pathIndex = 0;
  }

  /// Find the nearest road tile to a given grid position
  ({int x, int y})? _findNearestRoadTile(int gridX, int gridY) {
    // Search in expanding radius for nearest road tile
    for (int radius = 0; radius <= 5; radius++) {
      for (int dy = -radius; dy <= radius; dy++) {
        for (int dx = -radius; dx <= radius; dx++) {
          if (dx.abs() == radius || dy.abs() == radius || (radius == 0 && dx == 0 && dy == 0)) {
            final checkX = gridX + dx;
            final checkY = gridY + dy;
            
            if (checkY >= 0 && checkY < _grid.length &&
                checkX >= 0 && checkX < _grid[checkY].length &&
                _grid[checkY][checkX] == TileType.road) {
              return (x: checkX, y: checkY);
            }
          }
        }
      }
    }
    return null;
  }

  /// Find the closest road tile to a building, prioritizing tiles adjacent to the building
  ({int x, int y})? _findClosestRoadTileToBuilding(int buildingGridX, int buildingGridY) {
    // First, check if there's a road tile directly adjacent to the building (closest)
    final adjacentDirections = [
      (x: buildingGridX, y: buildingGridY - 1), // Up
      (x: buildingGridX, y: buildingGridY + 1), // Down
      (x: buildingGridX - 1, y: buildingGridY), // Left
      (x: buildingGridX + 1, y: buildingGridY), // Right
    ];
    
    // Check adjacent tiles first (these are closest to the building)
    for (final dir in adjacentDirections) {
      if (dir.y >= 0 && dir.y < _grid.length &&
          dir.x >= 0 && dir.x < _grid[dir.y].length &&
          _grid[dir.y][dir.x] == TileType.road) {
        return (x: dir.x, y: dir.y);
      }
    }
    
    // If no adjacent road tile, find the nearest one (fallback to original method)
    return _findNearestRoadTile(buildingGridX, buildingGridY);
  }

  /// A* pathfinding for pedestrians through road tiles
  List<({int x, int y})> _findPathForPedestrian(int startX, int startY, int endX, int endY) {
    final start = (x: startX, y: startY);
    final end = (x: endX, y: endY);
    
    // Build graph of road tiles (only adjacent road tiles are connected)
    final graph = <({int x, int y}), List<({int x, int y})>>{};
    
    // Find all road tiles and build connections
    for (int y = 0; y < _grid.length; y++) {
      for (int x = 0; x < _grid[y].length; x++) {
        if (_grid[y][x] == TileType.road) {
          final node = (x: x, y: y);
          final neighbors = <({int x, int y})>[];
          
          // Check 4 adjacent directions
          if (y > 0 && _grid[y - 1][x] == TileType.road) {
            neighbors.add((x: x, y: y - 1));
          }
          if (y < _grid.length - 1 && _grid[y + 1][x] == TileType.road) {
            neighbors.add((x: x, y: y + 1));
          }
          if (x > 0 && _grid[y][x - 1] == TileType.road) {
            neighbors.add((x: x - 1, y: y));
          }
          if (x < _grid[y].length - 1 && _grid[y][x + 1] == TileType.road) {
            neighbors.add((x: x + 1, y: y));
          }
          
          graph[node] = neighbors;
        }
      }
    }
    
    // A* pathfinding
    final openSet = <({int x, int y})>{start};
    final cameFrom = <({int x, int y}), ({int x, int y})>{};
    final gScore = <({int x, int y}), double>{start: 0.0};
    final fScore = <({int x, int y}), double>{start: _heuristic(start, end)};
    
    while (openSet.isNotEmpty) {
      ({int x, int y})? current;
      double lowestF = double.infinity;
      for (final node in openSet) {
        final f = fScore[node] ?? double.infinity;
        if (f < lowestF) {
          lowestF = f;
          current = node;
        }
      }
      
      if (current == null) break;
      
      // Check if we reached the goal
      if (current.x == end.x && current.y == end.y) {
        // Reconstruct path
        final path = <({int x, int y})>[end];
        var node = current;
        while (cameFrom.containsKey(node)) {
          node = cameFrom[node]!;
          if (node.x == start.x && node.y == start.y) break;
          path.insert(0, node);
        }
        return path;
      }
      
      openSet.remove(current);
      final neighbors = graph[current] ?? [];
      
      for (final neighbor in neighbors) {
        final edgeCost = 1.0; // All edges have cost 1 (Manhattan distance)
        final tentativeG = (gScore[current] ?? double.infinity) + edgeCost;
        
        if (tentativeG < (gScore[neighbor] ?? double.infinity)) {
          cameFrom[neighbor] = current;
          gScore[neighbor] = tentativeG;
          fScore[neighbor] = tentativeG + _heuristic(neighbor, end);
          if (!openSet.contains(neighbor)) {
            openSet.add(neighbor);
          }
        }
      }
    }
    
    // No path found, return direct path
    return [end];
  }

  /// Heuristic function for A* (Manhattan distance)
  double _heuristic(({int x, int y}) a, ({int x, int y}) b) {
    return ((a.x - b.x).abs() + (a.y - b.y).abs()).toDouble();
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
        // Machine exists - tapping the building itself always opens the
        // status popup. Quick cash collection lives on the floating money
        // icon rendered above the machine instead (see _buildGameMachine),
        // so the building tap stays predictable regardless of cash state.
        if (context.mounted) {
          _showMachineView(existingMachine);
        }
      } else {
        // Machine doesn't exist - show purchase dialog. Purchases are gated
        // by cash alone (checked in the dialog itself) - buy as many
        // machines as the map has building tiles for, as long as you can
        // afford them.
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


}

/// Sells a customer's bundle from a machine: one soda and one chips, or two of each when
/// [isSpecial]. Used by customers walking past the machine.
void sellToCustomer(WidgetRef ref, String machineId, bool isSpecial) {
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


/// Details of one machine, shown as a panel over the map. Minimized, it shows only its
/// header, so the zoomed-in machine stays in view.
class _MachineViewPanel extends ConsumerWidget {
  final String machineId;
  final bool minimized;
  final VoidCallback onToggleMinimized;
  final VoidCallback onClose;

  const _MachineViewPanel({
    required this.machineId,
    required this.minimized,
    required this.onToggleMinimized,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final machines = ref.watch(machinesProvider);
    final matches = machines.where((m) => m.id == machineId);
    if (matches.isEmpty) return const SizedBox.shrink();
    final machine = matches.first;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final panelMaxWidth = screenWidth * AppConfig.machineStatusDialogWidthFactor;
    final padding = panelMaxWidth * AppConfig.machineStatusDialogPaddingFactor;

    return Container(
      constraints: BoxConstraints(
        maxWidth: panelMaxWidth,
        // Open, the panel takes at most part of the screen, so the map stays visible above it.
        maxHeight: minimized ? double.infinity : screenHeight * 0.42,
      ),
      decoration: BoxDecoration(
        color: VexColors.panel,
        borderRadius: BorderRadius.circular(panelMaxWidth * AppConfig.machineStatusDialogBorderRadiusFactor),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 12)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MachineHeader(
            machine: machine,
            padding: padding,
            minimized: minimized,
            onToggleMinimized: onToggleMinimized,
            onClose: onClose,
          ),
          if (!minimized)
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(padding),
                  child: _MachineStatusSection(machine: machine, dialogWidth: panelMaxWidth, onClose: onClose),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MachineStatusSection extends ConsumerWidget {
  final sim.Machine machine;
  final double dialogWidth;
  final VoidCallback? onClose;

  const _MachineStatusSection({
    required this.machine,
    required this.dialogWidth,
    this.onClose,
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
                color: VexColors.muted,
              ),
            ),
            SizedBox(
              height: dialogWidth * AppConfig.machineStatusDialogStockProgressSpacingFactor,
            ),
            LinearProgressIndicator(
              value: stockLevel,
              backgroundColor: VexColors.line,
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
                      color: VexColors.muted,
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
        // Show all allowed products for this zone type, not just those in inventory
        ...Zone.getAllowedProducts(machine.zone.type).map((product) {
          // Get existing inventory item or create a dummy one
          final currentDay = ref.watch(dayCountProvider);
          final item = machine.inventory[product] ?? sim.InventoryItem(
            product: product,
            quantity: 0,
            dayAdded: currentDay,
            allocation: 0,
          );
          
          return Padding(
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
                          SizedBox(height: dialogWidth * AppConfig.machineStatusDialogStockItemPaddingFactor * 0.3),
                          Text(
                            'Stock: ${item.quantity} / ${item.allocation}',
                            style: TextStyle(
                              fontSize: dialogWidth * AppConfig.machineStatusDialogStockItemFontSizeFactor * 0.85,
                              color: VexColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Allocation controls
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.remove, size: dialogWidth * 0.04),
                          onPressed: () {
                            if (item.allocation > 0) {
                              final controller = ref.read(gameControllerProvider.notifier);
                              controller.updateMachineAllocation(machine.id, product, item.allocation - 1);
                            }
                          },
                          padding: EdgeInsets.all(dialogWidth * 0.01),
                          constraints: BoxConstraints(),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: dialogWidth * AppConfig.machineStatusDialogStockItemBadgePaddingHorizontalFactor,
                        vertical: dialogWidth * AppConfig.machineStatusDialogStockItemBadgePaddingVerticalFactor,
                      ),
                      decoration: BoxDecoration(
                        color: VexColors.panelSoft,
                        borderRadius: BorderRadius.circular(
                          dialogWidth * AppConfig.machineStatusDialogStockItemBadgeBorderRadiusFactor,
                        ),
                      ),
                      child: Text(
                            '${item.allocation}',
                        style: TextStyle(
                          fontSize: dialogWidth * AppConfig.machineStatusDialogStockItemBadgeFontSizeFactor,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add, size: dialogWidth * 0.04),
                          onPressed: () {
                            final controller = ref.read(gameControllerProvider.notifier);
                            final currentTotalAllocation = machine.totalAllocation;
                            final currentItemAllocation = item.allocation;
                            final newTotalAllocation = currentTotalAllocation - currentItemAllocation + (item.allocation + 1);
                            
                            if (newTotalAllocation > machine.maxCapacity) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Cannot exceed machine capacity of ${machine.maxCapacity} items'),
                                  duration: AppConfig.snackbarDurationShort,
                                ),
                              );
                            } else {
                              controller.updateMachineAllocation(machine.id, product, item.allocation + 1);
                            }
                          },
                          padding: EdgeInsets.all(dialogWidth * 0.01),
                          constraints: BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: dialogWidth * AppConfig.machineStatusDialogStockItemPaddingFactor * 0.5),
                _buildPriceControl(context, ref, machine, product, item, dialogWidth),
                SizedBox(height: dialogWidth * AppConfig.machineStatusDialogStockItemPaddingFactor * 0.5),
                // Customer Interest Progress Bar (only show if item has quantity > 0)
                if (item.quantity > 0)
                LinearProgressIndicator(
                  value: item.customerInterest,
                  backgroundColor: VexColors.panelSoft,
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
          );
        }).toList(),
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
              // The panel is part of the city screen, not a route, so it must not be popped.
              // Open the interior dialog, then close the panel through the city's own handler.
              showDialog(
                context: context,
                barrierColor: Colors.black.withValues(alpha: 0.7),
                builder: (context) => MachineInteriorDialog(machine: machine),
              );
              onClose?.call();
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

  /// Price control for one product in one machine: a -/+ stepper on the
  /// player's price multiplier, the resulting retail price, and a live
  /// demand indicator so the tradeoff (higher price, fewer sales) is visible
  /// before committing to it.
  Widget _buildPriceControl(
    BuildContext context,
    WidgetRef ref,
    sim.Machine machine,
    Product product,
    sim.InventoryItem item,
    double dialogWidth,
  ) {
    final elasticity = machine.zone.type.priceElasticity;
    final demandFactor = PricingMath.demandFactor(item.priceMultiplier, elasticity);
    final effectivePrice = PricingMath.effectivePrice(
      basePrice: product.basePrice,
      priceMultiplier: item.priceMultiplier,
    );
    final percentOfList = (item.priceMultiplier * 100).round();
    final demandPercent = (demandFactor * 100).round();
    final demandColor = demandFactor >= 1.0
        ? Colors.green.shade700
        : demandFactor >= 0.7
            ? Colors.orange.shade800
            : Colors.red.shade700;

    void setMultiplier(double multiplier) {
      final controller = ref.read(gameControllerProvider.notifier);
      controller.updateMachinePrice(machine.id, product, multiplier);
    }

    return Row(
      children: [
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: dialogWidth * AppConfig.machineStatusDialogStockItemFontSizeFactor * 0.85,
                color: VexColors.cream,
              ),
              children: [
                TextSpan(
                  text: '\$${effectivePrice.toStringAsFixed(2)} ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: '($percentOfList% of list) · '),
                TextSpan(
                  text: 'Demand $demandPercent%',
                  style: TextStyle(color: demandColor, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.remove_circle_outline, size: dialogWidth * 0.045),
          tooltip: 'Lower price',
          onPressed: () => setMultiplier(item.priceMultiplier - AppConfig.machinePriceMultiplierStep),
          padding: EdgeInsets.all(dialogWidth * 0.008),
          constraints: const BoxConstraints(),
        ),
        IconButton(
          icon: Icon(Icons.add_circle_outline, size: dialogWidth * 0.045),
          tooltip: 'Raise price',
          onPressed: () => setMultiplier(item.priceMultiplier + AppConfig.machinePriceMultiplierStep),
          padding: EdgeInsets.all(dialogWidth * 0.008),
          constraints: const BoxConstraints(),
        ),
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

/// Floating money icon shown above a machine once it has cash waiting.
/// Tapping it collects instantly; a gentle continuous pulse draws the eye to
/// it without needing any new art (Material icon + shadow only).
class _CashCollectButton extends StatefulWidget {
  final VoidCallback onTap;
  final double size;

  const _CashCollectButton({
    required this.onTap,
    required this.size,
  });

  @override
  State<_CashCollectButton> createState() => _CashCollectButtonState();
}

class _CashCollectButtonState extends State<_CashCollectButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  Offset? _pointerDownPosition;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) => _pointerDownPosition = event.position,
      onPointerUp: (event) {
        if (_pointerDownPosition != null) {
          final distance = (event.position - _pointerDownPosition!).distance;
          if (distance < 10.0) {
            widget.onTap();
          }
        }
        _pointerDownPosition = null;
      },
      onPointerCancel: (_) => _pointerDownPosition = null,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _pulseAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.amber.shade600,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: ScreenUtils.relativeSize(context, 0.004)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: ScreenUtils.relativeSize(context, 0.008),
                offset: Offset(0, ScreenUtils.relativeSize(context, 0.003)),
              ),
            ],
          ),
          child: Icon(
            Icons.attach_money,
            color: Colors.white,
            size: widget.size * 0.7,
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
  final double price;
  final VoidCallback onPurchased;

  const _MachinePurchaseDialog({
    required this.zoneType,
    required this.zoneX,
    required this.zoneY,
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
              color: VexColors.panel,
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
                      child: VendingMachine3DView(
                        machine: previewMachineFor(zoneType),
                        height: imageHeight,
                        showCaption: false,
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
                                        color: VexColors.muted,
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
                                        color: VexColors.muted,
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
                                disabledForegroundColor: VexColors.muted,
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

class RainPainter extends CustomPainter {
  final double intensity;
  final double time;

  RainPainter({required this.intensity, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final random = math.Random(12345); // Consistent seed for distribution
    final numDrops = (100 * intensity).toInt();

    for (int i = 0; i < numDrops; i++) {
      final x = random.nextDouble() * size.width;
      final yStart = random.nextDouble() * size.height;
      final speed = 100.0 + random.nextDouble() * 50.0;

      // Animate y position based on time
      final yOffset = (time * speed / 1000.0) % size.height;
      final y = (yStart + yOffset) % size.height;

      canvas.drawLine(
        Offset(x, y),
        Offset(x - 5, y + 15), // Diagonal rain
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(RainPainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.intensity != intensity;
  }
}

/// Title bar of the machine details: the machine's name and zone, and a close button.
class _MachineHeader extends StatelessWidget {
  const _MachineHeader({
    required this.machine,
    required this.padding,
    required this.minimized,
    required this.onToggleMinimized,
    required this.onClose,
  });

  final sim.Machine machine;
  final double padding;
  final bool minimized;
  final VoidCallback onToggleMinimized;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final zone = machine.zone.type;
    return Container(
      padding: EdgeInsets.fromLTRB(padding, padding * 0.8, padding * 0.4, padding * 0.8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: VexColors.line)),
      ),
      child: Row(
        children: [
          Icon(zone.icon, color: zone.color, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  machine.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: VexColors.gold,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${zone.name.toUpperCase()} · ${machine.isBroken ? 'BROKEN' : 'WORKING'}',
                  style: const TextStyle(color: VexColors.muted, fontSize: 11, letterSpacing: 0.8),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: minimized ? 'Expand' : 'Minimize',
            icon: Icon(
              minimized ? Icons.expand_less : Icons.expand_more,
              color: VexColors.cream,
            ),
            onPressed: onToggleMinimized,
          ),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close, color: VexColors.cream),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
