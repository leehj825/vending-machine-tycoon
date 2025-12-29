import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../simulation/models/zone.dart';
import 'components/machine_status_customer.dart';

/// Minimal Flame game for embedding in the machine interior dialog
/// This game only contains the customer animation component
class MachineDialogGame extends FlameGame {
  final ZoneType zoneType;
  final double dialogWidth;
  final double dialogHeight;
  
  MachineDialogGame({
    required this.zoneType,
    required this.dialogWidth,
    required this.dialogHeight,
  });

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    // Add customer component
    final customer = MachineStatusCustomer(
      zoneType: zoneType,
      dialogWidth: dialogWidth,
      dialogHeight: dialogHeight,
    );
    
    add(customer);
  }
}

