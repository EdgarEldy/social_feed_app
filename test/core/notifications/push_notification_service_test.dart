import 'package:flutter_test/flutter_test.dart';

import 'package:social_feed_app/core/notifications/push_notification_service.dart';

void main() {
  group('PushNotificationService.extractPostId', () {
    test('returns the postId value when present in the data payload', () {
      final data = {'postId': 'post-123', 'type': 'new_comment'};

      expect(PushNotificationService.extractPostId(data), 'post-123');
    });

    test('returns null when the data payload has no postId key', () {
      final data = {'type': 'new_comment'};

      expect(PushNotificationService.extractPostId(data), isNull);
    });

    test('returns null for an empty data payload', () {
      expect(PushNotificationService.extractPostId(const {}), isNull);
    });
  });

  group('PushNotificationService.buildDeviceRegistrationBody', () {
    test('includes the given pushToken and the current platform name', () {
      final body = PushNotificationService.buildDeviceRegistrationBody(
        'token-abc',
      );

      expect(body['pushToken'], 'token-abc');
      expect(body['platform'], PushNotificationService.currentPlatformName);
    });

    test('matches the API contract shape: only pushToken and platform', () {
      final body = PushNotificationService.buildDeviceRegistrationBody(
        'token-xyz',
      );

      expect(body.keys, containsAll(['pushToken', 'platform']));
      expect(body.length, 2);
    });
  });
}
