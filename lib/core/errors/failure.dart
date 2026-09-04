/// Base type for every error that can cross a repository boundary.
///
/// The whole point of this hierarchy is that `data/` never lets a raw
/// exception (a `DioException`, a `SqfliteException`, and so on) escape.
/// Every repository method maps whatever went wrong into one of these
/// subclasses and returns it as the `Left` side of an `Either<Failure, T>`,
/// so `domain/` and `presentation/` only ever deal with plain Dart values.
///
/// This branch is not using `freezed` yet, so equality is hand-written on
/// each subclass below. That equality is what lets tests write
/// `expect(result, Left(const NetworkFailure('...')))` and have it compare
/// by value instead of by identity.
sealed class Failure {
  /// Human-readable description of what went wrong, safe to surface in a
  /// `SnackBar` or similar UI affordance.
  final String message;

  const Failure(this.message);
}

/// No connectivity to the server, or a request that timed out before a
/// response was ever received.
class NetworkFailure extends Failure {
  const NetworkFailure(super.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NetworkFailure && other.message == message);

  @override
  int get hashCode => Object.hash(NetworkFailure, message);
}

/// The server responded, but with a 4xx or 5xx status code other than 401.
class ServerFailure extends Failure {
  /// The HTTP status code returned by the server, when available.
  final int? statusCode;

  const ServerFailure(super.message, {this.statusCode});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServerFailure &&
          other.message == message &&
          other.statusCode == statusCode);

  @override
  int get hashCode => Object.hash(ServerFailure, message, statusCode);
}

/// The request failed with a 401 and the subsequent refresh attempt also
/// failed, meaning the session is no longer valid.
class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure(super.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UnauthorizedFailure && other.message == message);

  @override
  int get hashCode => Object.hash(UnauthorizedFailure, message);
}

/// A local read or write against the `sqflite` cache failed.
class CacheFailure extends Failure {
  const CacheFailure(super.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CacheFailure && other.message == message);

  @override
  int get hashCode => Object.hash(CacheFailure, message);
}
