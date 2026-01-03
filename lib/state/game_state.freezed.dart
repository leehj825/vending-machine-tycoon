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
 double? get warehouseRoadY;// Road tile Y coordinate next to warehouse (zone coordinates)
 CityMapState? get cityMapState;// City map layout (grid, buildings, roads)
 List<double> get dailyRevenueHistory;// Last 7 days of revenue
 double get currentDayRevenue;// Revenue accumulated for current day
 Map<Product, int> get productSalesCount;// Global sales count per product
 double get hypeLevel;// Marketing hype level (0.0 to 1.0)
 bool get isRushHour;// Whether Rush Hour is currently active
 double get rushMultiplier;// Sales multiplier during Rush Hour (default 1.0, 10.0 during rush)
 int? get marketingButtonGridX;// Marketing button grid X position (0-9)
 int? get marketingButtonGridY;// Marketing button grid Y position (0-9)
// Tutorial flags - saved with game state
 bool get hasSeenPedestrianTapTutorial; bool get hasSeenBuyTruckTutorial; bool get hasSeenTruckTutorial; bool get hasSeenGoStockTutorial; bool get hasSeenMarketTutorial; bool get hasSeenMoneyExtractionTutorial;// Staff Management - Centralized in HQ
 int get driverPoolCount;// Number of hired drivers (not assigned to trucks)
 int get mechanicCount;// Number of mechanics (auto-repair)
 int get purchasingAgentCount;// Number of purchasing agents (auto-buy stock)
 Map<Product, int> get purchasingAgentTargetInventory;// Target inventory levels for purchasing agent
 bool get isGameOver;
/// Create a copy of GlobalGameState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GlobalGameStateCopyWith<GlobalGameState> get copyWith => _$GlobalGameStateCopyWithImpl<GlobalGameState>(this as GlobalGameState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GlobalGameState&&(identical(other.cash, cash) || other.cash == cash)&&(identical(other.reputation, reputation) || other.reputation == reputation)&&(identical(other.dayCount, dayCount) || other.dayCount == dayCount)&&(identical(other.hourOfDay, hourOfDay) || other.hourOfDay == hourOfDay)&&const DeepCollectionEquality().equals(other.logMessages, logMessages)&&const DeepCollectionEquality().equals(other.machines, machines)&&const DeepCollectionEquality().equals(other.trucks, trucks)&&(identical(other.warehouse, warehouse) || other.warehouse == warehouse)&&(identical(other.warehouseRoadX, warehouseRoadX) || other.warehouseRoadX == warehouseRoadX)&&(identical(other.warehouseRoadY, warehouseRoadY) || other.warehouseRoadY == warehouseRoadY)&&(identical(other.cityMapState, cityMapState) || other.cityMapState == cityMapState)&&const DeepCollectionEquality().equals(other.dailyRevenueHistory, dailyRevenueHistory)&&(identical(other.currentDayRevenue, currentDayRevenue) || other.currentDayRevenue == currentDayRevenue)&&const DeepCollectionEquality().equals(other.productSalesCount, productSalesCount)&&(identical(other.hypeLevel, hypeLevel) || other.hypeLevel == hypeLevel)&&(identical(other.isRushHour, isRushHour) || other.isRushHour == isRushHour)&&(identical(other.rushMultiplier, rushMultiplier) || other.rushMultiplier == rushMultiplier)&&(identical(other.marketingButtonGridX, marketingButtonGridX) || other.marketingButtonGridX == marketingButtonGridX)&&(identical(other.marketingButtonGridY, marketingButtonGridY) || other.marketingButtonGridY == marketingButtonGridY)&&(identical(other.hasSeenPedestrianTapTutorial, hasSeenPedestrianTapTutorial) || other.hasSeenPedestrianTapTutorial == hasSeenPedestrianTapTutorial)&&(identical(other.hasSeenBuyTruckTutorial, hasSeenBuyTruckTutorial) || other.hasSeenBuyTruckTutorial == hasSeenBuyTruckTutorial)&&(identical(other.hasSeenTruckTutorial, hasSeenTruckTutorial) || other.hasSeenTruckTutorial == hasSeenTruckTutorial)&&(identical(other.hasSeenGoStockTutorial, hasSeenGoStockTutorial) || other.hasSeenGoStockTutorial == hasSeenGoStockTutorial)&&(identical(other.hasSeenMarketTutorial, hasSeenMarketTutorial) || other.hasSeenMarketTutorial == hasSeenMarketTutorial)&&(identical(other.hasSeenMoneyExtractionTutorial, hasSeenMoneyExtractionTutorial) || other.hasSeenMoneyExtractionTutorial == hasSeenMoneyExtractionTutorial)&&(identical(other.driverPoolCount, driverPoolCount) || other.driverPoolCount == driverPoolCount)&&(identical(other.mechanicCount, mechanicCount) || other.mechanicCount == mechanicCount)&&(identical(other.purchasingAgentCount, purchasingAgentCount) || other.purchasingAgentCount == purchasingAgentCount)&&const DeepCollectionEquality().equals(other.purchasingAgentTargetInventory, purchasingAgentTargetInventory)&&(identical(other.isGameOver, isGameOver) || other.isGameOver == isGameOver));
}


