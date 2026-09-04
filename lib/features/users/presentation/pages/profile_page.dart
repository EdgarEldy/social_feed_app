import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_dimens.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/stores/auth_store.dart';
import '../../domain/usecases/get_user_usecase.dart';
import '../stores/user_store.dart';

/// Shows the profile of the user identified by [userId]: avatar, display
/// name, and the loading/error states around fetching it.
///
/// Reached via `/profile/:id` (someone else's profile) or, indirectly,
/// `/profile` (the signed-in user's own profile, resolved to an id by
/// [OwnProfilePage] before this widget is ever built). Both routes render
/// this same widget once an id is known, per the Screens table entry: "View
/// own or another user's profile".
///
/// Builds its own [UserStore] in [initState] rather than resolving one from
/// `get_it`, per that store's documented per-page scoping (see its class
/// doc). `UserStore` holds no reaction/subscription/controller, so nothing
/// needs disposing in [dispose] here.
///
/// The user's posts are deliberately not rendered on this page: `feature/posts`
/// (a later branch, per the README's "Order of Work") is what adds a post
/// grid below the header built here.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.userId});

  /// The id of the profile to load, via `GET /users/:id`.
  final String userId;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final UserStore _userStore = UserStore(
    getUserUseCase: getIt<GetUserUseCase>(),
  );

  @override
  void initState() {
    super.initState();
    _userStore.loadUser(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        final isOwnProfile =
            getIt<AuthStore>().currentUser?.id == widget.userId;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Profile'),
            actions: [
              if (isOwnProfile)
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit profile',
                  onPressed: () => context.push('/profile/edit'),
                ),
            ],
          ),
          body: _ProfileBody(userStore: _userStore, userId: widget.userId),
        );
      },
    );
  }
}

/// The loading/error/data states for the profile identified by [userId],
/// split out from [ProfilePage] so the app bar's own `Observer` (reading
/// [AuthStore.currentUser] for the "is this my own profile" check) does not
/// have to also re-run [_ProfileHeader]'s layout on every unrelated
/// [UserStore] change, and vice versa.
class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.userStore, required this.userId});

  final UserStore userStore;
  final String userId;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        if (userStore.isLoading) {
          return const LoadingIndicator(semanticsLabel: 'Loading profile');
        }
        final error = userStore.error;
        if (error != null) {
          return ErrorView(
            message: error.message,
            onRetry: () => userStore.loadUser(userId),
          );
        }
        final user = userStore.user;
        if (user == null) {
          // loadUser always resolves error or user before isLoading flips
          // back to false, so this is unreachable in practice; handled
          // rather than assumed away, same reasoning AuthStore documents
          // for its own unreachable Left branch.
          return const SizedBox.shrink();
        }
        return _ProfileHeader(user: user);
        // feature/posts adds a paginated grid of this user's posts here,
        // below the header, once PostRepository exists.
      },
    );
  }
}

/// The avatar and display name for a loaded [user].
///
/// Split out from [ProfilePage] so the page itself only orchestrates
/// loading/error/data state, keeping both widgets well under the ~150 line
/// guideline.
///
/// Wrapped in a [SingleChildScrollView] rather than a bare [Center]: a
/// display name has no length cap (see `AuthValidators.validateDisplayName`)
/// and under a large `textScaleFactor` it can wrap onto several lines, tall
/// enough on a small device to overflow a fixed-height body. Scrolling is
/// the safe fallback so content never clips instead of merely growing.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoUrl = user.photoUrl;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.spacingLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            image: true,
            label: 'Profile photo of ${user.displayName}',
            child: CircleAvatar(
              radius: AppDimens.spacingXxl,
              backgroundImage: photoUrl == null
                  ? null
                  : CachedNetworkImageProvider(photoUrl),
              child: photoUrl == null
                  ? Icon(Icons.person, size: AppDimens.spacingXxl)
                  : null,
            ),
          ),
          const SizedBox(height: AppDimens.spacingMd),
          Text(
            user.displayName,
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Resolves and renders the signed-in user's own profile, for the `/profile`
/// route (no id in the URL).
///
/// ## The "id unknown" gap
///
/// The API Contract has no `GET /users/me` endpoint, only `GET /users/:id`,
/// `PATCH /users/me`, and `POST /users/me/avatar`. Fetching "my own profile"
/// therefore always requires already knowing my own id, and
/// [AuthStore.currentUser] is exactly the (only) place that id lives, per
/// [AuthStore]'s class doc: a session restored from stored tokens leaves
/// `currentUser` `null` until a fresh sign in/up response (or a future "load
/// my profile" flow) populates it, even though [AuthStore.isAuthenticated]
/// is already `true`.
///
/// So there is a real window, right after a cold start with a restored
/// session, where `/profile` is reachable (the auth guard lets it through)
/// but there is no id to call `GET /users/:id` with. Rather than either (a)
/// crashing on a null id, or (b) inventing an id (decoding the JWT, which
/// `AuthStore` already rejected as out of contract for the same reason),
/// this widget shows a short explanatory state instead, and stays wrapped in
/// [Observer] so it re-renders the moment something else populates
/// `currentUser`, no navigation required.
class OwnProfilePage extends StatelessWidget {
  const OwnProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final authStore = getIt<AuthStore>();
    return Observer(
      builder: (_) {
        final currentUser = authStore.currentUser;
        if (currentUser == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Profile')),
            body: const ErrorView(
              message:
                  'Your profile has not loaded yet. Sign out and back in '
                  'to refresh it.',
            ),
          );
        }
        return ProfilePage(userId: currentUser.id);
      },
    );
  }
}
