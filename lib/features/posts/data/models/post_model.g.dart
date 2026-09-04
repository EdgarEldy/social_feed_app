// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PostModel _$PostModelFromJson(Map<String, dynamic> json) => _PostModel(
  id: json['id'] as String,
  authorId: json['authorId'] as String,
  authorName: json['authorName'] as String,
  authorPhotoUrl: json['authorPhotoUrl'] as String?,
  title: json['title'] as String,
  content: json['content'] as String,
  imageUrl: json['imageUrl'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
  commentsCount: (json['commentsCount'] as num).toInt(),
  likesCount: (json['likesCount'] as num).toInt(),
  isLikedByMe: json['isLikedByMe'] as bool? ?? false,
);

Map<String, dynamic> _$PostModelToJson(_PostModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'authorId': instance.authorId,
      'authorName': instance.authorName,
      'authorPhotoUrl': instance.authorPhotoUrl,
      'title': instance.title,
      'content': instance.content,
      'imageUrl': instance.imageUrl,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'commentsCount': instance.commentsCount,
      'likesCount': instance.likesCount,
      'isLikedByMe': instance.isLikedByMe,
    };
