import 'post_model.dart';

/// Converts a [PostModel] to and from the flat row shape stored in the
/// `posts_cache` table (see `core/database/app_database.dart`).
///
/// Kept separate from `post_model.dart` rather than added to the
/// `freezed` class body so the wire-format mapping (`fromJson`/`toJson`)
/// and the local-cache mapping stay independently readable, and so a
/// schema change here never touches the generated `*.freezed.dart`/
/// `*.g.dart` files for the API shape.
extension PostModelLocalMapper on PostModel {
  /// Builds the row `sqflite` expects for an insert/update into
  /// `posts_cache`, stamping [syncedAt] (defaulting to now) as the moment
  /// this row was last written from a successful remote read.
  Map<String, Object?> toRow({DateTime? syncedAt}) {
    return {
      'id': id,
      'author_id': authorId,
      'author_name': authorName,
      'author_photo_url': authorPhotoUrl,
      'title': title,
      'content': content,
      'image_url': imageUrl,
      // sqflite has no native DATETIME column type, so every DateTime is
      // stored as epoch milliseconds and converted back on read.
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
      'comments_count': commentsCount,
      'likes_count': likesCount,
      // sqflite has no BOOLEAN column type either; 0/1 is the conventional
      // encoding.
      'is_liked_by_me': isLikedByMe ? 1 : 0,
      'synced_at': (syncedAt ?? DateTime.now()).millisecondsSinceEpoch,
    };
  }
}

/// Namespace for building a [PostModel] back out of a `posts_cache` row.
///
/// A plain static method (rather than another extension) because there is
/// no [PostModel] instance to extend yet, the row is the input.
class PostLocalMapper {
  const PostLocalMapper._();

  static PostModel fromRow(Map<String, Object?> row) {
    return PostModel(
      id: row['id'] as String,
      authorId: row['author_id'] as String,
      authorName: row['author_name'] as String,
      authorPhotoUrl: row['author_photo_url'] as String?,
      title: row['title'] as String,
      content: row['content'] as String,
      imageUrl: row['image_url'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row['created_at'] as int,
      ),
      updatedAt: row['updated_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
      commentsCount: row['comments_count'] as int,
      likesCount: row['likes_count'] as int,
      isLikedByMe: (row['is_liked_by_me'] as int) == 1,
    );
  }

  /// The `synced_at` timestamp stored on [row], read back separately from
  /// [fromRow] since it is not part of the API-facing [PostModel] shape.
  static DateTime syncedAtFromRow(Map<String, Object?> row) {
    return DateTime.fromMillisecondsSinceEpoch(row['synced_at'] as int);
  }
}
