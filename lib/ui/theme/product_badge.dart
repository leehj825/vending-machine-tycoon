import 'package:flutter/material.dart';

import '../../simulation/models/product.dart';
import '../three_d/vending_machine_3d.dart' show productSlotColor;
import 'vex_theme.dart';

/// A product shown as a coloured tile with an icon, in place of a picture.
/// Without [size] it fills the space it is given.
class ProductBadge extends StatelessWidget {
  const ProductBadge({super.key, required this.product, this.size});

  final Product product;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final color = productSlotColor(product);
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = size ?? constraints.biggest.shortestSide;
        return Container(
          width: side,
          height: side,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color.lerp(color, Colors.white, 0.25) ?? color, color],
            ),
            border: Border.all(color: VexColors.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(productIcon(product), color: Colors.white, size: side * 0.55),
        );
      },
    );
  }
}

/// The icon that stands for a product.
IconData productIcon(Product product) {
  switch (product) {
    case Product.soda:
      return Icons.local_drink;
    case Product.chips:
      return Icons.fastfood;
    case Product.proteinBar:
      return Icons.fitness_center;
    case Product.coffee:
      return Icons.coffee;
    case Product.techGadget:
      return Icons.devices;
    case Product.sandwich:
      return Icons.lunch_dining;
    case Product.freshSalad:
      return Icons.eco;
    case Product.newspaper:
      return Icons.newspaper;
    case Product.energyDrink:
      return Icons.bolt;
  }
}
