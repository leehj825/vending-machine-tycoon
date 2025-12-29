import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../components/status_customer.dart';
import '../../simulation/models/zone.dart';

/// Minimal Flame game for embedding in the machine status card
/// This game only contains the customer animation component
class CustomerPreviewGame extends FlameGame {
  final ZoneType zoneType;
  final double cardWidth;
  final double cardHeight;
  
  CustomerPreviewGame({
    required this.zoneType,
    required this.cardWidth,
    required this.cardHeight,
  });

  @override
  Color backgroundColor() => const Color(0x00000000); // Transparent

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    // Add customer component
    final customer = StatusCustomer(
      zoneType: zoneType,
      cardWidth: cardWidth,
      cardHeight: cardHeight,
    );
    
    add(customer);
  }
}

