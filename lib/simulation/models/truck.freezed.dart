// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'truck.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Truck {

 String get id; String get name; double get fuel;// Percentage (0-100)
 int get capacity;// Max items it can carry
/// Current route: List of machine IDs to visit in order
 List<String> get route;/// Pending route: Route changes saved while truck is moving (applied when truck becomes idle)
 List<String> get pendingRoute;/// Current position in the route (index)
 int get currentRouteIndex; TruckStatus get status;/// Current position (x, y) on the grid
 double get currentX; double get currentY;/// Target position (x, y) when traveling
 double get targetX; double get targetY;/// Path waypoints for smooth movement (list of (x, y) positions)
 List<({double x, double y})> get path;/// Current index in the path
 int get pathIndex; Map<Product, int> get inventory; bool get hasDriver;
/// Create a copy of Truck
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TruckCopyWith<Truck> get copyWith => _$TruckCopyWithImpl<Truck>(this as Truck, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Truck&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.fuel, fuel) || other.fuel == fuel)&&(identical(other.capacity, capacity) || other.capacity == capacity)&&const DeepCollectionEquality().equals(other.route, route)&&const DeepCollectionEquality().equals(other.pendingRoute, pendingRoute)&&(identical(other.currentRouteIndex, currentRouteIndex) || other.currentRouteIndex == currentRouteIndex)&&(identical(other.status, status) || other.status == status)&&(identical(other.currentX, currentX) || other.currentX == currentX)&&(identical(other.currentY, currentY) || other.currentY == currentY)&&(identical(other.targetX, targetX) || other.targetX == targetX)&&(identical(other.targetY, targetY) || other.targetY == targetY)&&const DeepCollectionEquality().equals(other.path, path)&&(identical(other.pathIndex, pathIndex) || other.pathIndex == pathIndex)&&const DeepCollectionEquality().equals(other.inventory, inventory)&&(identical(other.hasDriver, hasDriver) || other.hasDriver == hasDriver));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,fuel,capacity,const DeepCollectionEquality().hash(route),const DeepCollectionEquality().hash(pendingRoute),currentRouteIndex,status,currentX,currentY,targetX,targetY,const DeepCollectionEquality().hash(path),pathIndex,const DeepCollectionEquality().hash(inventory),hasDriver);

@override
String toString() {
  return 'Truck(id: $id, name: $name, fuel: $fuel, capacity: $capacity, route: $route, pendingRoute: $pendingRoute, currentRouteIndex: $currentRouteIndex, status: $status, currentX: $currentX, currentY: $currentY, targetX: $targetX, targetY: $targetY, path: $path, pathIndex: $pathIndex, inventory: $inventory, hasDriver: $hasDriver)';
}


}

