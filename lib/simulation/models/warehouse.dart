import 'package:freezed_annotation/freezed_annotation.dart';
import 'product.dart';

part 'warehouse.freezed.dart';

/// Warehouse inventory (global stock available for restocking)
@freezed
abstract class Warehouse with _$Warehouse {
  const factory Warehouse({
    @Default({}) Map<Product, int> inventory,
  }) = _Warehouse;

  const Warehouse._();
}
