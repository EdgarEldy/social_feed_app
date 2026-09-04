import 'package:freezed_annotation/freezed_annotation.dart';

import 'user.dart';

part 'auth_session.freezed.dart';

/// The result of a successful `POST /auth/register` or `POST /auth/login`
/// call: the authenticated `user` together with the token pair the API
/// issued for them.
///
/// `AuthRepository.register` and `AuthRepository.login` used to each spell
/// out the same `({User user, String accessToken, String refreshToken})`
/// record. Both endpoints return the exact same shape per the API Contract,
/// so this named type replaces the duplicated record, the same way
/// `PaginatedResult` replaces the duplicated pagination record.
@freezed
abstract class AuthSession with _$AuthSession {
  const factory AuthSession({
    /// The signed-in or newly registered user.
    required User user,

    /// Short-lived JWT sent as `Authorization: Bearer <token>` on every
    /// authenticated request.
    required String accessToken,

    /// Longer-lived token exchanged for a new access token via
    /// `POST /auth/refresh`.
    required String refreshToken,
  }) = _AuthSession;
}
