// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'machine.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$InventoryItem {

 Product get product; int get quantity; int get dayAdded;// Game day when item was added
 double get salesProgress;// Accumulator for customer interest (0.0 to 1.0+)
 int get allocation;
/// Create a copy of InventoryItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InventoryItemCopyWith<InventoryItem> get copyWith => _$InventoryItemCopyWithImpl<InventoryItem>(this as InventoryItem, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InventoryItem&&(identical(other.product, product) || other.product == product)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.dayAdded, dayAdded) || other.dayAdded == dayAdded)&&(identical(other.salesProgress, salesProgress) || other.salesProgress == salesProgress)&&(identical(other.allocation, allocation) || other.allocation == allocation));
}


@override
int get hashCode => Object.hash(runtimeType,product,quantity,dayAdded,salesProgress,allocation);

@override
String toString() {
  return 'InventoryItem(product: $product, quantity: $quantity, dayAdded: $dayAdded, salesProgress: $salesProgress, allocation: $allocation)';
}


}

/// @nodoc
abstract mixin class $InventoryItemCopyWith<$Res>  {
  factory $InventoryItemCopyWith(InventoryItem value, $Res Function(InventoryItem) _then) = _$InventoryItemCopyWithImpl;
@useResult
$Res call({
 Product product, int quantity, int dayAdded, double salesProgress, int allocation
});




}
/// @nodoc
class _$InventoryItemCopyWithImpl<$Res>
    implements $InventoryItemCopyWith<$Res> {
  _$InventoryItemCopyWithImpl(this._self, this._then);

  final InventoryItem _self;
  final $Res Function(InventoryItem) _then;

/// Create a copy of InventoryItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? product = null,Object? quantity = null,Object? dayAdded = null,Object? salesProgress = null,Object? allocation = null,}) {
  return _then(_self.copyWith(
product: null == product ? _self.product : product // ignore: cast_nullable_to_non_nullable
as Product,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,dayAdded: null == dayAdded ? _self.dayAdded : dayAdded // ignore: cast_nullable_to_non_nullable
as int,salesProgress: null == salesProgress ? _self.salesProgress : salesProgress // ignore: cast_nullable_to_non_nullable
as double,allocation: null == allocation ? _self.allocation : allocation // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [InventoryItem].
extension InventoryItemPatterns on InventoryItem {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InventoryItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InventoryItem() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InventoryItem value)  $default,){
final _that = this;
switch (_that) {
case _InventoryItem():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InventoryItem value)?  $default,){
final _that = this;
switch (_that) {
case _InventoryItem() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Product product,  int quantity,  int dayAdded,  double salesProgress,  int allocation)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InventoryItem() when $default != null:
return $default(_that.product,_that.quantity,_that.dayAdded,_that.salesProgress,_that.allocation);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Product product,  int quantity,  int dayAdded,  double salesProgress,  int allocation)  $default,) {final _that = this;
switch (_that) {
case _InventoryItem():
return $default(_that.product,_that.quantity,_that.dayAdded,_that.salesProgress,_that.allocation);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Product product,  int quantity,  int dayAdded,  double salesProgress,  int allocation)?  $default,) {final _that = this;
switch (_that) {
case _InventoryItem() when $default != null:
return $default(_that.product,_that.quantity,_that.dayAdded,_that.salesProgress,_that.allocation);case _:
  return null;

}
}

}

/// @nodoc


class _InventoryItem extends InventoryItem {
  const _InventoryItem({required this.product, required this.quantity, required this.dayAdded, this.salesProgress = 0.0, this.allocation = 20}): super._();
  

@override final  Product product;
@override final  int quantity;
@override final  int dayAdded;
// Game day when item was added
@override@JsonKey() final  double salesProgress;
// Accumulator for customer interest (0.0 to 1.0+)
@override@JsonKey() final  int allocation;

/// Create a copy of InventoryItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InventoryItemCopyWith<_InventoryItem> get copyWith => __$InventoryItemCopyWithImpl<_InventoryItem>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InventoryItem&&(identical(other.product, product) || other.product == product)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.dayAdded, dayAdded) || other.dayAdded == dayAdded)&&(identical(other.salesProgress, salesProgress) || other.salesProgress == salesProgress)&&(identical(other.allocation, allocation) || other.allocation == allocation));
}