@override
int get hashCode => Object.hashAll([runtimeType,cash,reputation,dayCount,hourOfDay,const DeepCollectionEquality().hash(logMessages),const DeepCollectionEquality().hash(machines),const DeepCollectionEquality().hash(trucks),warehouse,warehouseRoadX,warehouseRoadY,cityMapState,const DeepCollectionEquality().hash(dailyRevenueHistory),currentDayRevenue,const DeepCollectionEquality().hash(productSalesCount),hypeLevel,isRushHour,rushMultiplier,marketingButtonGridX,marketingButtonGridY,hasSeenPedestrianTapTutorial,hasSeenBuyTruckTutorial,hasSeenTruckTutorial,hasSeenGoStockTutorial,hasSeenMarketTutorial,hasSeenMoneyExtractionTutorial,driverPoolCount,mechanicCount,purchasingAgentCount,const DeepCollectionEquality().hash(purchasingAgentTargetInventory),isGameOver]);

@override
String toString() {
  return 'GlobalGameState(cash: $cash, reputation: $reputation, dayCount: $dayCount, hourOfDay: $hourOfDay, logMessages: $logMessages, machines: $machines, trucks: $trucks, warehouse: $warehouse, warehouseRoadX: $warehouseRoadX, warehouseRoadY: $warehouseRoadY, cityMapState: $cityMapState, dailyRevenueHistory: $dailyRevenueHistory, currentDayRevenue: $currentDayRevenue, productSalesCount: $productSalesCount, hypeLevel: $hypeLevel, isRushHour: $isRushHour, rushMultiplier: $rushMultiplier, marketingButtonGridX: $marketingButtonGridX, marketingButtonGridY: $marketingButtonGridY, hasSeenPedestrianTapTutorial: $hasSeenPedestrianTapTutorial, hasSeenBuyTruckTutorial: $hasSeenBuyTruckTutorial, hasSeenTruckTutorial: $hasSeenTruckTutorial, hasSeenGoStockTutorial: $hasSeenGoStockTutorial, hasSeenMarketTutorial: $hasSeenMarketTutorial, hasSeenMoneyExtractionTutorial: $hasSeenMoneyExtractionTutorial, driverPoolCount: $driverPoolCount, mechanicCount: $mechanicCount, purchasingAgentCount: $purchasingAgentCount, purchasingAgentTargetInventory: $purchasingAgentTargetInventory, isGameOver: $isGameOver)';
}


}

