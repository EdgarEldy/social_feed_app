import 'package:mobx/mobx.dart';

import '../../../../core/errors/failure.dart';
import '../../../auth/domain/entities/user.dart';
import '../../domain/usecases/get_user_usecase.dart';

part 'user_store.g.dart';

/// Holds the state of a single viewed profile: loading/error/data for one
/// `User`, loaded by id.
///
/// ## Scoping: per-page, not a `get_it` singleton
///
/// `AuthStore` and `ConnectivityStore` are registered as `get_it` singletons
/// because they hold genuinely app-wide, single-instance state: there is
/// exactly one signed-in session and exactly one device connectivity status,
/// and multiple unrelated screens all need to read the *same* value. `Store`
/// (`AuthStore`'s class doc) is explicit about that being the reason.
///
/// `UserStore` does not fit that shape. `ProfilePage` is reached via
/// `/profile/:id` (or `/profile` for "my own profile"), and a user can
/// navigate profile -> profile -> profile in sequence (e.g. tapping an
/// author's name from a post, then an author's name from a comment on that
/// profile's post) while each earlier page stays on the navigation stack
/// underneath. If `UserStore` were a shared singleton, popping back from
/// profile B to profile A would find `user` still holding B's data (or a
/// stale `isLoading`/`error` from B's load) for at least one frame before
/// A's own `loadUser` call, if it were even re-triggered, overwrote it; a
/// `StatefulWidget`'s `initState` only runs once per widget lifetime, and if
/// `go_router` keeps A's page alive underneath B rather than rebuilding it,
/// nothing would re-trigger a reload at all, so the leak would not just be a
/// single-frame flash. This mirrors `CommentsStore`'s documented scoping
/// (README: "instantiated per `PostDetailPage` and disposed with it"), a
/// closer precedent than `AuthStore`/`ConnectivityStore`.
///
/// `ProfilePage` therefore constructs its own `UserStore` directly (typically
/// in `initState`, pulling `GetUserUseCase` from `getIt`), rather than
/// resolving one from `get_it`. This store is intentionally not registered
/// in `injection_container.dart`.
class UserStore = _UserStore with _$UserStore;

abstract class _UserStore with Store {
  _UserStore({required this._getUserUseCase});

  final GetUserUseCase _getUserUseCase;

  /// The loaded profile, or `null` before the first successful [loadUser]
  /// call (or after one that failed).
  @observable
  User? user;

  /// Whether a [loadUser] call is currently in flight.
  @observable
  bool isLoading = false;

  /// The failure from the most recent [loadUser] call, or `null`.
  ///
  /// Cleared at the start of every [loadUser] call so a stale error from a
  /// previously viewed profile never lingers into the next one.
  @observable
  Failure? error;

  /// Loads the profile for the user with the given [id] via
  /// `GET /users/:id`.
  ///
  /// Posts state is deliberately not touched here: `PostRepository` has no
  /// implementation yet (`feature/posts` is a later branch), so
  /// `ProfilePage` only ever renders avatar/name/loading/error state for
  /// this branch, per the README's "user's posts" section being explicitly
  /// deferred.
  @action
  Future<void> loadUser(String id) async {
    isLoading = true;
    error = null;
    final result = await _getUserUseCase(id);
    result.match((failure) => error = failure, (loadedUser) => user = loadedUser);
    isLoading = false;
  }
}