@override
int get hashCode => Object.hash(runtimeType,product,quantity,dayAdded,salesProgress,allocation);

@override
String toString() {
  return 'InventoryItem(product: $product, quantity: $quantity, dayAdded: $dayAdded, salesProgress: $salesProgress, allocation: $allocation)';
}


}

/// @nodoc
abstract mixin class _$InventoryItemCopyWith<$Res> implements $InventoryItemCopyWith<$Res> {
  factory _$InventoryItemCopyWith(_InventoryItem value, $Res Function(_InventoryItem) _then) = __$InventoryItemCopyWithImpl;
@override @useResult
$Res call({
 Product product, int quantity, int dayAdded, double salesProgress, int allocation
});




}
/// @nodoc
class __$InventoryItemCopyWithImpl<$Res>
    implements _$InventoryItemCopyWith<$Res> {
  __$InventoryItemCopyWithImpl(this._self, this._then);

  final _InventoryItem _self;
  final $Res Function(_InventoryItem) _then;

/// Create a copy of InventoryItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? product = null,Object? quantity = null,Object? dayAdded = null,Object? salesProgress = null,Object? allocation = null,}) {
  return _then(_InventoryItem(
product: null == product ? _self.product : product // ignore: cast_nullable_to_non_nullable
as Product,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,dayAdded: null == dayAdded ? _self.dayAdded : dayAdded // ignore: cast_nullable_to_non_nullable
as int,salesProgress: null == salesProgress ? _self.salesProgress : salesProgress // ignore: cast_nullable_to_non_nullable
as double,allocation: null == allocation ? _self.allocation : allocation // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$Machine {

 String get id; String get name; Zone get zone; MachineCondition get condition;/// Inventory: Map of Product to InventoryItem
 Map<Product, InventoryItem> get inventory; double get currentCash;/// Hours since last restock (for reputation penalty calculation)
 double get hoursSinceRestock;/// Total sales count (for analytics)
 int get totalSales;/// Whether the machine is currently under maintenance (e.g., open for cash collection)
 bool get isUnderMaintenance;
/// Create a copy of Machine
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MachineCopyWith<Machine> get copyWith => _$MachineCopyWithImpl<Machine>(this as Machine, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Machine&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.zone, zone) || other.zone == zone)&&(identical(other.condition, condition) || other.condition == condition)&&const DeepCollectionEquality().equals(other.inventory, inventory)&&(identical(other.currentCash, currentCash) || other.currentCash == currentCash)&&(identical(other.hoursSinceRestock, hoursSinceRestock) || other.hoursSinceRestock == hoursSinceRestock)&&(identical(other.totalSales, totalSales) || other.totalSales == totalSales)&&(identical(other.isUnderMaintenance, isUnderMaintenance) || other.isUnderMaintenance == isUnderMaintenance));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,zone,condition,const DeepCollectionEquality().hash(inventory),currentCash,hoursSinceRestock,totalSales,isUnderMaintenance);

@override
String toString() {
  return 'Machine(id: $id, name: $name, zone: $zone, condition: $condition, inventory: $inventory, currentCash: $currentCash, hoursSinceRestock: $hoursSinceRestock, totalSales: $totalSales, isUnderMaintenance: $isUnderMaintenance)';
}


}

