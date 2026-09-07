import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:social_feed_app/core/errors/failure.dart';
import 'package:social_feed_app/core/l10n/app_localizations.dart';
import 'package:social_feed_app/features/likes/domain/usecases/toggle_like_usecase.dart';
import 'package:social_feed_app/features/likes/presentation/stores/like_store.dart';
import 'package:social_feed_app/features/likes/presentation/widgets/like_button.dart';

class _MockToggleLikeUseCase extends Mock implements ToggleLikeUseCase {}

void main() {
  late _MockToggleLikeUseCase toggleLikeUseCase;

  setUp(() {
    toggleLikeUseCase = _MockToggleLikeUseCase();
  });

  Future<void> pumpLikeButton(WidgetTester tester, LikeStore store) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: LikeButton(store: store, postId: 'post-1')),
      ),
    );
  }

  group('LikeButton', () {
    testWidgets('flips icon and count immediately on tap, ahead of the usecase resolving', (tester) async {
      final completer = Completer<Either<Failure, ({bool liked, int likesCount})>>();
      when(() => toggleLikeUseCase.call('post-1')).thenAnswer((_) => completer.future);

      final store = LikeStore(isLiked: false, likesCount: 3, toggleLikeUseCase: toggleLikeUseCase);
      await pumpLikeButton(tester, store);

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      await tester.tap(find.byType(IconButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsNothing);
      expect(find.text('4'), findsOneWidget);

      completer.complete(const Right((liked: true, likesCount: 4)));
      await tester.pumpAndSettle();
    });

    testWidgets('reconciles with the mocked response once the usecase call resolves', (tester) async {
      final completer = Completer<Either<Failure, ({bool liked, int likesCount})>>();
      when(() => toggleLikeUseCase.call('post-1')).thenAnswer((_) => completer.future);

      final store = LikeStore(isLiked: false, likesCount: 3, toggleLikeUseCase: toggleLikeUseCase);
      await pumpLikeButton(tester, store);

      await tester.tap(find.byType(IconButton));
      await tester.pump();

      // The server disagrees with the optimistic guess, e.g. another client
      // liked the post in between; the store reconciles with its response
      // rather than trusting the optimistic count.
      completer.complete(const Right((liked: true, likesCount: 9)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
    });

    testWidgets('reverts to the pre-tap state and shows an error on a failed toggle', (tester) async {
      final completer = Completer<Either<Failure, ({bool liked, int likesCount})>>();
      when(() => toggleLikeUseCase.call('post-1')).thenAnswer((_) => completer.future);

      final store = LikeStore(isLiked: false, likesCount: 3, toggleLikeUseCase: toggleLikeUseCase);
      await pumpLikeButton(tester, store);

      await tester.tap(find.byType(IconButton));
      await tester.pump();

      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.text('4'), findsOneWidget);

      completer.complete(const Left(NetworkFailure('No connection to the server.')));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNothing);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('No connection to the server.'), findsOneWidget);
    });

    testWidgets('ignores a second tap while a toggle is still in flight', (tester) async {
      final completer = Completer<Either<Failure, ({bool liked, int likesCount})>>();
      when(() => toggleLikeUseCase.call('post-1')).thenAnswer((_) => completer.future);

      final store = LikeStore(isLiked: false, likesCount: 3, toggleLikeUseCase: toggleLikeUseCase);
      await pumpLikeButton(tester, store);

      await tester.tap(find.byType(IconButton));
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pump();

      verify(() => toggleLikeUseCase.call('post-1')).called(1);

      completer.complete(const Right((liked: true, likesCount: 4)));
      await tester.pumpAndSettle();
    });
  });
}
