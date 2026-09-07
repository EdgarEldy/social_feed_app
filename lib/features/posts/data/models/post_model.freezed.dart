// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'post_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PostModel {

 String get id; String get authorId; String get authorName; String? get authorPhotoUrl; String get title; String get content; String? get imageUrl; DateTime get createdAt; DateTime? get updatedAt; int get commentsCount; int get likesCount; bool get isLikedByMe;
/// Create a copy of PostModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PostModelCopyWith<PostModel> get copyWith => _$PostModelCopyWithImpl<PostModel>(this as PostModel, _$identity);

  /// Serializes this PostModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PostModel;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PostModel&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.authorId, _this.authorId) || other.authorId == _this.authorId)&&(identical(other.authorName, _this.authorName) || other.authorName == _this.authorName)&&(identical(other.authorPhotoUrl, _this.authorPhotoUrl) || other.authorPhotoUrl == _this.authorPhotoUrl)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.content, _this.content) || other.content == _this.content)&&(identical(other.imageUrl, _this.imageUrl) || other.imageUrl == _this.imageUrl)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.commentsCount, _this.commentsCount) || other.commentsCount == _this.commentsCount)&&(identical(other.likesCount, _this.likesCount) || other.likesCount == _this.likesCount)&&(identical(other.isLikedByMe, _this.isLikedByMe) || other.isLikedByMe == _this.isLikedByMe));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PostModel;
  return Object.hash(runtimeType,_this.id,_this.authorId,_this.authorName,_this.authorPhotoUrl,_this.title,_this.content,_this.imageUrl,_this.createdAt,_this.updatedAt,_this.commentsCount,_this.likesCount,_this.isLikedByMe);
}

@override
String toString() {
  final _this = this as PostModel;
  return 'PostModel(id: ${_this.id}, authorId: ${_this.authorId}, authorName: ${_this.authorName}, authorPhotoUrl: ${_this.authorPhotoUrl}, title: ${_this.title}, content: ${_this.content}, imageUrl: ${_this.imageUrl}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt}, commentsCount: ${_this.commentsCount}, likesCount: ${_this.likesCount}, isLikedByMe: ${_this.isLikedByMe})';
}


}