/// @nodoc
abstract mixin class $GlobalGameStateCopyWith<$Res>  {
  factory $GlobalGameStateCopyWith(GlobalGameState value, $Res Function(GlobalGameState) _then) = _$GlobalGameStateCopyWithImpl;
@useResult
$Res call({
 double cash, int reputation, int dayCount, int hourOfDay, List<String> logMessages, List<Machine> machines, List<Truck> trucks, Warehouse warehouse, double? warehouseRoadX, double? warehouseRoadY, CityMapState? cityMapState, List<double> dailyRevenueHistory, double currentDayRevenue, Map<Product, int> productSalesCount, double hypeLevel, bool isRushHour, double rushMultiplier, int? marketingButtonGridX, int? marketingButtonGridY, bool hasSeenPedestrianTapTutorial, bool hasSeenBuyTruckTutorial, bool hasSeenTruckTutorial, bool hasSeenGoStockTutorial, bool hasSeenMarketTutorial, bool hasSeenMoneyExtractionTutorial, int driverPoolCount, int mechanicCount, int purchasingAgentCount, Map<Product, int> purchasingAgentTargetInventory, bool isGameOver
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
@pragma('vm:prefer-inline') @override $Res call({Object? cash = null,Object? reputation = null,Object? dayCount = null,Object? hourOfDay = null,Object? logMessages = null,Object? machines = null,Object? trucks = null,Object? warehouse = null,Object? warehouseRoadX = freezed,Object? warehouseRoadY = freezed,Object? cityMapState = freezed,Object? dailyRevenueHistory = null,Object? currentDayRevenue = null,Object? productSalesCount = null,Object? hypeLevel = null,Object? isRushHour = null,Object? rushMultiplier = null,Object? marketingButtonGridX = freezed,Object? marketingButtonGridY = freezed,Object? hasSeenPedestrianTapTutorial = null,Object? hasSeenBuyTruckTutorial = null,Object? hasSeenTruckTutorial = null,Object? hasSeenGoStockTutorial = null,Object? hasSeenMarketTutorial = null,Object? hasSeenMoneyExtractionTutorial = null,Object? driverPoolCount = null,Object? mechanicCount = null,Object? purchasingAgentCount = null,Object? purchasingAgentTargetInventory = null,Object? isGameOver = null,}) {
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
as double?,cityMapState: freezed == cityMapState ? _self.cityMapState : cityMapState // ignore: cast_nullable_to_non_nullable
as CityMapState?,dailyRevenueHistory: null == dailyRevenueHistory ? _self.dailyRevenueHistory : dailyRevenueHistory // ignore: cast_nullable_to_non_nullable
as List<double>,currentDayRevenue: null == currentDayRevenue ? _self.currentDayRevenue : currentDayRevenue // ignore: cast_nullable_to_non_nullable
as double,productSalesCount: null == productSalesCount ? _self.productSalesCount : productSalesCount // ignore: cast_nullable_to_non_nullable
as Map<Product, int>,hypeLevel: null == hypeLevel ? _self.hypeLevel : hypeLevel // ignore: cast_nullable_to_non_nullable
as double,isRushHour: null == isRushHour ? _self.isRushHour : isRushHour // ignore: cast_nullable_to_non_nullable
as bool,rushMultiplier: null == rushMultiplier ? _self.rushMultiplier : rushMultiplier // ignore: cast_nullable_to_non_nullable
as double,marketingButtonGridX: freezed == marketingButtonGridX ? _self.marketingButtonGridX : marketingButtonGridX // ignore: cast_nullable_to_non_nullable
as int?,marketingButtonGridY: freezed == marketingButtonGridY ? _self.marketingButtonGridY : marketingButtonGridY // ignore: cast_nullable_to_non_nullable
as int?,hasSeenPedestrianTapTutorial: null == hasSeenPedestrianTapTutorial ? _self.hasSeenPedestrianTapTutorial : hasSeenPedestrianTapTutorial // ignore: cast_nullable_to_non_nullable
as bool,hasSeenBuyTruckTutorial: null == hasSeenBuyTruckTutorial ? _self.hasSeenBuyTruckTutorial : hasSeenBuyTruckTutorial // ignore: cast_nullable_to_non_nullable
as bool,hasSeenTruckTutorial: null == hasSeenTruckTutorial ? _self.hasSeenTruckTutorial : hasSeenTruckTutorial // ignore: cast_nullable_to_non_nullable
as bool,hasSeenGoStockTutorial: null == hasSeenGoStockTutorial ? _self.hasSeenGoStockTutorial : hasSeenGoStockTutorial // ignore: cast_nullable_to_non_nullable
as bool,hasSeenMarketTutorial: null == hasSeenMarketTutorial ? _self.hasSeenMarketTutorial : hasSeenMarketTutorial // ignore: cast_nullable_to_non_nullable
as bool,hasSeenMoneyExtractionTutorial: null == hasSeenMoneyExtractionTutorial ? _self.hasSeenMoneyExtractionTutorial : hasSeenMoneyExtractionTutorial // ignore: cast_nullable_to_non_nullable
as bool,driverPoolCount: null == driverPoolCount ? _self.driverPoolCount : driverPoolCount // ignore: cast_nullable_to_non_nullable
as int,mechanicCount: null == mechanicCount ? _self.mechanicCount : mechanicCount // ignore: cast_nullable_to_non_nullable
as int,purchasingAgentCount: null == purchasingAgentCount ? _self.purchasingAgentCount : purchasingAgentCount // ignore: cast_nullable_to_non_nullable
as int,purchasingAgentTargetInventory: null == purchasingAgentTargetInventory ? _self.purchasingAgentTargetInventory : purchasingAgentTargetInventory // ignore: cast_nullable_to_non_nullable
as Map<Product, int>,isGameOver: null == isGameOver ? _self.isGameOver : isGameOver // ignore: cast_nullable_to_non_nullable
as bool,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double cash,  int reputation,  int dayCount,  int hourOfDay,  List<String> logMessages,  List<Machine> machines,  List<Truck> trucks,  Warehouse warehouse,  double? warehouseRoadX,  double? warehouseRoadY,  CityMapState? cityMapState,  List<double> dailyRevenueHistory,  double currentDayRevenue,  Map<Product, int> productSalesCount,  double hypeLevel,  bool isRushHour,  double rushMultiplier,  int? marketingButtonGridX,  int? marketingButtonGridY,  bool hasSeenPedestrianTapTutorial,  bool hasSeenBuyTruckTutorial,  bool hasSeenTruckTutorial,  bool hasSeenGoStockTutorial,  bool hasSeenMarketTutorial,  bool hasSeenMoneyExtractionTutorial,  int driverPoolCount,  int mechanicCount,  int purchasingAgentCount,  Map<Product, int> purchasingAgentTargetInventory,  bool isGameOver)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GlobalGameState() when $default != null:
return $default(_that.cash,_that.reputation,_that.dayCount,_that.hourOfDay,_that.logMessages,_that.machines,_that.trucks,_that.warehouse,_that.warehouseRoadX,_that.warehouseRoadY,_that.cityMapState,_that.dailyRevenueHistory,_that.currentDayRevenue,_that.productSalesCount,_that.hypeLevel,_that.isRushHour,_that.rushMultiplier,_that.marketingButtonGridX,_that.marketingButtonGridY,_that.hasSeenPedestrianTapTutorial,_that.hasSeenBuyTruckTutorial,_that.hasSeenTruckTutorial,_that.hasSeenGoStockTutorial,_that.hasSeenMarketTutorial,_that.hasSeenMoneyExtractionTutorial,_that.driverPoolCount,_that.mechanicCount,_that.purchasingAgentCount,_that.purchasingAgentTargetInventory,_that.isGameOver);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double cash,  int reputation,  int dayCount,  int hourOfDay,  List<String> logMessages,  List<Machine> machines,  List<Truck> trucks,  Warehouse warehouse,  double? warehouseRoadX,  double? warehouseRoadY,  CityMapState? cityMapState,  List<double> dailyRevenueHistory,  double currentDayRevenue,  Map<Product, int> productSalesCount,  double hypeLevel,  bool isRushHour,  double rushMultiplier,  int? marketingButtonGridX,  int? marketingButtonGridY,  bool hasSeenPedestrianTapTutorial,  bool hasSeenBuyTruckTutorial,  bool hasSeenTruckTutorial,  bool hasSeenGoStockTutorial,  bool hasSeenMarketTutorial,  bool hasSeenMoneyExtractionTutorial,  int driverPoolCount,  int mechanicCount,  int purchasingAgentCount,  Map<Product, int> purchasingAgentTargetInventory,  bool isGameOver)  $default,) {final _that = this;
switch (_that) {
case _GlobalGameState():
return $default(_that.cash,_that.reputation,_that.dayCount,_that.hourOfDay,_that.logMessages,_that.machines,_that.trucks,_that.warehouse,_that.warehouseRoadX,_that.warehouseRoadY,_that.cityMapState,_that.dailyRevenueHistory,_that.currentDayRevenue,_that.productSalesCount,_that.hypeLevel,_that.isRushHour,_that.rushMultiplier,_that.marketingButtonGridX,_that.marketingButtonGridY,_that.hasSeenPedestrianTapTutorial,_that.hasSeenBuyTruckTutorial,_that.hasSeenTruckTutorial,_that.hasSeenGoStockTutorial,_that.hasSeenMarketTutorial,_that.hasSeenMoneyExtractionTutorial,_that.driverPoolCount,_that.mechanicCount,_that.purchasingAgentCount,_that.purchasingAgentTargetInventory,_that.isGameOver);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double cash,  int reputation,  int dayCount,  int hourOfDay,  List<String> logMessages,  List<Machine> machines,  List<Truck> trucks,  Warehouse warehouse,  double? warehouseRoadX,  double? warehouseRoadY,  CityMapState? cityMapState,  List<double> dailyRevenueHistory,  double currentDayRevenue,  Map<Product, int> productSalesCount,  double hypeLevel,  bool isRushHour,  double rushMultiplier,  int? marketingButtonGridX,  int? marketingButtonGridY,  bool hasSeenPedestrianTapTutorial,  bool hasSeenBuyTruckTutorial,  bool hasSeenTruckTutorial,  bool hasSeenGoStockTutorial,  bool hasSeenMarketTutorial,  bool hasSeenMoneyExtractionTutorial,  int driverPoolCount,  int mechanicCount,  int purchasingAgentCount,  Map<Product, int> purchasingAgentTargetInventory,  bool isGameOver)?  $default,) {final _that = this;
switch (_that) {
case _GlobalGameState() when $default != null:
return $default(_that.cash,_that.reputation,_that.dayCount,_that.hourOfDay,_that.logMessages,_that.machines,_that.trucks,_that.warehouse,_that.warehouseRoadX,_that.warehouseRoadY,_that.cityMapState,_that.dailyRevenueHistory,_that.currentDayRevenue,_that.productSalesCount,_that.hypeLevel,_that.isRushHour,_that.rushMultiplier,_that.marketingButtonGridX,_that.marketingButtonGridY,_that.hasSeenPedestrianTapTutorial,_that.hasSeenBuyTruckTutorial,_that.hasSeenTruckTutorial,_that.hasSeenGoStockTutorial,_that.hasSeenMarketTutorial,_that.hasSeenMoneyExtractionTutorial,_that.driverPoolCount,_that.mechanicCount,_that.purchasingAgentCount,_that.purchasingAgentTargetInventory,_that.isGameOver);case _:
  return null;

}
}

}

