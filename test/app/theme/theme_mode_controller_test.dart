import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:social_feed_app/app/app.dart';
import 'package:social_feed_app/app/theme/theme_mode_controller.dart';
import 'package:social_feed_app/core/di/injection_container.dart';

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
}
