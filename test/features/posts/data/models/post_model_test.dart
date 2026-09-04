import 'package:flutter_test/flutter_test.dart';
import 'package:social_feed_app/features/posts/data/models/post_model.dart';

void main() {
  // Sample payload matching a realistic `GET /posts/:id` response, with
  // every field present including the optional `isLikedByMe`.
  final samplePostJson = <String, dynamic>{
    'id': 'post-1',
    'authorId': 'user-42',
    'authorName': 'Ada Lovelace',
    'authorPhotoUrl': 'https://example.com/avatars/ada.png',
    'title': 'Hello world',
    'content': 'My first post on the feed.',
    'imageUrl': 'https://example.com/images/hello.png',
    'createdAt': '2026-01-15T10:30:00.000Z',
    'updatedAt': '2026-01-16T08:00:00.000Z',
    'commentsCount': 3,
    'likesCount': 12,
    'isLikedByMe': true,
  };

  group('PostModel.fromJson/toJson', () {
    test('round-trips a full GET /posts/:id payload without data loss', () {
      final model = PostModel.fromJson(samplePostJson);
      final json = model.toJson();

      expect(json, samplePostJson);
    });

    test('defaults isLikedByMe to false when absent from the JSON', () {
      final jsonWithoutIsLikedByMe = Map<String, dynamic>.from(
        samplePostJson,
      )..remove('isLikedByMe');

      final model = PostModel.fromJson(jsonWithoutIsLikedByMe);

      expect(model.isLikedByMe, isFalse);
    });

    test('parses null authorPhotoUrl, imageUrl and updatedAt as null', () {
      final jsonWithNulls = <String, dynamic>{
        ...samplePostJson,
        'authorPhotoUrl': null,
        'imageUrl': null,
        'updatedAt': null,
      };

      final model = PostModel.fromJson(jsonWithNulls);

      expect(model.authorPhotoUrl, isNull);
      expect(model.imageUrl, isNull);
      expect(model.updatedAt, isNull);
    });
  });

  group('PostModel.toEntity', () {
    test('maps every field onto the Post entity unchanged', () {
      final model = PostModel.fromJson(samplePostJson);
      final entity = model.toEntity();

      expect(entity.id, samplePostJson['id']);
      expect(entity.authorId, samplePostJson['authorId']);
      expect(entity.authorName, samplePostJson['authorName']);
      expect(entity.authorPhotoUrl, samplePostJson['authorPhotoUrl']);
      expect(entity.title, samplePostJson['title']);
      expect(entity.content, samplePostJson['content']);
      expect(entity.imageUrl, samplePostJson['imageUrl']);
      expect(
        entity.createdAt,
        DateTime.parse(samplePostJson['createdAt'] as String),
      );
      expect(
        entity.updatedAt,
        DateTime.parse(samplePostJson['updatedAt'] as String),
      );
      expect(entity.commentsCount, samplePostJson['commentsCount']);
      expect(entity.likesCount, samplePostJson['likesCount']);
      expect(entity.isLikedByMe, samplePostJson['isLikedByMe']);
    });

    test('maps a post with no likedByMe key in JSON to isLikedByMe false', () {
      final jsonWithoutIsLikedByMe = Map<String, dynamic>.from(
        samplePostJson,
      )..remove('isLikedByMe');

      final entity = PostModel.fromJson(jsonWithoutIsLikedByMe).toEntity();

      expect(entity.isLikedByMe, isFalse);
    });
  });
}