/// @nodoc
abstract mixin class $TruckCopyWith<$Res>  {
  factory $TruckCopyWith(Truck value, $Res Function(Truck) _then) = _$TruckCopyWithImpl;
@useResult
$Res call({
 String id, String name, double fuel, int capacity, List<String> route, List<String> pendingRoute, int currentRouteIndex, TruckStatus status, double currentX, double currentY, double targetX, double targetY, List<({double x, double y})> path, int pathIndex, Map<Product, int> inventory, bool hasDriver
});




}
/// @nodoc
class _$TruckCopyWithImpl<$Res>
    implements $TruckCopyWith<$Res> {
  _$TruckCopyWithImpl(this._self, this._then);

  final Truck _self;
  final $Res Function(Truck) _then;

/// Create a copy of Truck
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? fuel = null,Object? capacity = null,Object? route = null,Object? pendingRoute = null,Object? currentRouteIndex = null,Object? status = null,Object? currentX = null,Object? currentY = null,Object? targetX = null,Object? targetY = null,Object? path = null,Object? pathIndex = null,Object? inventory = null,Object? hasDriver = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,fuel: null == fuel ? _self.fuel : fuel // ignore: cast_nullable_to_non_nullable
as double,capacity: null == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as int,route: null == route ? _self.route : route // ignore: cast_nullable_to_non_nullable
as List<String>,pendingRoute: null == pendingRoute ? _self.pendingRoute : pendingRoute // ignore: cast_nullable_to_non_nullable
as List<String>,currentRouteIndex: null == currentRouteIndex ? _self.currentRouteIndex : currentRouteIndex // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as TruckStatus,currentX: null == currentX ? _self.currentX : currentX // ignore: cast_nullable_to_non_nullable
as double,currentY: null == currentY ? _self.currentY : currentY // ignore: cast_nullable_to_non_nullable
as double,targetX: null == targetX ? _self.targetX : targetX // ignore: cast_nullable_to_non_nullable
as double,targetY: null == targetY ? _self.targetY : targetY // ignore: cast_nullable_to_non_nullable
as double,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as List<({double x, double y})>,pathIndex: null == pathIndex ? _self.pathIndex : pathIndex // ignore: cast_nullable_to_non_nullable
as int,inventory: null == inventory ? _self.inventory : inventory // ignore: cast_nullable_to_non_nullable
as Map<Product, int>,hasDriver: null == hasDriver ? _self.hasDriver : hasDriver // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Truck].
extension TruckPatterns on Truck {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Truck value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Truck() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Truck value)  $default,){
final _that = this;
switch (_that) {
case _Truck():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Truck value)?  $default,){
final _that = this;
switch (_that) {
case _Truck() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  double fuel,  int capacity,  List<String> route,  List<String> pendingRoute,  int currentRouteIndex,  TruckStatus status,  double currentX,  double currentY,  double targetX,  double targetY,  List<({double x, double y})> path,  int pathIndex,  Map<Product, int> inventory,  bool hasDriver)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Truck() when $default != null:
return $default(_that.id,_that.name,_that.fuel,_that.capacity,_that.route,_that.pendingRoute,_that.currentRouteIndex,_that.status,_that.currentX,_that.currentY,_that.targetX,_that.targetY,_that.path,_that.pathIndex,_that.inventory,_that.hasDriver);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  double fuel,  int capacity,  List<String> route,  List<String> pendingRoute,  int currentRouteIndex,  TruckStatus status,  double currentX,  double currentY,  double targetX,  double targetY,  List<({double x, double y})> path,  int pathIndex,  Map<Product, int> inventory,  bool hasDriver)  $default,) {final _that = this;
switch (_that) {
case _Truck():
return $default(_that.id,_that.name,_that.fuel,_that.capacity,_that.route,_that.pendingRoute,_that.currentRouteIndex,_that.status,_that.currentX,_that.currentY,_that.targetX,_that.targetY,_that.path,_that.pathIndex,_that.inventory,_that.hasDriver);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  double fuel,  int capacity,  List<String> route,  List<String> pendingRoute,  int currentRouteIndex,  TruckStatus status,  double currentX,  double currentY,  double targetX,  double targetY,  List<({double x, double y})> path,  int pathIndex,  Map<Product, int> inventory,  bool hasDriver)?  $default,) {final _that = this;
switch (_that) {
case _Truck() when $default != null:
return $default(_that.id,_that.name,_that.fuel,_that.capacity,_that.route,_that.pendingRoute,_that.currentRouteIndex,_that.status,_that.currentX,_that.currentY,_that.targetX,_that.targetY,_that.path,_that.pathIndex,_that.inventory,_that.hasDriver);case _:
  return null;

}
}

}

/// @nodoc


class _Truck extends Truck {
  const _Truck({required this.id, required this.name, this.fuel = 100.0, this.capacity = AppConfig.truckMaxCapacity, final  List<String> route = const [], final  List<String> pendingRoute = const [], this.currentRouteIndex = 0, this.status = TruckStatus.idle, this.currentX = 0.0, this.currentY = 0.0, this.targetX = 0.0, this.targetY = 0.0, final  List<({double x, double y})> path = const [], this.pathIndex = 0, final  Map<Product, int> inventory = const {}, this.hasDriver = false}): _route = route,_pendingRoute = pendingRoute,_path = path,_inventory = inventory,super._();
  

@override final  String id;
@override final  String name;
@override@JsonKey() final  double fuel;
// Percentage (0-100)
@override@JsonKey() final  int capacity;
// Max items it can carry
/// Current route: List of machine IDs to visit in order
 final  List<String> _route;
// Max items it can carry
/// Current route: List of machine IDs to visit in order
@override@JsonKey() List<String> get route {
  if (_route is EqualUnmodifiableListView) return _route;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_route);
}

/// Pending route: Route changes saved while truck is moving (applied when truck becomes idle)
 final  List<String> _pendingRoute;
/// Pending route: Route changes saved while truck is moving (applied when truck becomes idle)
@override@JsonKey() List<String> get pendingRoute {
  if (_pendingRoute is EqualUnmodifiableListView) return _pendingRoute;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_pendingRoute);
}

/// Current position in the route (index)
@override@JsonKey() final  int currentRouteIndex;
@override@JsonKey() final  TruckStatus status;
/// Current position (x, y) on the grid
@override@JsonKey() final  double currentX;
@override@JsonKey() final  double currentY;
/// Target position (x, y) when traveling
@override@JsonKey() final  double targetX;
@override@JsonKey() final  double targetY;
/// Path waypoints for smooth movement (list of (x, y) positions)
 final  List<({double x, double y})> _path;
/// Path waypoints for smooth movement (list of (x, y) positions)
@override@JsonKey() List<({double x, double y})> get path {
  if (_path is EqualUnmodifiableListView) return _path;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_path);
}