/// @nodoc


class _GlobalGameState extends GlobalGameState {
  const _GlobalGameState({this.cash = 2000.0, this.reputation = 100, this.dayCount = 1, this.hourOfDay = 8, final  List<String> logMessages = const [], final  List<Machine> machines = const [], final  List<Truck> trucks = const [], this.warehouse = const Warehouse(), this.warehouseRoadX = null, this.warehouseRoadY = null, this.cityMapState = null, final  List<double> dailyRevenueHistory = const [], this.currentDayRevenue = 0.0, final  Map<Product, int> productSalesCount = const {}, this.hypeLevel = 0.0, this.isRushHour = false, this.rushMultiplier = 1.0, this.marketingButtonGridX = null, this.marketingButtonGridY = null, this.hasSeenPedestrianTapTutorial = false, this.hasSeenBuyTruckTutorial = false, this.hasSeenTruckTutorial = false, this.hasSeenGoStockTutorial = false, this.hasSeenMarketTutorial = false, this.hasSeenMoneyExtractionTutorial = false, this.driverPoolCount = 0, this.mechanicCount = 0, this.purchasingAgentCount = 0, final  Map<Product, int> purchasingAgentTargetInventory = const {}, this.isGameOver = false}): _logMessages = logMessages,_machines = machines,_trucks = trucks,_dailyRevenueHistory = dailyRevenueHistory,_productSalesCount = productSalesCount,_purchasingAgentTargetInventory = purchasingAgentTargetInventory,super._();
  

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
// Road tile Y coordinate next to warehouse (zone coordinates)
@override@JsonKey() final  CityMapState? cityMapState;
// City map layout (grid, buildings, roads)
 final  List<double> _dailyRevenueHistory;
// City map layout (grid, buildings, roads)
@override@JsonKey() List<double> get dailyRevenueHistory {
  if (_dailyRevenueHistory is EqualUnmodifiableListView) return _dailyRevenueHistory;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_dailyRevenueHistory);
}

