// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'like_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LikeToggleModel _$LikeToggleModelFromJson(Map<String, dynamic> json) =>
    _LikeToggleModel(
      liked: json['liked'] as bool,
      likesCount: (json['likesCount'] as num).toInt(),
    );

Map<String, dynamic> _$LikeToggleModelToJson(_LikeToggleModel instance) =>
    <String, dynamic>{
      'liked': instance.liked,
      'likesCount': instance.likesCount,
    };

_LikeStatusModel _$LikeStatusModelFromJson(Map<String, dynamic> json) =>
    _LikeStatusModel(liked: json['liked'] as bool);

Map<String, dynamic> _$LikeStatusModelToJson(_LikeStatusModel instance) =>
    <String, dynamic>{'liked': instance.liked};
