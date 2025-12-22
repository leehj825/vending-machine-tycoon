// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'game_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$GlobalGameState {

 double get cash;// Starting cash: $2000
 int get reputation;// Starting reputation: 100
 int get dayCount;// Current day number
 int get hourOfDay;// Current hour (0-23), starts at 8 AM
 List<String> get logMessages;// Game event log
 List<Machine> get machines; List<Truck> get trucks; Warehouse get warehouse; double? get warehouseRoadX;// Road tile X coordinate next to warehouse (zone coordinates)
 double? get warehouseRoadY;
/// Create a copy of GlobalGameState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GlobalGameStateCopyWith<GlobalGameState> get copyWith => _$GlobalGameStateCopyWithImpl<GlobalGameState>(this as GlobalGameState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GlobalGameState&&(identical(other.cash, cash) || other.cash == cash)&&(identical(other.reputation, reputation) || other.reputation == reputation)&&(identical(other.dayCount, dayCount) || other.dayCount == dayCount)&&(identical(other.hourOfDay, hourOfDay) || other.hourOfDay == hourOfDay)&&const DeepCollectionEquality().equals(other.logMessages, logMessages)&&const DeepCollectionEquality().equals(other.machines, machines)&&const DeepCollectionEquality().equals(other.trucks, trucks)&&(identical(other.warehouse, warehouse) || other.warehouse == warehouse)&&(identical(other.warehouseRoadX, warehouseRoadX) || other.warehouseRoadX == warehouseRoadX)&&(identical(other.warehouseRoadY, warehouseRoadY) || other.warehouseRoadY == warehouseRoadY));
}


@override
int get hashCode => Object.hash(runtimeType,cash,reputation,dayCount,hourOfDay,const DeepCollectionEquality().hash(logMessages),const DeepCollectionEquality().hash(machines),const DeepCollectionEquality().hash(trucks),warehouse,warehouseRoadX,warehouseRoadY);

@override
String toString() {
  return 'GlobalGameState(cash: $cash, reputation: $reputation, dayCount: $dayCount, hourOfDay: $hourOfDay, logMessages: $logMessages, machines: $machines, trucks: $trucks, warehouse: $warehouse, warehouseRoadX: $warehouseRoadX, warehouseRoadY: $warehouseRoadY)';
}


}

