import 'comment_model.dart';

/// Converts a [CommentModel] to and from the flat row shape stored in the
/// `comments_cache` table (see `core/database/app_database.dart`).
///
/// Kept separate from `comment_model.dart` for the same reason as
/// `PostModelLocalMapper` in `post_local_mapper.dart`: the wire-format
/// mapping and the local-cache mapping stay independently readable.
extension CommentModelLocalMapper on CommentModel {
  /// Builds the row `sqflite` expects for an insert/update into
  /// `comments_cache`, stamping [syncedAt] (defaulting to now) as the
  /// moment this row was last written from a successful remote read.
  Map<String, Object?> toRow({DateTime? syncedAt}) {
    return {
      'id': id,
      'post_id': postId,
      'author_id': authorId,
      'author_name': authorName,
      'author_photo_url': authorPhotoUrl,
      'content': content,
      // sqflite has no native DATETIME column type, so every DateTime is
      // stored as epoch milliseconds and converted back on read.
      'created_at': createdAt.millisecondsSinceEpoch,
      'synced_at': (syncedAt ?? DateTime.now()).millisecondsSinceEpoch,
    };
  }
}

/// Namespace for building a [CommentModel] back out of a `comments_cache`
/// row.
///
/// A plain static method (rather than another extension) because there is
/// no [CommentModel] instance to extend yet, the row is the input.
class CommentLocalMapper {
  const CommentLocalMapper._();

  static CommentModel fromRow(Map<String, Object?> row) {
    return CommentModel(
      id: row['id'] as String,
      postId: row['post_id'] as String,
      authorId: row['author_id'] as String,
      authorName: row['author_name'] as String,
      authorPhotoUrl: row['author_photo_url'] as String?,
      content: row['content'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row['created_at'] as int,
      ),
    );
  }

  /// The `synced_at` timestamp stored on [row], read back separately from
  /// [fromRow] since it is not part of the API-facing [CommentModel] shape.
  static DateTime syncedAtFromRow(Map<String, Object?> row) {
    return DateTime.fromMillisecondsSinceEpoch(row['synced_at'] as int);
  }
}
