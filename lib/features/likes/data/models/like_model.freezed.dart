// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'like_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LikeToggleModel {

 bool get liked; int get likesCount;
/// Create a copy of LikeToggleModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LikeToggleModelCopyWith<LikeToggleModel> get copyWith => _$LikeToggleModelCopyWithImpl<LikeToggleModel>(this as LikeToggleModel, _$identity);

  /// Serializes this LikeToggleModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LikeToggleModel;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LikeToggleModel&&(identical(other.liked, _this.liked) || other.liked == _this.liked)&&(identical(other.likesCount, _this.likesCount) || other.likesCount == _this.likesCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LikeToggleModel;
  return Object.hash(runtimeType,_this.liked,_this.likesCount);
}

@override
String toString() {
  final _this = this as LikeToggleModel;
  return 'LikeToggleModel(liked: ${_this.liked}, likesCount: ${_this.likesCount})';
}


}

/// @nodoc
abstract mixin class $LikeToggleModelCopyWith<$Res>  {
  factory $LikeToggleModelCopyWith(LikeToggleModel value, $Res Function(LikeToggleModel) _then) = _$LikeToggleModelCopyWithImpl;
@useResult
$Res call({
 bool liked, int likesCount
});




}
/// @nodoc
class _$LikeToggleModelCopyWithImpl<$Res>
    implements $LikeToggleModelCopyWith<$Res> {
  _$LikeToggleModelCopyWithImpl(this._self, this._then);

  final LikeToggleModel _self;
  final $Res Function(LikeToggleModel) _then;

/// Create a copy of LikeToggleModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? liked = null,Object? likesCount = null,}) {
  return _then(LikeToggleModel(
liked: null == liked ? _self.liked : liked // ignore: cast_nullable_to_non_nullable
as bool,likesCount: null == likesCount ? _self.likesCount : likesCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [LikeToggleModel].
extension LikeToggleModelPatterns on LikeToggleModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LikeToggleModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LikeToggleModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LikeToggleModel value)  $default,){
final _that = this;
switch (_that) {
case _LikeToggleModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LikeToggleModel value)?  $default,){
final _that = this;
switch (_that) {
case _LikeToggleModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool liked,  int likesCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LikeToggleModel() when $default != null:
return $default(_that.liked,_that.likesCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool liked,  int likesCount)  $default,) {final _that = this;
switch (_that) {
case _LikeToggleModel():
return $default(_that.liked,_that.likesCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool liked,  int likesCount)?  $default,) {final _that = this;
switch (_that) {
case _LikeToggleModel() when $default != null:
return $default(_that.liked,_that.likesCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LikeToggleModel implements LikeToggleModel {
  const _LikeToggleModel({required this.liked, required this.likesCount});
  factory _LikeToggleModel.fromJson(Map<String, dynamic> json) => _$LikeToggleModelFromJson(json);

@override final  bool liked;
@override final  int likesCount;

/// Create a copy of LikeToggleModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LikeToggleModelCopyWith<_LikeToggleModel> get copyWith => __$LikeToggleModelCopyWithImpl<_LikeToggleModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LikeToggleModelToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LikeToggleModel&&(identical(other.liked, liked) || other.liked == liked)&&(identical(other.likesCount, likesCount) || other.likesCount == likesCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,liked,likesCount);
}

@override
String toString() {
    return 'LikeToggleModel(liked: $liked, likesCount: $likesCount)';
}


}

/// @nodoc
abstract mixin class _$LikeToggleModelCopyWith<$Res> implements $LikeToggleModelCopyWith<$Res> {
  factory _$LikeToggleModelCopyWith(_LikeToggleModel value, $Res Function(_LikeToggleModel) _then) = __$LikeToggleModelCopyWithImpl;
@override @useResult
$Res call({
 bool liked, int likesCount
});




}
/// @nodoc
class __$LikeToggleModelCopyWithImpl<$Res>
    implements _$LikeToggleModelCopyWith<$Res> {
  __$LikeToggleModelCopyWithImpl(this._self, this._then);

  final _LikeToggleModel _self;
  final $Res Function(_LikeToggleModel) _then;

/// Create a copy of LikeToggleModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? liked = null,Object? likesCount = null,}) {
  return _then(_LikeToggleModel(
liked: null == liked ? _self.liked : liked // ignore: cast_nullable_to_non_nullable
as bool,likesCount: null == likesCount ? _self.likesCount : likesCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$LikeStatusModel {

 bool get liked;
/// Create a copy of LikeStatusModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LikeStatusModelCopyWith<LikeStatusModel> get copyWith => _$LikeStatusModelCopyWithImpl<LikeStatusModel>(this as LikeStatusModel, _$identity);

  /// Serializes this LikeStatusModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LikeStatusModel;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LikeStatusModel&&(identical(other.liked, _this.liked) || other.liked == _this.liked));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LikeStatusModel;
  return Object.hash(runtimeType,_this.liked);
}

@override
String toString() {
  final _this = this as LikeStatusModel;
  return 'LikeStatusModel(liked: ${_this.liked})';
}


}

/// @nodoc
abstract mixin class $LikeStatusModelCopyWith<$Res>  {
  factory $LikeStatusModelCopyWith(LikeStatusModel value, $Res Function(LikeStatusModel) _then) = _$LikeStatusModelCopyWithImpl;
@useResult
$Res call({
 bool liked
});




}
/// @nodoc
class _$LikeStatusModelCopyWithImpl<$Res>
    implements $LikeStatusModelCopyWith<$Res> {
  _$LikeStatusModelCopyWithImpl(this._self, this._then);

  final LikeStatusModel _self;
  final $Res Function(LikeStatusModel) _then;

/// Create a copy of LikeStatusModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? liked = null,}) {
  return _then(LikeStatusModel(
liked: null == liked ? _self.liked : liked // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [LikeStatusModel].
extension LikeStatusModelPatterns on LikeStatusModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LikeStatusModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LikeStatusModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LikeStatusModel value)  $default,){
final _that = this;
switch (_that) {
case _LikeStatusModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LikeStatusModel value)?  $default,){
final _that = this;
switch (_that) {
case _LikeStatusModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool liked)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LikeStatusModel() when $default != null:
return $default(_that.liked);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool liked)  $default,) {final _that = this;
switch (_that) {
case _LikeStatusModel():
return $default(_that.liked);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool liked)?  $default,) {final _that = this;
switch (_that) {
case _LikeStatusModel() when $default != null:
return $default(_that.liked);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LikeStatusModel implements LikeStatusModel {
  const _LikeStatusModel({required this.liked});
  factory _LikeStatusModel.fromJson(Map<String, dynamic> json) => _$LikeStatusModelFromJson(json);

@override final  bool liked;

/// Create a copy of LikeStatusModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LikeStatusModelCopyWith<_LikeStatusModel> get copyWith => __$LikeStatusModelCopyWithImpl<_LikeStatusModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LikeStatusModelToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LikeStatusModel&&(identical(other.liked, liked) || other.liked == liked));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,liked);
}

@override
String toString() {
    return 'LikeStatusModel(liked: $liked)';
}


}

/// @nodoc
abstract mixin class _$LikeStatusModelCopyWith<$Res> implements $LikeStatusModelCopyWith<$Res> {
  factory _$LikeStatusModelCopyWith(_LikeStatusModel value, $Res Function(_LikeStatusModel) _then) = __$LikeStatusModelCopyWithImpl;
@override @useResult
$Res call({
 bool liked
});




}
/// @nodoc
class __$LikeStatusModelCopyWithImpl<$Res>
    implements _$LikeStatusModelCopyWith<$Res> {
  __$LikeStatusModelCopyWithImpl(this._self, this._then);

  final _LikeStatusModel _self;
  final $Res Function(_LikeStatusModel) _then;

/// Create a copy of LikeStatusModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? liked = null,}) {
  return _then(_LikeStatusModel(
liked: null == liked ? _self.liked : liked // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
