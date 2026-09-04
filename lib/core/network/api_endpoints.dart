/// Path constants for every endpoint exposed by the backend, matching the
/// API Contract in the project README exactly. Paths here are always
/// relative; [DioClient] supplies the scheme and host via `baseUrl`.
///
/// Parameterized paths are exposed as functions instead of string templates
/// so call sites get compile-time checked arguments instead of manual
/// string interpolation scattered across the codebase.
class ApiEndpoints {
  const ApiEndpoints._();

  // Auth

  /// `POST /auth/register`
  static const String register = '/auth/register';

  /// `POST /auth/login`
  static const String login = '/auth/login';

  /// `POST /auth/refresh`
  static const String refresh = '/auth/refresh';

  /// `POST /auth/logout`
  static const String logout = '/auth/logout';

  /// `POST /auth/google`
  static const String googleAuth = '/auth/google';

  // Users

  /// `GET /users/:id`
  static String userById(String id) => '/users/$id';

  /// `PATCH /users/me`
  static const String currentUser = '/users/me';

  /// `POST /users/me/avatar`
  static const String currentUserAvatar = '/users/me/avatar';

  // Posts

  /// `GET /posts` and `POST /posts`
  static const String posts = '/posts';

  /// `GET /posts/:id`, `PATCH /posts/:id`, `DELETE /posts/:id`
  static String postById(String id) => '/posts/$id';

  // Comments

  /// `GET /posts/:postId/comments` and `POST /posts/:postId/comments`
  static String postComments(String postId) => '/posts/$postId/comments';

  /// `DELETE /comments/:id`
  static String commentById(String id) => '/comments/$id';

  // Likes

  /// `POST /posts/:postId/likes`
  static String postLikes(String postId) => '/posts/$postId/likes';

  /// `GET /posts/:postId/likes/me`
  static String postLikesMe(String postId) => '/posts/$postId/likes/me';

  // Devices (bonus, push notifications)

  /// `POST /devices`
  static const String devices = '/devices';

  /// `DELETE /devices/:pushToken`
  static String deviceByPushToken(String pushToken) => '/devices/$pushToken';
}
