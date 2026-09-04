import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:social_feed_app/core/di/injection_container.dart';
import 'package:social_feed_app/core/errors/failure.dart';
import 'package:social_feed_app/core/l10n/app_localizations.dart';
import 'package:social_feed_app/core/storage/secure_token_storage.dart';
import 'package:social_feed_app/features/auth/domain/entities/user.dart';
import 'package:social_feed_app/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:social_feed_app/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:social_feed_app/features/auth/domain/usecases/sign_up_usecase.dart';
import 'package:social_feed_app/features/auth/presentation/stores/auth_store.dart';
import 'package:social_feed_app/features/users/domain/usecases/get_user_usecase.dart';
import 'package:social_feed_app/features/users/presentation/pages/profile_page.dart';

class _MockGetUserUseCase extends Mock implements GetUserUseCase {}

class _MockSignInUseCase extends Mock implements SignInUseCase {}

class _MockSignUpUseCase extends Mock implements SignUpUseCase {}

class _MockSignOutUseCase extends Mock implements SignOutUseCase {}

class _MockSecureTokenStorage extends Mock implements SecureTokenStorage {}

void main() {
  late _MockGetUserUseCase getUserUseCase;

  final user = User(
    id: 'user-1',
    displayName: 'Ada Lovelace',
    email: 'ada@example.com',
    createdAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    getUserUseCase = _MockGetUserUseCase();
    getIt.registerSingleton<GetUserUseCase>(getUserUseCase);

    // ProfilePage's app bar reads getIt<AuthStore>() to decide whether to
    // show the edit action, so a real AuthStore (built against mocked
    // collaborators, same pattern as login_page_test.dart) needs to be
    // registered even though this test is not exercising auth itself.
    getIt.registerSingleton<AuthStore>(
      AuthStore(
        signUpUseCase: _MockSignUpUseCase(),
        signInUseCase: _MockSignInUseCase(),
        signOutUseCase: _MockSignOutUseCase(),
        tokenStorage: _MockSecureTokenStorage(),
      ),
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('shows a loading indicator, then the loaded user\'s display name', (tester) async {
    final completer = Completer<Either<Failure, User>>();
    when(() => getUserUseCase.call('user-1')).thenAnswer((_) => completer.future);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ProfilePage(userId: 'user-1'),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsNothing);

    completer.complete(Right(user));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Ada Lovelace'), findsOneWidget);
  });

  testWidgets('shows an ErrorView when loading the user fails', (tester) async {
    when(() => getUserUseCase.call('user-1')).thenAnswer(
      (_) async => const Left(ServerFailure('Unexpected server error.', statusCode: 500)),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ProfilePage(userId: 'user-1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Unexpected server error.'), findsOneWidget);
  });
}
