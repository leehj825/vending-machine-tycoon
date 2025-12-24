/// City map state that holds the layout of buildings and roads
class CityMapState {
  final List<List<String>> grid; // TileType names as strings
  final List<List<String?>> roadDirections; // RoadDirection names as strings or null
  final List<List<String?>> buildingOrientations; // BuildingOrientation names as strings or null
  final int? warehouseX;
  final int? warehouseY;

  const CityMapState({
    required this.grid,
    required this.roadDirections,
    required this.buildingOrientations,
    this.warehouseX,
    this.warehouseY,
  });

  /// Create an empty map state
  factory CityMapState.empty() {
    return const CityMapState(
      grid: [],
      roadDirections: [],
      buildingOrientations: [],
      warehouseX: null,
      warehouseY: null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'grid': grid,
      'roadDirections': roadDirections,
      'buildingOrientations': buildingOrientations,
      'warehouseX': warehouseX,
      'warehouseY': warehouseY,
    };
  }

  /// Create from JSON
  factory CityMapState.fromJson(Map<String, dynamic> json) {
    return CityMapState(
      grid: (json['grid'] as List)
          .map((row) => List<String>.from(row as List))
          .toList(),
      roadDirections: (json['roadDirections'] as List)
          .map((row) => (row as List).map((e) => e as String?).toList())
          .toList(),
      buildingOrientations: (json['buildingOrientations'] as List)
          .map((row) => (row as List).map((e) => e as String?).toList())
          .toList(),
      warehouseX: json['warehouseX'] as int?,
      warehouseY: json['warehouseY'] as int?,
    );
  }
}