/// Current index in the path
@override@JsonKey() final  int pathIndex;
 final  Map<Product, int> _inventory;
@override@JsonKey() Map<Product, int> get inventory {
  if (_inventory is EqualUnmodifiableMapView) return _inventory;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_inventory);
}

@override@JsonKey() final  bool hasDriver;

/// Create a copy of Truck
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TruckCopyWith<_Truck> get copyWith => __$TruckCopyWithImpl<_Truck>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Truck&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.fuel, fuel) || other.fuel == fuel)&&(identical(other.capacity, capacity) || other.capacity == capacity)&&const DeepCollectionEquality().equals(other._route, _route)&&const DeepCollectionEquality().equals(other._pendingRoute, _pendingRoute)&&(identical(other.currentRouteIndex, currentRouteIndex) || other.currentRouteIndex == currentRouteIndex)&&(identical(other.status, status) || other.status == status)&&(identical(other.currentX, currentX) || other.currentX == currentX)&&(identical(other.currentY, currentY) || other.currentY == currentY)&&(identical(other.targetX, targetX) || other.targetX == targetX)&&(identical(other.targetY, targetY) || other.targetY == targetY)&&const DeepCollectionEquality().equals(other._path, _path)&&(identical(other.pathIndex, pathIndex) || other.pathIndex == pathIndex)&&const DeepCollectionEquality().equals(other._inventory, _inventory)&&(identical(other.hasDriver, hasDriver) || other.hasDriver == hasDriver));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,fuel,capacity,const DeepCollectionEquality().hash(_route),const DeepCollectionEquality().hash(_pendingRoute),currentRouteIndex,status,currentX,currentY,targetX,targetY,const DeepCollectionEquality().hash(_path),pathIndex,const DeepCollectionEquality().hash(_inventory),hasDriver);

@override
String toString() {
  return 'Truck(id: $id, name: $name, fuel: $fuel, capacity: $capacity, route: $route, pendingRoute: $pendingRoute, currentRouteIndex: $currentRouteIndex, status: $status, currentX: $currentX, currentY: $currentY, targetX: $targetX, targetY: $targetY, path: $path, pathIndex: $pathIndex, inventory: $inventory, hasDriver: $hasDriver)';
}


}

/// @nodoc
abstract mixin class _$TruckCopyWith<$Res> implements $TruckCopyWith<$Res> {
  factory _$TruckCopyWith(_Truck value, $Res Function(_Truck) _then) = __$TruckCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, double fuel, int capacity, List<String> route, List<String> pendingRoute, int currentRouteIndex, TruckStatus status, double currentX, double currentY, double targetX, double targetY, List<({double x, double y})> path, int pathIndex, Map<Product, int> inventory, bool hasDriver
});




}
/// @nodoc
class __$TruckCopyWithImpl<$Res>
    implements _$TruckCopyWith<$Res> {
  __$TruckCopyWithImpl(this._self, this._then);

  final _Truck _self;
  final $Res Function(_Truck) _then;

/// Create a copy of Truck
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? fuel = null,Object? capacity = null,Object? route = null,Object? pendingRoute = null,Object? currentRouteIndex = null,Object? status = null,Object? currentX = null,Object? currentY = null,Object? targetX = null,Object? targetY = null,Object? path = null,Object? pathIndex = null,Object? inventory = null,Object? hasDriver = null,}) {
  return _then(_Truck(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,fuel: null == fuel ? _self.fuel : fuel // ignore: cast_nullable_to_non_nullable
as double,capacity: null == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as int,route: null == route ? _self._route : route // ignore: cast_nullable_to_non_nullable
as List<String>,pendingRoute: null == pendingRoute ? _self._pendingRoute : pendingRoute // ignore: cast_nullable_to_non_nullable
as List<String>,currentRouteIndex: null == currentRouteIndex ? _self.currentRouteIndex : currentRouteIndex // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as TruckStatus,currentX: null == currentX ? _self.currentX : currentX // ignore: cast_nullable_to_non_nullable
as double,currentY: null == currentY ? _self.currentY : currentY // ignore: cast_nullable_to_non_nullable
as double,targetX: null == targetX ? _self.targetX : targetX // ignore: cast_nullable_to_non_nullable
as double,targetY: null == targetY ? _self.targetY : targetY // ignore: cast_nullable_to_non_nullable
as double,path: null == path ? _self._path : path // ignore: cast_nullable_to_non_nullable
as List<({double x, double y})>,pathIndex: null == pathIndex ? _self.pathIndex : pathIndex // ignore: cast_nullable_to_non_nullable
as int,inventory: null == inventory ? _self._inventory : inventory // ignore: cast_nullable_to_non_nullable
as Map<Product, int>,hasDriver: null == hasDriver ? _self.hasDriver : hasDriver // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
