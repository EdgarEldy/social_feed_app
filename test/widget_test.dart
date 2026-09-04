import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:social_feed_app/app/app.dart';
import 'package:social_feed_app/core/di/injection_container.dart';

void main() {
  // configureDependencies() is called with a Dio.new factory override
  // instead of the default DioClient.create, because DioClient.create()
  // reads dotenv.env['API_BASE_URL'], which throws unless dotenv.load() has
  // already run against a real .env file. That file loading is unrelated to
  // what this widget test is checking, so a plain Dio() stands in for it.
  // Everything else goes through the real production wiring.
  setUp(() {
    configureDependencies(dioFactory: Dio.new);
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('renders the login placeholder route on startup', (
    tester,
  ) async {
    await tester.pumpWidget(App());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Login'), findsOneWidget);
    expect(find.text('Login'), findsWidgets);
  });
}
