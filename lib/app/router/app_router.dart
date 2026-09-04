import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Builds the app's [GoRouter] configuration.
///
/// Only the route skeleton exists on this branch: every destination renders
/// a minimal placeholder page. Real pages are filled in feature by feature
/// in later branches (`feature/auth`, `feature/posts`, `feature/users`).
GoRouter buildAppRouter() {
  return GoRouter(
    initialLocation: '/login',
    redirect: _authGuard,
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const _PlaceholderPage(routeName: 'Login'),
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

/// Auth guard placeholder.
///
/// `feature/auth` introduces `AuthStore.isAuthenticated`, resolved via
/// `get_it`, and this callback will redirect unauthenticated users to
/// `/login`. `AuthStore` does not exist yet on this branch, and it would be
/// wrong to fake one just to fill this in, so the guard is a deliberate
/// no-op: it always allows the navigation that was already requested.
String? _authGuard(BuildContext context, GoRouterState state) {
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
