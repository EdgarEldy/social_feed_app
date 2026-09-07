import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_dimens.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/network_info/connectivity_store.dart';
import '../../../../core/widgets/adaptive_grid.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../stores/posts_store.dart';
import '../widgets/post_card.dart';

/// How close to the bottom of the scroll extent (in logical pixels) the user
/// has to get before the next page starts loading.
///
/// Triggering [PostsStore.loadMore] a little before the literal end of the
/// list, rather than exactly at it, means the next page is usually already
/// in flight by the time the user reaches the last rendered [PostCard],
/// instead of the list visibly stalling on an empty screen first.
const double _loadMoreThreshold = 300;

/// The main feed: a paginated, newest-first grid of [PostCard]s.
///
/// Built directly on [CustomScrollView]/[SliverAppBar] rather than a plain
/// `ListView.builder` wrapped in an `AppBar`, so the app bar collapses away
/// as the user scrolls down through the feed and reappears as soon as they
/// scroll back up (`floating`/`snap`, see [_FeedSliverAppBar]).
///
/// The posts themselves are laid out with `AdaptiveGrid`
/// (`core/widgets/adaptive_grid.dart`), which switches between one, two, and
/// three columns as the viewport widens, see [_buildContentSlivers] for the
/// eager-vs-lazy tradeoff that comes with it.
///
/// Owns the [ScrollController] driving cursor-based pagination: a listener
/// calls [PostsStore.loadMore] once the scroll position gets within
/// [_loadMoreThreshold] of the bottom, relying entirely on that method's own
/// in-flight/no-more-pages guards rather than tracking any of that state
/// again here.
class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final PostsStore _postsStore = getIt<PostsStore>();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Only fetch the first page the very first time this page is reached.
    // Popping back from PostDetailPage (or switching tabs and back) reuses
    // whatever PostsStore already has loaded instead of refetching it.
    if (!_postsStore.hasLoadedOnce) {
      _postsStore.loadPosts();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
      _postsStore.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _postsStore.loadPosts,
        child: Observer(
          builder: (_) => CustomScrollView(
            controller: _scrollController,
            // Loading/error/empty states render a single SliverFillRemaining
            // sliver that may not fill (let alone overflow) the viewport, so
            // the default scroll physics would refuse to overscroll and the
            // RefreshIndicator gesture above would never trigger. Forcing
            // always-scrollable physics keeps pull-to-refresh working in
            // every state, not just once there is a long enough post list to
            // scroll on its own.
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const _FeedSliverAppBar(),
              ..._buildContentSlivers(_postsStore),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/posts/new'),
        tooltip: 'Create a post',
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// The collapsing header for [FeedPage].
///
/// `floating: true` lets the app bar reappear as soon as the user scrolls
/// up, even from deep in the list, rather than only once they scroll all
/// the way back to the top (`pinned`'s behavior); `snap: true` makes that
/// reappearance settle into place immediately instead of tracking the
/// scroll offset one pixel at a time, which reads as a natural, deliberate
/// collapse/reveal rather than a jittery one.
class _FeedSliverAppBar extends StatelessWidget {
  const _FeedSliverAppBar();

  @override
  Widget build(BuildContext context) {
    return const SliverAppBar(
      title: Text('Feed'),
      floating: true,
      snap: true,
    );
  }
}

/// Picks the right slivers for [store]'s current state: a full-page loader,
/// a full-page error with retry, a full-page empty state, or the paginated
/// list of [PostCard]s with a trailing loader while the next page fetches.
///
/// A plain function rather than its own widget: it only maps observable
/// reads to a `List<Widget>`, and running it inside the [Observer] already
/// wrapping [CustomScrollView] in [_FeedPageState] is what makes every read
/// below reactive, splitting it into a separate widget would not add
/// anything beyond an extra layer of indirection.
List<Widget> _buildContentSlivers(PostsStore store) {
  if (store.isLoadingFeed && store.posts.isEmpty) {
    return const [
      SliverFillRemaining(
        hasScrollBody: false,
        child: LoadingIndicator(semanticsLabel: 'Loading feed'),
      ),
    ];
  }

  final error = store.feedError;
  if (error != null && store.posts.isEmpty) {
    return [
      SliverFillRemaining(
        hasScrollBody: false,
        child: ErrorView(message: error.message, onRetry: store.loadPosts),
      ),
    ];
  }

  if (store.hasLoadedOnce && store.posts.isEmpty) {
    return const [
      SliverFillRemaining(hasScrollBody: false, child: _FeedEmptyState()),
    ];
  }

  return [
    SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spacingMd),
      // AdaptiveGrid lays out its children with Wrap, which builds every
      // entry in `store.posts` up front rather than lazily windowing them
      // the way SliverList.builder/SliverList.separated did. That trade is
      // acceptable here because `store.posts` is not "the whole feed": it is
      // bounded by cursor-based pagination, one backend page at a time via
      // loadPosts/loadMore, so the number of PostCards actually in memory at
      // once stays in the low hundreds even after a long scroll session,
      // never the full remote dataset. Capping how much of `posts` is passed
      // to AdaptiveGrid (e.g. only the last N) was considered and rejected:
      // it would silently drop already-loaded cards from view, fighting
      // loadMore's append-only contract and surprising anyone relying on
      // scrolling back up through the feed. If this ever becomes a real
      // jank source (very deep scroll sessions on low-end devices), the fix
      // is a virtualized grid (e.g. a sliver-aware grid delegate) rather
      // than truncating already-fetched data.
      sliver: SliverToBoxAdapter(
        child: AdaptiveGrid(
          runSpacing: AppDimens.spacingSm,
          children: [
            for (final post in store.posts)
              PostCard(key: ValueKey(post.id), post: post),
          ],
        ),
      ),
    ),
    if (store.isLoadingMore) const _FeedLoadMoreSliver(),
  ];
}

/// The empty-feed message, shown once [PostsStore.loadPosts] has completed
/// with zero posts (not an error, see [PostsStore.hasLoadedOnce]'s doc).
///
/// Reads [ConnectivityStore] to tell apart two states that would otherwise
/// look identical: genuinely no posts exist yet, versus the device is
/// offline and the local cache has nothing to show either (the offline-first
/// read strategy returns an empty page rather than a [Failure] in that
/// case, see `PostRepositoryImpl._getPostsFromCache`). The app-wide
/// [ConnectivityAwareOfflineBanner] already announces "you are offline" on
/// its own, this only exists to stop the generic "no posts yet" copy from
/// misleadingly implying that is the whole story while offline.
class _FeedEmptyState extends StatelessWidget {
  const _FeedEmptyState();

  @override
  Widget build(BuildContext context) {
    final connectivityStore = getIt<ConnectivityStore>();

    return Observer(
      builder: (_) {
        final isOffline = !connectivityStore.isOnline;
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.spacingLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isOffline ? Icons.cloud_off : Icons.dynamic_feed_outlined,
                  size: AppDimens.spacingXxl,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: AppDimens.spacingMd),
                Text(
                  isOffline
                      ? "You're offline and no posts are cached yet."
                      : 'No posts yet. Be the first to share something.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The small trailing spinner shown at the bottom of the feed while
/// [PostsStore.loadMore] fetches the next page.
class _FeedLoadMoreSliver extends StatelessWidget {
  const _FeedLoadMoreSliver();

  @override
  Widget build(BuildContext context) {
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppDimens.spacingLg),
        child: LoadingIndicator(semanticsLabel: 'Loading more posts'),
      ),
    );
  }
}
