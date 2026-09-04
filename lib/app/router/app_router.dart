import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/stores/auth_store.dart';

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
      GoRoute(
        path: '/posts/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return _PlaceholderPage(routeName: 'Post Detail', detail: id);
        },
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
                builder: (context, state) =>
                    const _PlaceholderPage(routeName: 'Feed'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) =>
                    const _PlaceholderPage(routeName: 'Profile'),
              ),
              GoRoute(
                path: '/profile/:id',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return _PlaceholderPage(routeName: 'Profile', detail: id);
                },
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

/// Minimal placeholder page naming the route it stands in for.
///
/// No feature branch has built real pages yet, this exists purely so the
/// route tree has something to render and can be exercised by a widget
/// test.
class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.routeName, this.detail});

  final String routeName;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(routeName)),
      body: Center(
        child: Text(detail == null ? routeName : '$routeName: $detail'),
      ),
    );
  }
}
