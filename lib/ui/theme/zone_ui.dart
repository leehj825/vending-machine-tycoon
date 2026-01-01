import 'package:flutter/material.dart';
import '../../simulation/models/zone.dart';

/// Extension on ZoneType for UI presentation (icons and colors)
extension ZoneTypeUI on ZoneType {
  /// Get icon for this zone type
  IconData get icon {
    switch (this) {
      case ZoneType.shop:
        return Icons.shopping_cart;
      case ZoneType.school:
        return Icons.school;
      case ZoneType.gym:
        return Icons.fitness_center;
      case ZoneType.office:
        return Icons.business;
      case ZoneType.subway:
        return Icons.train;
      case ZoneType.hospital:
        return Icons.local_hospital;
      case ZoneType.university:
        return Icons.school;
    }
  }

  /// Get color for this zone type
  Color get color {
    switch (this) {
      case ZoneType.shop:
        return Colors.blue;
      case ZoneType.school:
        return Colors.purple;
      case ZoneType.gym:
        return Colors.orange;
      case ZoneType.office:
        return Colors.blue;
      case ZoneType.subway:
        return Colors.blueGrey;
      case ZoneType.hospital:
        return Colors.red;
      case ZoneType.university:
        return Colors.indigo;
    }
  }
}
