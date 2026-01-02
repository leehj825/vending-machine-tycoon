import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tile_city_screen.dart';

/// Screen that displays the city map using Flutter widget-based TileCityScreen
class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // AppBar removed - managed by MainScreen
    return const TileCityScreen();
  }
}