/// @nodoc
abstract mixin class $GlobalGameStateCopyWith<$Res>  {
  factory $GlobalGameStateCopyWith(GlobalGameState value, $Res Function(GlobalGameState) _then) = _$GlobalGameStateCopyWithImpl;
@useResult
$Res call({
 double cash, int reputation, int dayCount, int hourOfDay, List<String> logMessages, List<Machine> machines, List<Truck> trucks, Warehouse warehouse, double? warehouseRoadX, double? warehouseRoadY
});


$WarehouseCopyWith<$Res> get warehouse;

}
/// @nodoc
class _$GlobalGameStateCopyWithImpl<$Res>
    implements $GlobalGameStateCopyWith<$Res> {
  _$GlobalGameStateCopyWithImpl(this._self, this._then);

  final GlobalGameState _self;
  final $Res Function(GlobalGameState) _then;

/// Create a copy of GlobalGameState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? cash = null,Object? reputation = null,Object? dayCount = null,Object? hourOfDay = null,Object? logMessages = null,Object? machines = null,Object? trucks = null,Object? warehouse = null,Object? warehouseRoadX = freezed,Object? warehouseRoadY = freezed,}) {
  return _then(_self.copyWith(
cash: null == cash ? _self.cash : cash // ignore: cast_nullable_to_non_nullable
as double,reputation: null == reputation ? _self.reputation : reputation // ignore: cast_nullable_to_non_nullable
as int,dayCount: null == dayCount ? _self.dayCount : dayCount // ignore: cast_nullable_to_non_nullable
as int,hourOfDay: null == hourOfDay ? _self.hourOfDay : hourOfDay // ignore: cast_nullable_to_non_nullable
as int,logMessages: null == logMessages ? _self.logMessages : logMessages // ignore: cast_nullable_to_non_nullable
as List<String>,machines: null == machines ? _self.machines : machines // ignore: cast_nullable_to_non_nullable
as List<Machine>,trucks: null == trucks ? _self.trucks : trucks // ignore: cast_nullable_to_non_nullable
as List<Truck>,warehouse: null == warehouse ? _self.warehouse : warehouse // ignore: cast_nullable_to_non_nullable
as Warehouse,warehouseRoadX: freezed == warehouseRoadX ? _self.warehouseRoadX : warehouseRoadX // ignore: cast_nullable_to_non_nullable
as double?,warehouseRoadY: freezed == warehouseRoadY ? _self.warehouseRoadY : warehouseRoadY // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}
/// Create a copy of GlobalGameState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WarehouseCopyWith<$Res> get warehouse {
  
  return $WarehouseCopyWith<$Res>(_self.warehouse, (value) {
    return _then(_self.copyWith(warehouse: value));
  });
}
}


/// Adds pattern-matching-related methods to [GlobalGameState].
extension GlobalGameStatePatterns on GlobalGameState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GlobalGameState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GlobalGameState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GlobalGameState value)  $default,){
final _that = this;
switch (_that) {
case _GlobalGameState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GlobalGameState value)?  $default,){
final _that = this;
switch (_that) {
case _GlobalGameState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double cash,  int reputation,  int dayCount,  int hourOfDay,  List<String> logMessages,  List<Machine> machines,  List<Truck> trucks,  Warehouse warehouse,  double? warehouseRoadX,  double? warehouseRoadY)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GlobalGameState() when $default != null:
return $default(_that.cash,_that.reputation,_that.dayCount,_that.hourOfDay,_that.logMessages,_that.machines,_that.trucks,_that.warehouse,_that.warehouseRoadX,_that.warehouseRoadY);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double cash,  int reputation,  int dayCount,  int hourOfDay,  List<String> logMessages,  List<Machine> machines,  List<Truck> trucks,  Warehouse warehouse,  double? warehouseRoadX,  double? warehouseRoadY)  $default,) {final _that = this;
switch (_that) {
case _GlobalGameState():
return $default(_that.cash,_that.reputation,_that.dayCount,_that.hourOfDay,_that.logMessages,_that.machines,_that.trucks,_that.warehouse,_that.warehouseRoadX,_that.warehouseRoadY);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double cash,  int reputation,  int dayCount,  int hourOfDay,  List<String> logMessages,  List<Machine> machines,  List<Truck> trucks,  Warehouse warehouse,  double? warehouseRoadX,  double? warehouseRoadY)?  $default,) {final _that = this;
switch (_that) {
case _GlobalGameState() when $default != null:
return $default(_that.cash,_that.reputation,_that.dayCount,_that.hourOfDay,_that.logMessages,_that.machines,_that.trucks,_that.warehouse,_that.warehouseRoadX,_that.warehouseRoadY);case _:
  return null;

}
}

}

/// @nodoc


class _GlobalGameState extends GlobalGameState {
  const _GlobalGameState({this.cash = 2000.0, this.reputation = 100, this.dayCount = 1, this.hourOfDay = 8, final  List<String> logMessages = const [], final  List<Machine> machines = const [], final  List<Truck> trucks = const [], this.warehouse = const Warehouse(), this.warehouseRoadX = null, this.warehouseRoadY = null}): _logMessages = logMessages,_machines = machines,_trucks = trucks,super._();
  

@override@JsonKey() final  double cash;
// Starting cash: $2000
@override@JsonKey() final  int reputation;
// Starting reputation: 100
@override@JsonKey() final  int dayCount;
// Current day number
@override@JsonKey() final  int hourOfDay;
// Current hour (0-23), starts at 8 AM
 final  List<String> _logMessages;
// Current hour (0-23), starts at 8 AM
@override@JsonKey() List<String> get logMessages {
  if (_logMessages is EqualUnmodifiableListView) return _logMessages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_logMessages);
}

// Game event log
 final  List<Machine> _machines;
// Game event log
@override@JsonKey() List<Machine> get machines {
  if (_machines is EqualUnmodifiableListView) return _machines;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_machines);
}

 final  List<Truck> _trucks;
@override@JsonKey() List<Truck> get trucks {
  if (_trucks is EqualUnmodifiableListView) return _trucks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_trucks);
}

@override@JsonKey() final  Warehouse warehouse;
@override@JsonKey() final  double? warehouseRoadX;
// Road tile X coordinate next to warehouse (zone coordinates)
@override@JsonKey() final  double? warehouseRoadY;