// Last 7 days of revenue
@override@JsonKey() final  double currentDayRevenue;
// Revenue accumulated for current day
 final  Map<Product, int> _productSalesCount;
// Revenue accumulated for current day
@override@JsonKey() Map<Product, int> get productSalesCount {
  if (_productSalesCount is EqualUnmodifiableMapView) return _productSalesCount;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_productSalesCount);
}

// Global sales count per product
@override@JsonKey() final  double hypeLevel;
// Marketing hype level (0.0 to 1.0)
@override@JsonKey() final  bool isRushHour;
// Whether Rush Hour is currently active
@override@JsonKey() final  double rushMultiplier;
// Sales multiplier during Rush Hour (default 1.0, 10.0 during rush)
@override@JsonKey() final  int? marketingButtonGridX;
// Marketing button grid X position (0-9)
@override@JsonKey() final  int? marketingButtonGridY;
// Marketing button grid Y position (0-9)
// Tutorial flags - saved with game state
@override@JsonKey() final  bool hasSeenPedestrianTapTutorial;
@override@JsonKey() final  bool hasSeenBuyTruckTutorial;
@override@JsonKey() final  bool hasSeenTruckTutorial;
@override@JsonKey() final  bool hasSeenGoStockTutorial;
@override@JsonKey() final  bool hasSeenMarketTutorial;
@override@JsonKey() final  bool hasSeenMoneyExtractionTutorial;
// Staff Management - Centralized in HQ
@override@JsonKey() final  int driverPoolCount;
// Number of hired drivers (not assigned to trucks)
@override@JsonKey() final  int mechanicCount;
// Number of mechanics (auto-repair)
@override@JsonKey() final  int purchasingAgentCount;
// Number of purchasing agents (auto-buy stock)
 final  Map<Product, int> _purchasingAgentTargetInventory;
