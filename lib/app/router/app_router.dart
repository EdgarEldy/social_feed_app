import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection_container.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/stores/auth_store.dart';
import '../../features/posts/domain/entities/post.dart';
import '../../features/posts/presentation/pages/create_post_page.dart';
import '../../features/posts/presentation/pages/feed_page.dart';
import '../../features/posts/presentation/pages/post_detail_page.dart';
import '../../features/posts/presentation/stores/posts_store.dart';
import '../../features/users/presentation/pages/edit_profile_page.dart';
import '../../features/users/presentation/pages/profile_page.dart';

/// Builds the app's [GoRouter] configuration.
///
/// [authStore] drives the auth guard below: every redirect decision reads
/// its `isAuthenticated` value. It is taken as an explicit parameter,
/// rather than resolved with `getIt<AuthStore>()` inside this function, so
/// a widget test can build a router against a fake/mock store without
/// touching `get_it` at all.
///
/// [refreshListenable], when provided, is handed straight to `GoRouter`; see
/// `auth_refresh_listenable.dart` for why one is needed at all. It is
/// optional here purely so a test can omit it when it only cares about the
/// redirect logic itself and not about re-evaluating it on sign in/out.
///
/// Real pages are filled in feature by feature; `feature/auth` fills in
/// `LoginPage`/`RegisterPage`, later branches fill in the rest. Everything
/// else here remains the placeholder route skeleton from
/// `feature/design-system`.
GoRouter buildAppRouter({
  required AuthStore authStore,
  Listenable? refreshListenable,
}) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) => _authGuard(authStore, state),
    refreshListenable: refreshListenable,
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      // Declared before '/posts/:id' below so it wins the match for the
      // literal path '/posts/new', the same static-before-dynamic ordering
      // '/profile/edit' relies on further down.
      GoRoute(
        path: '/posts/new',
        builder: (context, state) => const CreatePostPage(),
      ),
      GoRoute(
        path: '/posts/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final initialPost = state.extra as Post?;
          return PostDetailPage(postId: id, initialPost: initialPost);
        },
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              final existingPost = state.extra as Post?;
              return _EditPostRoute(id: id, initialPost: existingPost);
            },
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/feed',
                builder: (context, state) => const FeedPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const OwnProfilePage(),
                routes: [
                  // Declared before the ':id' route below so it wins the
                  // match for the literal path '/profile/edit': go_router
                  // tries sibling routes in declaration order, and a
                  // static segment declared first is matched before a
                  // dynamic ':id' segment ever gets a chance to swallow it.
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => const EditProfilePage(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return ProfilePage(userId: id);
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// Redirects between the public auth routes and the rest of the app based
/// on [authStore]'s `isAuthenticated`.
///
/// Only `/login` and `/register` are public; every other route in this app
/// requires a bearer token server-side per the API Contract, `/posts/:id`
/// included, so an unauthenticated user hitting any of them is bounced to
/// `/login`. An already-authenticated user landing on `/login` or
/// `/register` (a cold start with a restored session, following the link
/// between the two pages while already signed in, or navigating `back` to
/// either) is bounced forward to `/feed` instead, since there is no reason
/// to show an auth form to someone already signed in.
///
/// Returning `null` in every other case means "proceed with the navigation
/// that was already requested".
String? _authGuard(AuthStore authStore, GoRouterState state) {
  final isAuthenticated = authStore.isAuthenticated;
  final isPublicAuthRoute =
      state.matchedLocation == '/login' || state.matchedLocation == '/register';

  if (!isAuthenticated && !isPublicAuthRoute) {
    return '/login';
  }
  if (isAuthenticated && isPublicAuthRoute) {
    return '/feed';
  }
  return null;
}

/// Bottom navigation shell shared by the feed and profile tabs.
///
/// [StatefulShellRoute.indexedStack] keeps one [Navigator] per branch alive
/// in an [IndexedStack], so switching tabs preserves each tab's own
/// navigation stack and scroll position instead of rebuilding it.
class _AppShell extends StatelessWidget {
  const _AppShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          // goBranch with initialLocation: true pops that branch back to
          // its root when re-tapping the already-selected tab, matching
          // the usual bottom-nav behavior.
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dynamic_feed), label: 'Feed'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

/// Resolves the `Post` behind `/posts/:id/edit`, then hands off to
/// [CreatePostPage] in edit mode.
///
/// `PostCard`'s edit menu item already has the `Post` in memory (it is what
/// it is rendering), so it passes it straight through as `extra` when it
/// pushes this route, skipping a redundant `GET /posts/:id` round trip; that
/// is the [initialPost] case below. A direct visit to this route without
/// that `extra` (a deep link, a page restored without its navigation
/// history) has no such in-memory `Post` to reuse, so this widget falls back
/// to [PostsStore.loadPost], the same load `PostDetailPage` uses for its own
/// `GET /posts/:id`.
class _EditPostRoute extends StatefulWidget {
  const _EditPostRoute({required this.id, this.initialPost});

  final String id;
  final Post? initialPost;

  @override
  State<_EditPostRoute> createState() => _EditPostRouteState();
}

class _EditPostRouteState extends State<_EditPostRoute> {
  @override
  void initState() {
    super.initState();
    if (widget.initialPost == null) {
      getIt<PostsStore>().loadPost(widget.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialPost = widget.initialPost;
    if (initialPost != null) {
      return CreatePostPage(existingPost: initialPost);
    }
    return Observer(
      builder: (_) {
        final store = getIt<PostsStore>();
        if (store.isLoadingCurrentPost) {
          return const Scaffold(
            body: LoadingIndicator(semanticsLabel: 'Loading post'),
          );
        }
        final error = store.currentPostError;
        if (error != null) {
          return Scaffold(body: ErrorView(message: error.message));
        }
        final post = store.currentPost;
        if (post == null || post.id != widget.id) {
          return const Scaffold(
            body: ErrorView(message: 'Post not found.'),
          );
        }
        return CreatePostPage(existingPost: post);
      },
    );
  }
}

