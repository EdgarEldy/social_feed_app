import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:social_feed_app/app/app.dart';
import 'package:social_feed_app/core/di/injection_container.dart';
import 'package:social_feed_app/core/storage/secure_token_storage.dart';
import 'package:social_feed_app/core/sync/sync_service.dart';
import 'package:social_feed_app/features/auth/presentation/stores/auth_store.dart';
import 'package:social_feed_app/features/likes/presentation/widgets/like_button.dart';
import 'package:social_feed_app/features/posts/presentation/pages/post_detail_page.dart';

/// Stand-in for the real `path_provider` platform channel, pointing
/// [AppDatabase] at a fresh temporary directory instead of a real device
/// path. Same pattern `test/core/database/app_database_test.dart` uses,
/// applied here so this end-to-end run never touches (or leaves behind) a
/// real app-data SQLite file on the machine running the test.
class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.directoryPath);

  final String directoryPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => directoryPath;
}

/// A minimal, stateful, in-memory stand-in for a backend implementing the
/// slice of the API Contract this flow exercises: register, list/create/get
/// a post, toggle a like, and list/add a comment.
///
/// This is a plain [HttpClientAdapter], the same seam `DioAdapter`
/// (`http_mock_adapter`, used by every other `dio`-facing test in this repo)
/// is itself built on. A hand-rolled adapter is used here instead, rather
/// than `DioAdapter`'s route-by-route canned responses, because this flow
/// needs *stateful* responses: creating a post must make it show up in a
/// later `GET /posts`, liking it must change what a later `GET /posts/:id`
/// reports, and adding a comment must show up in a later `GET
/// /posts/:postId/comments`, none of which a single canned reply per route
/// can express. Every response shape below matches the API Contract in the
/// project README exactly.
class _FakeBackendAdapter implements HttpClientAdapter {
  final List<Map<String, dynamic>> _posts = [];
  final Map<String, List<Map<String, dynamic>>> _commentsByPost = {};
  final Map<String, Map<String, dynamic>> _likesByPost = {};

  String? _currentUserId;
  String? _currentUserName;

  int _postSeq = 0;
  int _commentSeq = 0;
  int _userSeq = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final method = options.method.toUpperCase();
    final segments = options.uri.pathSegments;

    if (method == 'POST' && segments.length == 2 && segments[0] == 'auth' && segments[1] == 'register') {
      return _handleRegister(options);
    }
    if (method == 'GET' && segments.length == 1 && segments[0] == 'posts') {
      return _handleGetPosts();
    }
    if (method == 'POST' && segments.length == 1 && segments[0] == 'posts') {
      return _handleCreatePost(options);
    }
    if (method == 'GET' && segments.length == 2 && segments[0] == 'posts') {
      return _handleGetPost(segments[1]);
    }
    if (method == 'POST' && segments.length == 3 && segments[0] == 'posts' && segments[2] == 'likes') {
      return _handleToggleLike(segments[1]);
    }
    if (method == 'GET' && segments.length == 3 && segments[0] == 'posts' && segments[2] == 'comments') {
      return _handleGetComments(segments[1]);
    }
    if (method == 'POST' && segments.length == 3 && segments[0] == 'posts' && segments[2] == 'comments') {
      return _handleAddComment(segments[1], options);
    }