// Number of purchasing agents (auto-buy stock)
@override@JsonKey() Map<Product, int> get purchasingAgentTargetInventory {
  if (_purchasingAgentTargetInventory is EqualUnmodifiableMapView) return _purchasingAgentTargetInventory;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_purchasingAgentTargetInventory);
}

// Target inventory levels for purchasing agent
@override@JsonKey() final  bool isGameOver;

/// Create a copy of GlobalGameState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GlobalGameStateCopyWith<_GlobalGameState> get copyWith => __$GlobalGameStateCopyWithImpl<_GlobalGameState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GlobalGameState&&(identical(other.cash, cash) || other.cash == cash)&&(identical(other.reputation, reputation) || other.reputation == reputation)&&(identical(other.dayCount, dayCount) || other.dayCount == dayCount)&&(identical(other.hourOfDay, hourOfDay) || other.hourOfDay == hourOfDay)&&const DeepCollectionEquality().equals(other._logMessages, _logMessages)&&const DeepCollectionEquality().equals(other._machines, _machines)&&const DeepCollectionEquality().equals(other._trucks, _trucks)&&(identical(other.warehouse, warehouse) || other.warehouse == warehouse)&&(identical(other.warehouseRoadX, warehouseRoadX) || other.warehouseRoadX == warehouseRoadX)&&(identical(other.warehouseRoadY, warehouseRoadY) || other.warehouseRoadY == warehouseRoadY)&&(identical(other.cityMapState, cityMapState) || other.cityMapState == cityMapState)&&const DeepCollectionEquality().equals(other._dailyRevenueHistory, _dailyRevenueHistory)&&(identical(other.currentDayRevenue, currentDayRevenue) || other.currentDayRevenue == currentDayRevenue)&&const DeepCollectionEquality().equals(other._productSalesCount, _productSalesCount)&&(identical(other.hypeLevel, hypeLevel) || other.hypeLevel == hypeLevel)&&(identical(other.isRushHour, isRushHour) || other.isRushHour == isRushHour)&&(identical(other.rushMultiplier, rushMultiplier) || other.rushMultiplier == rushMultiplier)&&(identical(other.marketingButtonGridX, marketingButtonGridX) || other.marketingButtonGridX == marketingButtonGridX)&&(identical(other.marketingButtonGridY, marketingButtonGridY) || other.marketingButtonGridY == marketingButtonGridY)&&(identical(other.hasSeenPedestrianTapTutorial, hasSeenPedestrianTapTutorial) || other.hasSeenPedestrianTapTutorial == hasSeenPedestrianTapTutorial)&&(identical(other.hasSeenBuyTruckTutorial, hasSeenBuyTruckTutorial) || other.hasSeenBuyTruckTutorial == hasSeenBuyTruckTutorial)&&(identical(other.hasSeenTruckTutorial, hasSeenTruckTutorial) || other.hasSeenTruckTutorial == hasSeenTruckTutorial)&&(identical(other.hasSeenGoStockTutorial, hasSeenGoStockTutorial) || other.hasSeenGoStockTutorial == hasSeenGoStockTutorial)&&(identical(other.hasSeenMarketTutorial, hasSeenMarketTutorial) || other.hasSeenMarketTutorial == hasSeenMarketTutorial)&&(identical(other.hasSeenMoneyExtractionTutorial, hasSeenMoneyExtractionTutorial) || other.hasSeenMoneyExtractionTutorial == hasSeenMoneyExtractionTutorial)&&(identical(other.driverPoolCount, driverPoolCount) || other.driverPoolCount == driverPoolCount)&&(identical(other.mechanicCount, mechanicCount) || other.mechanicCount == mechanicCount)&&(identical(other.purchasingAgentCount, purchasingAgentCount) || other.purchasingAgentCount == purchasingAgentCount)&&const DeepCollectionEquality().equals(other._purchasingAgentTargetInventory, _purchasingAgentTargetInventory)&&(identical(other.isGameOver, isGameOver) || other.isGameOver == isGameOver));
}


