// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'game_log_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$GameLogEntry {

 LogType get type; GameTime get timestamp; Map<String, dynamic> get data; String get message;
/// Create a copy of GameLogEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GameLogEntryCopyWith<GameLogEntry> get copyWith => _$GameLogEntryCopyWithImpl<GameLogEntry>(this as GameLogEntry, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GameLogEntry&&(identical(other.type, type) || other.type == type)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&const DeepCollectionEquality().equals(other.data, data)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,type,timestamp,const DeepCollectionEquality().hash(data),message);

@override
String toString() {
  return 'GameLogEntry(type: $type, timestamp: $timestamp, data: $data, message: $message)';
}


}

/// @nodoc
abstract mixin class $GameLogEntryCopyWith<$Res>  {
  factory $GameLogEntryCopyWith(GameLogEntry value, $Res Function(GameLogEntry) _then) = _$GameLogEntryCopyWithImpl;
@useResult
$Res call({
 LogType type, GameTime timestamp, Map<String, dynamic> data, String message
});




}
/// @nodoc
class _$GameLogEntryCopyWithImpl<$Res>
    implements $GameLogEntryCopyWith<$Res> {
  _$GameLogEntryCopyWithImpl(this._self, this._then);

  final GameLogEntry _self;
  final $Res Function(GameLogEntry) _then;

/// Create a copy of GameLogEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? timestamp = null,Object? data = null,Object? message = null,}) {
  return _then(_self.copyWith(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as LogType,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as GameTime,data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [GameLogEntry].
extension GameLogEntryPatterns on GameLogEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GameLogEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GameLogEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GameLogEntry value)  $default,){
final _that = this;
switch (_that) {
case _GameLogEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GameLogEntry value)?  $default,){
final _that = this;
switch (_that) {
case _GameLogEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LogType type,  GameTime timestamp,  Map<String, dynamic> data,  String message)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GameLogEntry() when $default != null:
return $default(_that.type,_that.timestamp,_that.data,_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LogType type,  GameTime timestamp,  Map<String, dynamic> data,  String message)  $default,) {final _that = this;
switch (_that) {
case _GameLogEntry():
return $default(_that.type,_that.timestamp,_that.data,_that.message);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LogType type,  GameTime timestamp,  Map<String, dynamic> data,  String message)?  $default,) {final _that = this;
switch (_that) {
case _GameLogEntry() when $default != null:
return $default(_that.type,_that.timestamp,_that.data,_that.message);case _:
  return null;

}
}

}

/// @nodoc


class _GameLogEntry extends GameLogEntry {
  const _GameLogEntry({required this.type, required this.timestamp, final  Map<String, dynamic> data = const {}, this.message = ''}): _data = data,super._();


@override final  LogType type;
@override final  GameTime timestamp;
 final  Map<String, dynamic> _data;
@override@JsonKey() Map<String, dynamic> get data {
  if (_data is EqualUnmodifiableMapView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_data);
}

@override@JsonKey() final  String message;

/// Create a copy of GameLogEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GameLogEntryCopyWith<_GameLogEntry> get copyWith => __$GameLogEntryCopyWithImpl<_GameLogEntry>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GameLogEntry&&(identical(other.type, type) || other.type == type)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&const DeepCollectionEquality().equals(other._data, _data)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,type,timestamp,const DeepCollectionEquality().hash(_data),message);

@override
String toString() {
  return 'GameLogEntry(type: $type, timestamp: $timestamp, data: $data, message: $message)';
}


}

/// @nodoc
abstract mixin class _$GameLogEntryCopyWith<$Res> implements $GameLogEntryCopyWith<$Res> {
  factory _$GameLogEntryCopyWith(_GameLogEntry value, $Res Function(_GameLogEntry) _then) = __$GameLogEntryCopyWithImpl;
@override @useResult
$Res call({
 LogType type, GameTime timestamp, Map<String, dynamic> data, String message
});




}
/// @nodoc
class __$GameLogEntryCopyWithImpl<$Res>
    implements _$GameLogEntryCopyWith<$Res> {
  __$GameLogEntryCopyWithImpl(this._self, this._then);

  final _GameLogEntry _self;
  final $Res Function(_GameLogEntry) _then;

/// Create a copy of GameLogEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? timestamp = null,Object? data = null,Object? message = null,}) {
  return _then(_GameLogEntry(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as LogType,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as GameTime,data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
