import 'package:flutter/material.dart';

import '../../simulation/models/machine.dart' as sim;
import '../../simulation/models/product.dart';
import '../../simulation/models/zone.dart';
import '../theme/vex_theme.dart';
import '../theme/zone_ui.dart';
import 'lowpoly_engine.dart';

/// Camera for the vending machine preview: a three-quarter view of the front.
const LowPolyCamera vendingMachineCamera = LowPolyCamera(
  target: Vec3(0, 0.95, 0),
  yaw: 0.5,
  pitch: 0.28,
  distance: 3.2,
);

/// Lowpoly vending machine that shows the machine's stock and cash.
class VendingMachine3DView extends StatelessWidget {
  const VendingMachine3DView({
    super.key,
    required this.machine,
    this.height = 260,
    this.showCaption = true,
  });

  final sim.Machine machine;
  final double height;
  final bool showCaption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LowPolyView(
              objects: buildVendingMachineScene(machine),
              camera: vendingMachineCamera,
              background: const Color(0xFFEEF2F6),
              minDistance: 2.2,
              maxDistance: 5,
            ),
          ),
        ),
        if (showCaption) ...[
          const SizedBox(height: 4),
          Text(
            'Drag to rotate · pinch to zoom',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: VexColors.muted),
          ),
        ],
      ],
    );
  }
}

/// Colour of the product sold in a slot.
Color productSlotColor(Product product) {
  switch (product) {
    case Product.soda:
      return const Color(0xFFE53935);
    case Product.chips:
      return const Color(0xFFFDD835);
    case Product.proteinBar:
      return const Color(0xFF8D6E63);
    case Product.coffee:
      return const Color(0xFF5D4037);
    case Product.techGadget:
      return const Color(0xFF42A5F5);
    case Product.sandwich:
      return const Color(0xFFFFB74D);
    case Product.freshSalad:
      return const Color(0xFF66BB6A);
    case Product.newspaper:
      return const Color(0xFFBDBDBD);
    case Product.energyDrink:
      return const Color(0xFF9CCC65);
  }
}

const int _slotRows = 4;
const int _slotColumns = 3;
const int _slotCount = _slotRows * _slotColumns;

/// Stock below this count fills a slot's product completely.
const int _fullSlotStock = 20;