@override
int get hashCode => Object.hashAll([runtimeType,cash,reputation,dayCount,hourOfDay,const DeepCollectionEquality().hash(_logMessages),const DeepCollectionEquality().hash(_machines),const DeepCollectionEquality().hash(_trucks),warehouse,warehouseRoadX,warehouseRoadY,cityMapState,const DeepCollectionEquality().hash(_dailyRevenueHistory),currentDayRevenue,const DeepCollectionEquality().hash(_productSalesCount),hypeLevel,isRushHour,rushMultiplier,marketingButtonGridX,marketingButtonGridY,hasSeenPedestrianTapTutorial,hasSeenBuyTruckTutorial,hasSeenTruckTutorial,hasSeenGoStockTutorial,hasSeenMarketTutorial,hasSeenMoneyExtractionTutorial,driverPoolCount,mechanicCount,purchasingAgentCount,const DeepCollectionEquality().hash(_purchasingAgentTargetInventory),isGameOver]);

@override
String toString() {
  return 'GlobalGameState(cash: $cash, reputation: $reputation, dayCount: $dayCount, hourOfDay: $hourOfDay, logMessages: $logMessages, machines: $machines, trucks: $trucks, warehouse: $warehouse, warehouseRoadX: $warehouseRoadX, warehouseRoadY: $warehouseRoadY, cityMapState: $cityMapState, dailyRevenueHistory: $dailyRevenueHistory, currentDayRevenue: $currentDayRevenue, productSalesCount: $productSalesCount, hypeLevel: $hypeLevel, isRushHour: $isRushHour, rushMultiplier: $rushMultiplier, marketingButtonGridX: $marketingButtonGridX, marketingButtonGridY: $marketingButtonGridY, hasSeenPedestrianTapTutorial: $hasSeenPedestrianTapTutorial, hasSeenBuyTruckTutorial: $hasSeenBuyTruckTutorial, hasSeenTruckTutorial: $hasSeenTruckTutorial, hasSeenGoStockTutorial: $hasSeenGoStockTutorial, hasSeenMarketTutorial: $hasSeenMarketTutorial, hasSeenMoneyExtractionTutorial: $hasSeenMoneyExtractionTutorial, driverPoolCount: $driverPoolCount, mechanicCount: $mechanicCount, purchasingAgentCount: $purchasingAgentCount, purchasingAgentTargetInventory: $purchasingAgentTargetInventory, isGameOver: $isGameOver)';
}


}

