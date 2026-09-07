// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'like.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Like {

/// Id of the `User` who liked the post.
 String get userId;/// Id of the `Post` that was liked.
 String get postId; DateTime get createdAt;
/// Create a copy of Like
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LikeCopyWith<Like> get copyWith => _$LikeCopyWithImpl<Like>(this as Like, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Like;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Like&&(identical(other.userId, _this.userId) || other.userId == _this.userId)&&(identical(other.postId, _this.postId) || other.postId == _this.postId)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt));
}


@override
int get hashCode {
  final _this = this as Like;
  return Object.hash(runtimeType,_this.userId,_this.postId,_this.createdAt);
}

@override
String toString() {
  final _this = this as Like;
  return 'Like(userId: ${_this.userId}, postId: ${_this.postId}, createdAt: ${_this.createdAt})';
}


}

/// @nodoc
abstract mixin class $LikeCopyWith<$Res>  {
  factory $LikeCopyWith(Like value, $Res Function(Like) _then) = _$LikeCopyWithImpl;
@useResult
$Res call({
 String userId, String postId, DateTime createdAt
});




}
/// @nodoc
class _$LikeCopyWithImpl<$Res>
    implements $LikeCopyWith<$Res> {
  _$LikeCopyWithImpl(this._self, this._then);

  final Like _self;
  final $Res Function(Like) _then;

/// Create a copy of Like
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userId = null,Object? postId = null,Object? createdAt = null,}) {
  return _then(Like(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,postId: null == postId ? _self.postId : postId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [Like].
extension LikePatterns on Like {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Like value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Like() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Like value)  $default,){
final _that = this;
switch (_that) {
case _Like():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Like value)?  $default,){
final _that = this;
switch (_that) {
case _Like() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String userId,  String postId,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Like() when $default != null:
return $default(_that.userId,_that.postId,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String userId,  String postId,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _Like():
return $default(_that.userId,_that.postId,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String userId,  String postId,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _Like() when $default != null:
return $default(_that.userId,_that.postId,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc


class _Like implements Like {
  const _Like({required this.userId, required this.postId, required this.createdAt});
  

/// Id of the `User` who liked the post.
@override final  String userId;
/// Id of the `Post` that was liked.
@override final  String postId;
@override final  DateTime createdAt;

/// Create a copy of Like
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LikeCopyWith<_Like> get copyWith => __$LikeCopyWithImpl<_Like>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Like&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.postId, postId) || other.postId == postId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,userId,postId,createdAt);
}

@override
String toString() {
    return 'Like(userId: $userId, postId: $postId, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$LikeCopyWith<$Res> implements $LikeCopyWith<$Res> {
  factory _$LikeCopyWith(_Like value, $Res Function(_Like) _then) = __$LikeCopyWithImpl;
@override @useResult
$Res call({
 String userId, String postId, DateTime createdAt
});




}
/// @nodoc
class __$LikeCopyWithImpl<$Res>
    implements _$LikeCopyWith<$Res> {
  __$LikeCopyWithImpl(this._self, this._then);

  final _Like _self;
  final $Res Function(_Like) _then;

/// Create a copy of Like
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? postId = null,Object? createdAt = null,}) {
  return _then(_Like(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,postId: null == postId ? _self.postId : postId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