/// @nodoc
abstract mixin class $MachineCopyWith<$Res>  {
  factory $MachineCopyWith(Machine value, $Res Function(Machine) _then) = _$MachineCopyWithImpl;
@useResult
$Res call({
 String id, String name, Zone zone, MachineCondition condition, Map<Product, InventoryItem> inventory, double currentCash, double hoursSinceRestock, int totalSales, bool isUnderMaintenance
});


$ZoneCopyWith<$Res> get zone;

}
/// @nodoc
class _$MachineCopyWithImpl<$Res>
    implements $MachineCopyWith<$Res> {
  _$MachineCopyWithImpl(this._self, this._then);

  final Machine _self;
  final $Res Function(Machine) _then;

/// Create a copy of Machine
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? zone = null,Object? condition = null,Object? inventory = null,Object? currentCash = null,Object? hoursSinceRestock = null,Object? totalSales = null,Object? isUnderMaintenance = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,zone: null == zone ? _self.zone : zone // ignore: cast_nullable_to_non_nullable
as Zone,condition: null == condition ? _self.condition : condition // ignore: cast_nullable_to_non_nullable
as MachineCondition,inventory: null == inventory ? _self.inventory : inventory // ignore: cast_nullable_to_non_nullable
as Map<Product, InventoryItem>,currentCash: null == currentCash ? _self.currentCash : currentCash // ignore: cast_nullable_to_non_nullable
as double,hoursSinceRestock: null == hoursSinceRestock ? _self.hoursSinceRestock : hoursSinceRestock // ignore: cast_nullable_to_non_nullable
as double,totalSales: null == totalSales ? _self.totalSales : totalSales // ignore: cast_nullable_to_non_nullable
as int,isUnderMaintenance: null == isUnderMaintenance ? _self.isUnderMaintenance : isUnderMaintenance // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of Machine
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ZoneCopyWith<$Res> get zone {
  
  return $ZoneCopyWith<$Res>(_self.zone, (value) {
    return _then(_self.copyWith(zone: value));
  });
}
}


/// Adds pattern-matching-related methods to [Machine].
extension MachinePatterns on Machine {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Machine value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Machine() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Machine value)  $default,){
final _that = this;
switch (_that) {
case _Machine():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Machine value)?  $default,){
final _that = this;
switch (_that) {
case _Machine() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  Zone zone,  MachineCondition condition,  Map<Product, InventoryItem> inventory,  double currentCash,  double hoursSinceRestock,  int totalSales,  bool isUnderMaintenance)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Machine() when $default != null:
return $default(_that.id,_that.name,_that.zone,_that.condition,_that.inventory,_that.currentCash,_that.hoursSinceRestock,_that.totalSales,_that.isUnderMaintenance);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  Zone zone,  MachineCondition condition,  Map<Product, InventoryItem> inventory,  double currentCash,  double hoursSinceRestock,  int totalSales,  bool isUnderMaintenance)  $default,) {final _that = this;
switch (_that) {
case _Machine():
return $default(_that.id,_that.name,_that.zone,_that.condition,_that.inventory,_that.currentCash,_that.hoursSinceRestock,_that.totalSales,_that.isUnderMaintenance);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  Zone zone,  MachineCondition condition,  Map<Product, InventoryItem> inventory,  double currentCash,  double hoursSinceRestock,  int totalSales,  bool isUnderMaintenance)?  $default,) {final _that = this;
switch (_that) {
case _Machine() when $default != null:
return $default(_that.id,_that.name,_that.zone,_that.condition,_that.inventory,_that.currentCash,_that.hoursSinceRestock,_that.totalSales,_that.isUnderMaintenance);case _:
  return null;

}
}

}

/// @nodoc


class _Machine extends Machine {
  const _Machine({required this.id, required this.name, required this.zone, required this.condition, final  Map<Product, InventoryItem> inventory = const {}, this.currentCash = 0.0, this.hoursSinceRestock = 0.0, this.totalSales = 0, this.isUnderMaintenance = false}): _inventory = inventory,super._();
  

@override final  String id;
@override final  String name;
@override final  Zone zone;
@override final  MachineCondition condition;
/// Inventory: Map of Product to InventoryItem
 final  Map<Product, InventoryItem> _inventory;
/// Inventory: Map of Product to InventoryItem
@override@JsonKey() Map<Product, InventoryItem> get inventory {
  if (_inventory is EqualUnmodifiableMapView) return _inventory;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_inventory);
}