/// Create a copy of GlobalGameState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GlobalGameStateCopyWith<_GlobalGameState> get copyWith => __$GlobalGameStateCopyWithImpl<_GlobalGameState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GlobalGameState&&(identical(other.cash, cash) || other.cash == cash)&&(identical(other.reputation, reputation) || other.reputation == reputation)&&(identical(other.dayCount, dayCount) || other.dayCount == dayCount)&&(identical(other.hourOfDay, hourOfDay) || other.hourOfDay == hourOfDay)&&const DeepCollectionEquality().equals(other._logMessages, _logMessages)&&const DeepCollectionEquality().equals(other._machines, _machines)&&const DeepCollectionEquality().equals(other._trucks, _trucks)&&(identical(other.warehouse, warehouse) || other.warehouse == warehouse)&&(identical(other.warehouseRoadX, warehouseRoadX) || other.warehouseRoadX == warehouseRoadX)&&(identical(other.warehouseRoadY, warehouseRoadY) || other.warehouseRoadY == warehouseRoadY));
}


@override
int get hashCode => Object.hash(runtimeType,cash,reputation,dayCount,hourOfDay,const DeepCollectionEquality().hash(_logMessages),const DeepCollectionEquality().hash(_machines),const DeepCollectionEquality().hash(_trucks),warehouse,warehouseRoadX,warehouseRoadY);

@override
String toString() {
  return 'GlobalGameState(cash: $cash, reputation: $reputation, dayCount: $dayCount, hourOfDay: $hourOfDay, logMessages: $logMessages, machines: $machines, trucks: $trucks, warehouse: $warehouse, warehouseRoadX: $warehouseRoadX, warehouseRoadY: $warehouseRoadY)';
}


}

/// @nodoc
abstract mixin class _$GlobalGameStateCopyWith<$Res> implements $GlobalGameStateCopyWith<$Res> {
  factory _$GlobalGameStateCopyWith(_GlobalGameState value, $Res Function(_GlobalGameState) _then) = __$GlobalGameStateCopyWithImpl;
@override @useResult
$Res call({
 double cash, int reputation, int dayCount, int hourOfDay, List<String> logMessages, List<Machine> machines, List<Truck> trucks, Warehouse warehouse, double? warehouseRoadX, double? warehouseRoadY
});


@override $WarehouseCopyWith<$Res> get warehouse;

}
/// @nodoc
class __$GlobalGameStateCopyWithImpl<$Res>
    implements _$GlobalGameStateCopyWith<$Res> {
  __$GlobalGameStateCopyWithImpl(this._self, this._then);

  final _GlobalGameState _self;
  final $Res Function(_GlobalGameState) _then;

/// Create a copy of GlobalGameState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? cash = null,Object? reputation = null,Object? dayCount = null,Object? hourOfDay = null,Object? logMessages = null,Object? machines = null,Object? trucks = null,Object? warehouse = null,Object? warehouseRoadX = freezed,Object? warehouseRoadY = freezed,}) {
  return _then(_GlobalGameState(
cash: null == cash ? _self.cash : cash // ignore: cast_nullable_to_non_nullable
as double,reputation: null == reputation ? _self.reputation : reputation // ignore: cast_nullable_to_non_nullable
as int,dayCount: null == dayCount ? _self.dayCount : dayCount // ignore: cast_nullable_to_non_nullable
as int,hourOfDay: null == hourOfDay ? _self.hourOfDay : hourOfDay // ignore: cast_nullable_to_non_nullable
as int,logMessages: null == logMessages ? _self._logMessages : logMessages // ignore: cast_nullable_to_non_nullable
as List<String>,machines: null == machines ? _self._machines : machines // ignore: cast_nullable_to_non_nullable
as List<Machine>,trucks: null == trucks ? _self._trucks : trucks // ignore: cast_nullable_to_non_nullable
as List<Truck>,warehouse: null == warehouse ? _self.warehouse : warehouse // ignore: cast_nullable_to_non_nullable
as Warehouse,warehouseRoadX: freezed == warehouseRoadX ? _self.warehouseRoadX : warehouseRoadX // ignore: cast_nullable_to_non_nullable
as double?,warehouseRoadY: freezed == warehouseRoadY ? _self.warehouseRoadY : warehouseRoadY // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

/// Create a copy of GlobalGameState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WarehouseCopyWith<$Res> get warehouse {
  
  return $WarehouseCopyWith<$Res>(_self.warehouse, (value) {
    return _then(_self.copyWith(warehouse: value));
  });
}
}

// dart format on
