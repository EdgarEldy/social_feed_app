import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:social_feed_app/app/theme/app_theme.dart';
import 'package:social_feed_app/core/l10n/app_localizations.dart';
import 'package:social_feed_app/features/likes/domain/usecases/toggle_like_usecase.dart';
import 'package:social_feed_app/features/likes/presentation/stores/like_store.dart';
import 'package:social_feed_app/features/likes/presentation/widgets/like_button.dart';

class _MockToggleLikeUseCase extends Mock implements ToggleLikeUseCase {}

void main() {
  // LikeButton takes its LikeStore straight from the caller (see the
  // widget's own class doc), so no get_it registration is needed here,
  // matching like_button_test.dart's setup.
  late _MockToggleLikeUseCase toggleLikeUseCase;

  setUp(() {
    toggleLikeUseCase = _MockToggleLikeUseCase();
  });

  const boundaryKey = Key('like_button_golden_boundary');

  Future<void> pumpLikeButton(
    WidgetTester tester,
    ThemeData theme, {
    required bool isLiked,
  }) async {
    final store = LikeStore(
      isLiked: isLiked,
      likesCount: isLiked ? 43 : 42,
      toggleLikeUseCase: toggleLikeUseCase,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Without its own RepaintBoundary, matchesGoldenFile would bubble
        // up to the app's root boundary and capture the entire test
        // surface instead of just this small icon-and-count row.
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: LikeButton(store: store, postId: 'post-1'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('LikeButton golden', () {
    testWidgets('unliked state matches the light theme reference image', (tester) async {
      await pumpLikeButton(tester, AppTheme.light, isLiked: false);

      await expectLater(
        find.byKey(boundaryKey),
        matchesGoldenFile('goldens/like_button_unliked_light.png'),
      );
    });

    testWidgets('unliked state matches the dark theme reference image', (tester) async {
      await pumpLikeButton(tester, AppTheme.dark, isLiked: false);

      await expectLater(
        find.byKey(boundaryKey),
        matchesGoldenFile('goldens/like_button_unliked_dark.png'),
      );
    });

    testWidgets('liked state matches the light theme reference image', (tester) async {
      await pumpLikeButton(tester, AppTheme.light, isLiked: true);

      await expectLater(
        find.byKey(boundaryKey),
        matchesGoldenFile('goldens/like_button_liked_light.png'),
      );
    });

    testWidgets('liked state matches the dark theme reference image', (tester) async {
      await pumpLikeButton(tester, AppTheme.dark, isLiked: true);

      await expectLater(
        find.byKey(boundaryKey),
        matchesGoldenFile('goldens/like_button_liked_dark.png'),
      );
    });
  });
}