/// Builds the vending machine as a single object, with parts listed back to front.
///
/// The model is about 2 units tall in its own space. Place it with [placeObject] to
/// put it on the map at a smaller scale.
List<LowPolyObject> buildVendingMachineScene(sim.Machine machine, {double brightness = 1.0}) {
  final accent = machine.zone.type.color;
  final sign = Color.lerp(accent, Colors.white, 0.25) ?? accent;
  final cabinetTop = Color.lerp(accent, Colors.black, 0.2) ?? accent;
  final cabinetSide = Color.lerp(accent, Colors.black, 0.12) ?? accent;
  const steel = Color(0xFFB0BEC5);
  const dark = Color(0xFF2B2F38);
  final cashColor = machine.currentCash > 0
      ? const Color(0xFF43A047)
      : const Color(0xFF9E9E9E);

  final m = LowPolyMeshBuilder(brightness: brightness)
    // Plinth, cabinet and a sign band with a light strip.
    ..box(-0.52, 0, -0.4, 0.52, 0.12, 0.4, const Color(0xFF3A3F47))
    ..box(-0.5, 0.12, -0.38, 0.5, 1.85, 0.38, accent, top: cabinetTop)
    ..box(-0.5, 1.85, -0.38, 0.5, 2.0, 0.38, sign)
    ..box(-0.46, 1.8, 0.38, 0.46, 1.84, 0.41, const Color(0xFFFFF59D))
    // Side vents and a rounded side panel, so the side reads as a machine too.
    ..box(0.5, 0.2, -0.3, 0.53, 1.2, 0.3, cabinetSide)
    ..box(0.53, 0.3, -0.25, 0.55, 0.36, 0.25, const Color(0xFF263238))
    ..box(0.53, 0.42, -0.25, 0.55, 0.48, 0.25, const Color(0xFF263238))
    ..box(0.53, 0.54, -0.25, 0.55, 0.60, 0.25, const Color(0xFF263238))
    // Glass front with a steel frame around it.
    ..box(-0.4, 0.46, 0.38, 0.38, 1.7, 0.4, steel)
    ..box(-0.36, 0.5, 0.38, 0.34, 1.65, 0.42, const Color(0xFF203040));

  final slots = _slotLayout(machine);
  for (var row = 0; row < _slotRows; row++) {
    for (var col = 0; col < _slotColumns; col++) {
      final slot = slots[row * _slotColumns + col];
      final x0 = -0.32 + col * 0.22;
      final y1 = 1.6 - row * 0.27;
      final color = slot == null
          ? const Color(0xFF2B2F38)
          : productSlotColor(slot.product).withValues(alpha: slot.filled ? 1.0 : 0.35);
      // A product box with a lighter cap on top, and a spiral shelf behind it.
      m.box(x0, y1 - 0.22, 0.4, x0 + 0.18, y1, 0.45, color);
      m.box(x0 + 0.02, y1 - 0.04, 0.44, x0 + 0.16, y1, 0.47,
          Color.lerp(color, Colors.white, 0.35) ?? color);
      m.box(x0, y1 - 0.25, 0.38, x0 + 0.18, y1 - 0.22, 0.4, steel);
    }
  }

  m
    // Keypad: a 3 by 3 grid of buttons with a selection display above.
    ..box(0.37, 0.5, 0.38, 0.46, 1.3, 0.42, dark)
    ..box(0.39, 1.36, 0.41, 0.44, 1.5, 0.44, cashColor)
    ..box(0.39, 0.6, 0.41, 0.44, 0.7, 0.44, const Color(0xFFCFD8DC))
    // Bill validator slot and card reader.
    ..box(0.39, 0.78, 0.41, 0.44, 0.84, 0.45, const Color(0xFF12161D))
    ..box(0.39, 1.0, 0.41, 0.44, 1.06, 0.45, const Color(0xFF90A4AE))
    // Delivery bin and its flap.
    ..box(-0.3, 0.2, 0.38, 0.3, 0.42, 0.42, const Color(0xFF1B1F26))
    ..box(-0.3, 0.38, 0.42, 0.3, 0.42, 0.46, steel);
  for (var key = 0; key < 9; key++) {
    final kx = 0.385 + (key % 3) * 0.022;
    final ky = 0.9 + (key ~/ 3) * 0.1;
    m.box(kx, ky, 0.43, kx + 0.014, ky + 0.05, 0.45, const Color(0xFFECEFF1));
  }

  return [m.build(center: const Vec3(0, 1, 0))];
}

/// What one slot shows: the product it sells and whether it has stock.
class _Slot {
  const _Slot(this.product, this.filled);

  final Product product;
  final bool filled;
}

/// Spreads the stocked products over the slots, in product order, so every
/// product gets a share of the grid. Empty machines show empty slots.
List<_Slot?> _slotLayout(sim.Machine machine) {
  final stocked = [
    for (final product in Product.values)
      if ((machine.inventory[product]?.quantity ?? 0) > 0) product,
  ];
  if (stocked.isEmpty) return List<_Slot?>.filled(_slotCount, null);

  final slotsPerProduct = (_slotCount / stocked.length).ceil();
  final slots = <_Slot?>[];
  for (var index = 0; index < _slotCount; index++) {
    final product = stocked[index % stocked.length];
    final sequence = index ~/ stocked.length;
    final quantity = machine.inventory[product]?.quantity ?? 0;
    final level = (quantity / _fullSlotStock).clamp(0.0, 1.0).toDouble();
    final filled = (sequence + 0.5) / slotsPerProduct < level;
    slots.add(_Slot(product, filled));
  }
  return slots;
}

/// An empty machine of [type], for showing a machine before it is bought.
sim.Machine previewMachineFor(ZoneType type) => sim.Machine(
      id: 'preview-${type.name}',
      name: type.name,
      zone: Zone(id: 'preview-${type.name}', type: type, name: type.name, x: 1, y: 1),
      condition: sim.MachineCondition.good,
    );
