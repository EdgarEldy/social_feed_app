import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:social_feed_app/app/app.dart';
import 'package:social_feed_app/app/theme/theme_mode_controller.dart';
import 'package:social_feed_app/core/di/injection_container.dart';

/// A [ThemeModeController] that records whether [dispose] was called, used
/// to assert on ownership of a controller passed into [App] from the
/// outside.
class _TrackingThemeModeController extends ThemeModeController {
  _TrackingThemeModeController({super.initialMode});

  bool disposeCalled = false;

  @override
  void dispose() {
    disposeCalled = true;
    super.dispose();
  }
}

void main() {
  setUp(() {
    configureDependencies(dioFactory: Dio.new);
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('ThemeModeController', () {
    test('defaults to ThemeMode.system', () {
      final controller = ThemeModeController();

      expect(controller.mode, ThemeMode.system);
    });

    test('setThemeMode updates the mode', () {
      final controller = ThemeModeController();

      controller.setThemeMode(ThemeMode.dark);

      expect(controller.mode, ThemeMode.dark);
    });

    test('setThemeMode notifies listeners when the mode actually changes', () {
      final controller = ThemeModeController();
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.setThemeMode(ThemeMode.dark);

      expect(notifications, 1);
    });

    test('setThemeMode does not notify listeners when the mode is unchanged', () {
      final controller = ThemeModeController(initialMode: ThemeMode.dark);
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.setThemeMode(ThemeMode.dark);

      expect(notifications, 0);
    });
  });

  group('theme toggle', () {
    testWidgets('switches the active ColorScheme brightness when the mode changes', (
      tester,
    ) async {
      final controller = ThemeModeController(initialMode: ThemeMode.light);

      await tester.pumpWidget(App(themeModeController: controller));
      await tester.pumpAndSettle();

      final lightContext = tester.element(find.byType(Scaffold));
      final lightScheme = Theme.of(lightContext).colorScheme;
      expect(lightScheme.brightness, Brightness.light);

      controller.setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle();

      final darkContext = tester.element(find.byType(Scaffold));
      final darkScheme = Theme.of(darkContext).colorScheme;
      expect(darkScheme.brightness, Brightness.dark);

      expect(darkScheme, isNot(equals(lightScheme)));
    });
  });

  group('App controller ownership', () {
    testWidgets('does not dispose a caller-supplied controller when App leaves the tree', (
      tester,
    ) async {
      final controller = _TrackingThemeModeController(
        initialMode: ThemeMode.light,
      );

      await tester.pumpWidget(App(themeModeController: controller));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      expect(controller.disposeCalled, isFalse);

      // Still perfectly usable, since App never called dispose() on it.
      controller.setThemeMode(ThemeMode.dark);
      expect(controller.mode, ThemeMode.dark);

      controller.dispose();
    });

    testWidgets('didUpdateWidget re-attaches the listener when the controller instance changes', (
      tester,
    ) async {
      final controllerA = ThemeModeController(initialMode: ThemeMode.light);
      final controllerB = ThemeModeController(initialMode: ThemeMode.light);
      addTearDown(controllerA.dispose);
      addTearDown(controllerB.dispose);

      const appKey = Key('app');
      await tester.pumpWidget(
        App(key: appKey, themeModeController: controllerA),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        App(key: appKey, themeModeController: controllerB),
      );
      await tester.pumpAndSettle();

      // The old controller no longer drives the tree once its instance has
      // been swapped out.
      controllerA.setThemeMode(ThemeMode.dark);
      await tester.pump();
      final schemeAfterOldControllerChange = Theme.of(
        tester.element(find.byType(Scaffold)),
      ).colorScheme;
      expect(schemeAfterOldControllerChange.brightness, Brightness.light);

      // The new controller does drive the tree.
      controllerB.setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle();
      final schemeAfterNewControllerChange = Theme.of(
        tester.element(find.byType(Scaffold)),
      ).colorScheme;
      expect(schemeAfterNewControllerChange.brightness, Brightness.dark);
    });
  });
}