@override@JsonKey() final  double currentCash;
/// Hours since last restock (for reputation penalty calculation)
@override@JsonKey() final  double hoursSinceRestock;
/// Total sales count (for analytics)
@override@JsonKey() final  int totalSales;
/// Whether the machine is currently under maintenance (e.g., open for cash collection)
@override@JsonKey() final  bool isUnderMaintenance;

/// Create a copy of Machine
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MachineCopyWith<_Machine> get copyWith => __$MachineCopyWithImpl<_Machine>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Machine&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.zone, zone) || other.zone == zone)&&(identical(other.condition, condition) || other.condition == condition)&&const DeepCollectionEquality().equals(other._inventory, _inventory)&&(identical(other.currentCash, currentCash) || other.currentCash == currentCash)&&(identical(other.hoursSinceRestock, hoursSinceRestock) || other.hoursSinceRestock == hoursSinceRestock)&&(identical(other.totalSales, totalSales) || other.totalSales == totalSales)&&(identical(other.isUnderMaintenance, isUnderMaintenance) || other.isUnderMaintenance == isUnderMaintenance));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,zone,condition,const DeepCollectionEquality().hash(_inventory),currentCash,hoursSinceRestock,totalSales,isUnderMaintenance);

@override
String toString() {
  return 'Machine(id: $id, name: $name, zone: $zone, condition: $condition, inventory: $inventory, currentCash: $currentCash, hoursSinceRestock: $hoursSinceRestock, totalSales: $totalSales, isUnderMaintenance: $isUnderMaintenance)';
}


}

/// @nodoc
abstract mixin class _$MachineCopyWith<$Res> implements $MachineCopyWith<$Res> {
  factory _$MachineCopyWith(_Machine value, $Res Function(_Machine) _then) = __$MachineCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, Zone zone, MachineCondition condition, Map<Product, InventoryItem> inventory, double currentCash, double hoursSinceRestock, int totalSales, bool isUnderMaintenance
});


@override $ZoneCopyWith<$Res> get zone;

}
/// @nodoc
class __$MachineCopyWithImpl<$Res>
    implements _$MachineCopyWith<$Res> {
  __$MachineCopyWithImpl(this._self, this._then);

  final _Machine _self;
  final $Res Function(_Machine) _then;

/// Create a copy of Machine
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? zone = null,Object? condition = null,Object? inventory = null,Object? currentCash = null,Object? hoursSinceRestock = null,Object? totalSales = null,Object? isUnderMaintenance = null,}) {
  return _then(_Machine(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,zone: null == zone ? _self.zone : zone // ignore: cast_nullable_to_non_nullable
as Zone,condition: null == condition ? _self.condition : condition // ignore: cast_nullable_to_non_nullable
as MachineCondition,inventory: null == inventory ? _self._inventory : inventory // ignore: cast_nullable_to_non_nullable
as Map<Product, InventoryItem>,currentCash: null == currentCash ? _self.currentCash : currentCash // ignore: cast_nullable_to_non_nullable
as double,hoursSinceRestock: null == hoursSinceRestock ? _self.hoursSinceRestock : hoursSinceRestock // ignore: cast_nullable_to_non_nullable
as double,totalSales: null == totalSales ? _self.totalSales : totalSales // ignore: cast_nullable_to_non_nullable
as int,isUnderMaintenance: null == isUnderMaintenance ? _self.isUnderMaintenance : isUnderMaintenance // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of Machine
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ZoneCopyWith<$Res> get zone {
  
  return $ZoneCopyWith<$Res>(_self.zone, (value) {
    return _then(_self.copyWith(zone: value));
  });
}
}

// dart format on
