import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:social_feed_app/core/l10n/app_localizations.dart';
import 'package:social_feed_app/features/comments/presentation/widgets/comment_input.dart';

void main() {
  Widget buildSubject(Future<bool> Function(String content) onSubmit) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CommentInput(onSubmit: onSubmit),
      ),
    );
  }

  testWidgets('a successful submit calls onSubmit with the typed content and clears the field', (
    tester,
  ) async {
    final submittedContents = <String>[];
    Future<bool> onSubmit(String content) async {
      submittedContents.add(content);
      return true;
    }

    await tester.pumpWidget(buildSubject(onSubmit));

    await tester.enterText(find.byType(TextField), 'A real comment');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(submittedContents, ['A real comment']);
    expect(find.text('A real comment'), findsNothing);
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller!.text, isEmpty);
  });

  testWidgets('a failed submit leaves the typed content in the field', (tester) async {
    final submittedContents = <String>[];
    Future<bool> onSubmit(String content) async {
      submittedContents.add(content);
      return false;
    }

    await tester.pumpWidget(buildSubject(onSubmit));

    await tester.enterText(find.byType(TextField), 'A real comment');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(submittedContents, ['A real comment']);
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller!.text, 'A real comment');
  });

  testWidgets('does not call onSubmit when the field is left empty', (tester) async {
    var callCount = 0;
    Future<bool> onSubmit(String content) async {
      callCount++;
      return true;
    }

    await tester.pumpWidget(buildSubject(onSubmit));

    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(callCount, 0);
  });
}