/// @nodoc
abstract mixin class $PostModelCopyWith<$Res>  {
  factory $PostModelCopyWith(PostModel value, $Res Function(PostModel) _then) = _$PostModelCopyWithImpl;
@useResult
$Res call({
 String id, String authorId, String authorName, String? authorPhotoUrl, String title, String content, String? imageUrl, DateTime createdAt, DateTime? updatedAt, int commentsCount, int likesCount, bool isLikedByMe
});




}
/// @nodoc
class _$PostModelCopyWithImpl<$Res>
    implements $PostModelCopyWith<$Res> {
  _$PostModelCopyWithImpl(this._self, this._then);

  final PostModel _self;
  final $Res Function(PostModel) _then;

/// Create a copy of PostModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? authorId = null,Object? authorName = null,Object? authorPhotoUrl = freezed,Object? title = null,Object? content = null,Object? imageUrl = freezed,Object? createdAt = null,Object? updatedAt = freezed,Object? commentsCount = null,Object? likesCount = null,Object? isLikedByMe = null,}) {
  return _then(PostModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,authorId: null == authorId ? _self.authorId : authorId // ignore: cast_nullable_to_non_nullable
as String,authorName: null == authorName ? _self.authorName : authorName // ignore: cast_nullable_to_non_nullable
as String,authorPhotoUrl: freezed == authorPhotoUrl ? _self.authorPhotoUrl : authorPhotoUrl // ignore: cast_nullable_to_non_nullable
as String?,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,commentsCount: null == commentsCount ? _self.commentsCount : commentsCount // ignore: cast_nullable_to_non_nullable
as int,likesCount: null == likesCount ? _self.likesCount : likesCount // ignore: cast_nullable_to_non_nullable
as int,isLikedByMe: null == isLikedByMe ? _self.isLikedByMe : isLikedByMe // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [PostModel].
extension PostModelPatterns on PostModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PostModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PostModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PostModel value)  $default,){
final _that = this;
switch (_that) {
case _PostModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PostModel value)?  $default,){
final _that = this;
switch (_that) {
case _PostModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String authorId,  String authorName,  String? authorPhotoUrl,  String title,  String content,  String? imageUrl,  DateTime createdAt,  DateTime? updatedAt,  int commentsCount,  int likesCount,  bool isLikedByMe)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PostModel() when $default != null:
return $default(_that.id,_that.authorId,_that.authorName,_that.authorPhotoUrl,_that.title,_that.content,_that.imageUrl,_that.createdAt,_that.updatedAt,_that.commentsCount,_that.likesCount,_that.isLikedByMe);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String authorId,  String authorName,  String? authorPhotoUrl,  String title,  String content,  String? imageUrl,  DateTime createdAt,  DateTime? updatedAt,  int commentsCount,  int likesCount,  bool isLikedByMe)  $default,) {final _that = this;
switch (_that) {
case _PostModel():
return $default(_that.id,_that.authorId,_that.authorName,_that.authorPhotoUrl,_that.title,_that.content,_that.imageUrl,_that.createdAt,_that.updatedAt,_that.commentsCount,_that.likesCount,_that.isLikedByMe);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String authorId,  String authorName,  String? authorPhotoUrl,  String title,  String content,  String? imageUrl,  DateTime createdAt,  DateTime? updatedAt,  int commentsCount,  int likesCount,  bool isLikedByMe)?  $default,) {final _that = this;
switch (_that) {
case _PostModel() when $default != null:
return $default(_that.id,_that.authorId,_that.authorName,_that.authorPhotoUrl,_that.title,_that.content,_that.imageUrl,_that.createdAt,_that.updatedAt,_that.commentsCount,_that.likesCount,_that.isLikedByMe);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PostModel extends PostModel {
  const _PostModel({required this.id, required this.authorId, required this.authorName, this.authorPhotoUrl, required this.title, required this.content, this.imageUrl, required this.createdAt, this.updatedAt, required this.commentsCount, required this.likesCount, this.isLikedByMe = false}): super._();
  factory _PostModel.fromJson(Map<String, dynamic> json) => _$PostModelFromJson(json);

@override final  String id;
@override final  String authorId;
@override final  String authorName;
@override final  String? authorPhotoUrl;
@override final  String title;
@override final  String content;
@override final  String? imageUrl;
@override final  DateTime createdAt;
@override final  DateTime? updatedAt;
@override final  int commentsCount;
@override final  int likesCount;
@override@JsonKey() final  bool isLikedByMe;

/// Create a copy of PostModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PostModelCopyWith<_PostModel> get copyWith => __$PostModelCopyWithImpl<_PostModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PostModelToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PostModel&&(identical(other.id, id) || other.id == id)&&(identical(other.authorId, authorId) || other.authorId == authorId)&&(identical(other.authorName, authorName) || other.authorName == authorName)&&(identical(other.authorPhotoUrl, authorPhotoUrl) || other.authorPhotoUrl == authorPhotoUrl)&&(identical(other.title, title) || other.title == title)&&(identical(other.content, content) || other.content == content)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.commentsCount, commentsCount) || other.commentsCount == commentsCount)&&(identical(other.likesCount, likesCount) || other.likesCount == likesCount)&&(identical(other.isLikedByMe, isLikedByMe) || other.isLikedByMe == isLikedByMe));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,authorId,authorName,authorPhotoUrl,title,content,imageUrl,createdAt,updatedAt,commentsCount,likesCount,isLikedByMe);
}

@override
String toString() {
    return 'PostModel(id: $id, authorId: $authorId, authorName: $authorName, authorPhotoUrl: $authorPhotoUrl, title: $title, content: $content, imageUrl: $imageUrl, createdAt: $createdAt, updatedAt: $updatedAt, commentsCount: $commentsCount, likesCount: $likesCount, isLikedByMe: $isLikedByMe)';
}


}

/// @nodoc
abstract mixin class _$PostModelCopyWith<$Res> implements $PostModelCopyWith<$Res> {
  factory _$PostModelCopyWith(_PostModel value, $Res Function(_PostModel) _then) = __$PostModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String authorId, String authorName, String? authorPhotoUrl, String title, String content, String? imageUrl, DateTime createdAt, DateTime? updatedAt, int commentsCount, int likesCount, bool isLikedByMe
});




}
/// @nodoc
class __$PostModelCopyWithImpl<$Res>
    implements _$PostModelCopyWith<$Res> {
  __$PostModelCopyWithImpl(this._self, this._then);

  final _PostModel _self;
  final $Res Function(_PostModel) _then;

/// Create a copy of PostModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? authorId = null,Object? authorName = null,Object? authorPhotoUrl = freezed,Object? title = null,Object? content = null,Object? imageUrl = freezed,Object? createdAt = null,Object? updatedAt = freezed,Object? commentsCount = null,Object? likesCount = null,Object? isLikedByMe = null,}) {
  return _then(_PostModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,authorId: null == authorId ? _self.authorId : authorId // ignore: cast_nullable_to_non_nullable
as String,authorName: null == authorName ? _self.authorName : authorName // ignore: cast_nullable_to_non_nullable
as String,authorPhotoUrl: freezed == authorPhotoUrl ? _self.authorPhotoUrl : authorPhotoUrl // ignore: cast_nullable_to_non_nullable
as String?,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,commentsCount: null == commentsCount ? _self.commentsCount : commentsCount // ignore: cast_nullable_to_non_nullable
as int,likesCount: null == likesCount ? _self.likesCount : likesCount // ignore: cast_nullable_to_non_nullable
as int,isLikedByMe: null == isLikedByMe ? _self.isLikedByMe : isLikedByMe // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