    return _jsonResponse(404, {
      'message': 'Unmocked route in _FakeBackendAdapter: $method ${options.uri.path}',
    });
  }

  ResponseBody _jsonResponse(int statusCode, Object? data) {
    return ResponseBody.fromString(
      jsonEncode(data),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  Future<ResponseBody> _handleRegister(RequestOptions options) async {
    final body = options.data as Map<String, dynamic>;
    _userSeq += 1;
    final userId = 'user-$_userSeq';
    _currentUserId = userId;
    _currentUserName = body['displayName'] as String;

    return _jsonResponse(201, {
      'accessToken': 'access-token-$userId',
      'refreshToken': 'refresh-token-$userId',
      'user': {
        'id': userId,
        'displayName': body['displayName'],
        'email': body['email'],
        'photoUrl': null,
        'createdAt': DateTime.now().toIso8601String(),
      },
    });
  }

  Future<ResponseBody> _handleGetPosts() async {
    return _jsonResponse(200, {'items': _posts, 'nextCursor': null});
  }

  Future<ResponseBody> _handleCreatePost(RequestOptions options) async {
    final formData = options.data as FormData;
    final fields = Map.fromEntries(formData.fields);
    _postSeq += 1;
    final postId = 'post-$_postSeq';

    final post = {
      'id': postId,
      'authorId': _currentUserId ?? 'user-0',
      'authorName': _currentUserName ?? 'Test User',
      'authorPhotoUrl': null,
      'title': fields['title'] ?? '',
      'content': fields['content'] ?? '',
      'imageUrl': null,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': null,
      'commentsCount': 0,
      'likesCount': 0,
      'isLikedByMe': false,
    };
    _posts.insert(0, post);
    _commentsByPost[postId] = [];
    _likesByPost[postId] = {'liked': false, 'likesCount': 0};

    return _jsonResponse(201, post);
  }

  Future<ResponseBody> _handleGetPost(String id) async {
    final post = _posts.firstWhere((p) => p['id'] == id, orElse: () => const {});
    if (post.isEmpty) {
      return _jsonResponse(404, {'message': 'Post not found'});
    }
    return _jsonResponse(200, post);
  }

  Future<ResponseBody> _handleToggleLike(String postId) async {
    final state = _likesByPost.putIfAbsent(
      postId,
      () => {'liked': false, 'likesCount': 0},
    );
    final liked = !(state['liked'] as bool);
    final likesCount = (state['likesCount'] as int) + (liked ? 1 : -1);
    state['liked'] = liked;
    state['likesCount'] = likesCount;

    final post = _posts.firstWhere((p) => p['id'] == postId, orElse: () => const {});
    if (post.isNotEmpty) {
      post['likesCount'] = likesCount;
      post['isLikedByMe'] = liked;
    }

    return _jsonResponse(200, {'liked': liked, 'likesCount': likesCount});
  }

  Future<ResponseBody> _handleGetComments(String postId) async {
    return _jsonResponse(200, {
      'items': _commentsByPost[postId] ?? const [],
      'nextCursor': null,
    });
  }

  Future<ResponseBody> _handleAddComment(
    String postId,
    RequestOptions options,
  ) async {
    final body = options.data as Map<String, dynamic>;
    _commentSeq += 1;
    final commentId = 'comment-$_commentSeq';

    final comment = {
      'id': commentId,
      'postId': postId,
      'authorId': _currentUserId ?? 'user-0',
      'authorName': _currentUserName ?? 'Test User',
      'authorPhotoUrl': null,
      'content': body['content'],
      'createdAt': DateTime.now().toIso8601String(),
    };
    _commentsByPost.putIfAbsent(postId, () => []).add(comment);

    final post = _posts.firstWhere((p) => p['id'] == postId, orElse: () => const {});
    if (post.isNotEmpty) {
      post['commentsCount'] = (post['commentsCount'] as int) + 1;
    }

    return _jsonResponse(201, comment);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets(
    'sign up, create a post, like it, and comment on it',
    (tester) async {
      final tempDirectory = Directory.systemTemp.createTempSync(
        'app_test_documents',
      );
      addTearDown(() => tempDirectory.deleteSync(recursive: true));
      PathProviderPlatform.instance = _FakePathProviderPlatform(
        tempDirectory.path,
      );

      // Mirrors test/widget_test.dart's own justification for overriding
      // dioFactory: DioClient.create() reads dotenv.env['API_BASE_URL'],
      // which requires a real .env file this test has no reason to load.
      // _FakeBackendAdapter stands in for the network boundary only; every
      // other piece of production wiring (get_it, go_router, MobX stores,
      // real sqflite schema) is exactly what main.dart itself builds.
      configureDependencies(
        dioFactory: () => Dio(BaseOptions(baseUrl: 'https://api.example.com'))
          ..httpClientAdapter = _FakeBackendAdapter(),
      );
      addTearDown(() async => getIt.reset());

      // A leftover access token in the real OS keyring (from an earlier run
      // of this same suite on this machine) would restore an authenticated
      // session before the app even renders its first frame, skipping the
      // sign-up screen this test means to exercise.
      await getIt<SecureTokenStorage>().clearTokens();
      await getIt<AuthStore>().restoreSession();
      getIt<SyncService>();

      await tester.pumpWidget(App());
      await tester.pumpAndSettle();

      // Starts unauthenticated on the login page.
      expect(find.widgetWithText(AppBar, 'Log in'), findsOneWidget);

      // Sign up.
      await tester.tap(find.text("Don't have an account? Sign up"));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Sign up'), findsOneWidget);

      final registerFields = find.byType(TextFormField);
      await tester.enterText(registerFields.at(0), 'Ada Lovelace');
      await tester.enterText(registerFields.at(1), 'ada@example.com');
      await tester.enterText(registerFields.at(2), 'password123');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign up'));
      await tester.pumpAndSettle();

      // Signing up lands on the feed, empty at first.
      expect(find.widgetWithText(AppBar, 'Feed'), findsOneWidget);
      expect(
        find.text('No posts yet. Be the first to share something.'),
        findsOneWidget,
      );

      // Create a post.
      await tester.tap(find.byTooltip('Create a post'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Create post'), findsOneWidget);

      const postTitle = 'My first post';
      const postContent = 'Hello from the integration test suite!';
      final createPostFields = find.byType(TextFormField);
      await tester.enterText(createPostFields.at(0), postTitle);
      await tester.enterText(createPostFields.at(1), postContent);
      await tester.tap(find.widgetWithText(FilledButton, 'Publish'));
      await tester.pumpAndSettle();

      // Publishing navigates straight to the new post's detail page.
      expect(find.widgetWithText(AppBar, 'Post'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PostDetailPage),
          matching: find.text(postTitle),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(PostDetailPage),
          matching: find.text(postContent),
        ),
        findsOneWidget,
      );

      // Like the post: the heart flips from outline to filled and the count
      // goes from 0 to 1.
      expect(find.byIcon(Icons.favorite_border), findsWidgets);
      expect(find.byIcon(Icons.favorite), findsNothing);

      await tester.tap(
        find.descendant(
          of: find.byType(PostDetailPage),
          matching: find.byIcon(Icons.favorite_border),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(
        find.descendant(of: find.byType(LikeButton), matching: find.text('1')),
        findsOneWidget,
      );

      // Comment on the post.
      await tester.tap(find.byTooltip('Add comment'));
      await tester.pumpAndSettle();

      const commentContent = 'Great first post, congrats!';
      await tester.enterText(find.byType(TextField), commentContent);
      await tester.tap(find.byTooltip('Send comment'));
      await tester.pumpAndSettle();

      expect(find.text(commentContent), findsOneWidget);
    },
  );
}
