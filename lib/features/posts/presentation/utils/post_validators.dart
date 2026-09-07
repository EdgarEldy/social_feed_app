/// Field-level validation rules for `CreatePostPage`'s title/content fields.
///
/// Mirrors, but does not replace, the server-side rule `CreatePostUseCase`
/// already enforces (an empty `title`/`content`, once trimmed, is rejected
/// before ever reaching `PostRepository`): this class exists purely to give
/// the user immediate feedback on `CreatePostPage`'s own `Form` before a
/// submission round-trips to the usecase at all, the same division of labor
/// `AuthValidators` has with `SignUpUseCase`/`SignInUseCase`.
abstract final class PostValidators {
  const PostValidators._();

  /// Validates the title field, returning an error string or `null` when
  /// [value] is non-empty once trimmed.
  static String? validateTitle(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Title is required.';
    }
    return null;
  }

  /// Validates the content field, returning an error string or `null` when
  /// [value] is non-empty once trimmed.
  static String? validateContent(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Content is required.';
    }
    return null;
  }
}