/// @nodoc
abstract mixin class _$GlobalGameStateCopyWith<$Res> implements $GlobalGameStateCopyWith<$Res> {
  factory _$GlobalGameStateCopyWith(_GlobalGameState value, $Res Function(_GlobalGameState) _then) = __$GlobalGameStateCopyWithImpl;
@override @useResult
$Res call({
 double cash, int reputation, int dayCount, int hourOfDay, List<String> logMessages, List<Machine> machines, List<Truck> trucks, Warehouse warehouse, double? warehouseRoadX, double? warehouseRoadY, CityMapState? cityMapState, List<double> dailyRevenueHistory, double currentDayRevenue, Map<Product, int> productSalesCount, double hypeLevel, bool isRushHour, double rushMultiplier, int? marketingButtonGridX, int? marketingButtonGridY, bool hasSeenPedestrianTapTutorial, bool hasSeenBuyTruckTutorial, bool hasSeenTruckTutorial, bool hasSeenGoStockTutorial, bool hasSeenMarketTutorial, bool hasSeenMoneyExtractionTutorial, int driverPoolCount, int mechanicCount, int purchasingAgentCount, Map<Product, int> purchasingAgentTargetInventory, bool isGameOver
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
@override @pragma('vm:prefer-inline') $Res call({Object? cash = null,Object? reputation = null,Object? dayCount = null,Object? hourOfDay = null,Object? logMessages = null,Object? machines = null,Object? trucks = null,Object? warehouse = null,Object? warehouseRoadX = freezed,Object? warehouseRoadY = freezed,Object? cityMapState = freezed,Object? dailyRevenueHistory = null,Object? currentDayRevenue = null,Object? productSalesCount = null,Object? hypeLevel = null,Object? isRushHour = null,Object? rushMultiplier = null,Object? marketingButtonGridX = freezed,Object? marketingButtonGridY = freezed,Object? hasSeenPedestrianTapTutorial = null,Object? hasSeenBuyTruckTutorial = null,Object? hasSeenTruckTutorial = null,Object? hasSeenGoStockTutorial = null,Object? hasSeenMarketTutorial = null,Object? hasSeenMoneyExtractionTutorial = null,Object? driverPoolCount = null,Object? mechanicCount = null,Object? purchasingAgentCount = null,Object? purchasingAgentTargetInventory = null,Object? isGameOver = null,}) {
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
as double?,cityMapState: freezed == cityMapState ? _self.cityMapState : cityMapState // ignore: cast_nullable_to_non_nullable
as CityMapState?,dailyRevenueHistory: null == dailyRevenueHistory ? _self._dailyRevenueHistory : dailyRevenueHistory // ignore: cast_nullable_to_non_nullable
as List<double>,currentDayRevenue: null == currentDayRevenue ? _self.currentDayRevenue : currentDayRevenue // ignore: cast_nullable_to_non_nullable
as double,productSalesCount: null == productSalesCount ? _self._productSalesCount : productSalesCount // ignore: cast_nullable_to_non_nullable
as Map<Product, int>,hypeLevel: null == hypeLevel ? _self.hypeLevel : hypeLevel // ignore: cast_nullable_to_non_nullable
as double,isRushHour: null == isRushHour ? _self.isRushHour : isRushHour // ignore: cast_nullable_to_non_nullable
as bool,rushMultiplier: null == rushMultiplier ? _self.rushMultiplier : rushMultiplier // ignore: cast_nullable_to_non_nullable
as double,marketingButtonGridX: freezed == marketingButtonGridX ? _self.marketingButtonGridX : marketingButtonGridX // ignore: cast_nullable_to_non_nullable
as int?,marketingButtonGridY: freezed == marketingButtonGridY ? _self.marketingButtonGridY : marketingButtonGridY // ignore: cast_nullable_to_non_nullable
as int?,hasSeenPedestrianTapTutorial: null == hasSeenPedestrianTapTutorial ? _self.hasSeenPedestrianTapTutorial : hasSeenPedestrianTapTutorial // ignore: cast_nullable_to_non_nullable
as bool,hasSeenBuyTruckTutorial: null == hasSeenBuyTruckTutorial ? _self.hasSeenBuyTruckTutorial : hasSeenBuyTruckTutorial // ignore: cast_nullable_to_non_nullable
as bool,hasSeenTruckTutorial: null == hasSeenTruckTutorial ? _self.hasSeenTruckTutorial : hasSeenTruckTutorial // ignore: cast_nullable_to_non_nullable
as bool,hasSeenGoStockTutorial: null == hasSeenGoStockTutorial ? _self.hasSeenGoStockTutorial : hasSeenGoStockTutorial // ignore: cast_nullable_to_non_nullable
as bool,hasSeenMarketTutorial: null == hasSeenMarketTutorial ? _self.hasSeenMarketTutorial : hasSeenMarketTutorial // ignore: cast_nullable_to_non_nullable
as bool,hasSeenMoneyExtractionTutorial: null == hasSeenMoneyExtractionTutorial ? _self.hasSeenMoneyExtractionTutorial : hasSeenMoneyExtractionTutorial // ignore: cast_nullable_to_non_nullable
as bool,driverPoolCount: null == driverPoolCount ? _self.driverPoolCount : driverPoolCount // ignore: cast_nullable_to_non_nullable
as int,mechanicCount: null == mechanicCount ? _self.mechanicCount : mechanicCount // ignore: cast_nullable_to_non_nullable
as int,purchasingAgentCount: null == purchasingAgentCount ? _self.purchasingAgentCount : purchasingAgentCount // ignore: cast_nullable_to_non_nullable
as int,purchasingAgentTargetInventory: null == purchasingAgentTargetInventory ? _self._purchasingAgentTargetInventory : purchasingAgentTargetInventory // ignore: cast_nullable_to_non_nullable
as Map<Product, int>,isGameOver: null == isGameOver ? _self.isGameOver : isGameOver // ignore: cast_nullable_to_non_nullable
as bool,
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
