import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../network/api_endpoints.dart';

/// Registers this device for push notifications and displays/handles
/// whatever the backend sends through Firebase Cloud Messaging.
///
/// This is a `core/` service, not a `data/repositories/` implementation, so
/// it deliberately does not wrap every call in `Either<Failure, T>` the way
/// a repository method does; it follows the same lightweight style as
/// `ConnectivityStore` (a plain class doing best-effort platform/network
/// work, swallowing failures it cannot usefully surface to a caller) rather
/// than the full repository-layer error contract. The device registration
/// calls below are the one exception that does still go through `Dio`, per
/// the `core/network/dio_client.dart` pattern every other piece of `core/`
/// that talks to the backend follows.
///
/// The backend, not this client, is responsible for actually triggering a
/// push send (for example, notifying a post's author when someone comments
/// on it) through the Firebase Admin SDK or an equivalent server-side FCM
/// client. This service only registers/deregisters the device's token and
/// reacts to whatever message Firebase already decided to deliver.
class PushNotificationService {
  PushNotificationService({
    required this._dio,
    required this._router,
    FirebaseMessaging? firebaseMessaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _firebaseMessaging = firebaseMessaging ?? FirebaseMessaging.instance,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  final Dio _dio;
  final GoRouter _router;
  final FirebaseMessaging _firebaseMessaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  /// The Android 8+ notification channel every locally-displayed foreground
  /// notification is posted to. Android requires a channel to exist before
  /// a notification can be shown on it, hence [_initLocalNotifications]
  /// creating it up front rather than lazily on the first message.
  static const _androidChannel = AndroidNotificationChannel(
    'push_notifications',
    'Push notifications',
    description: 'Notifications about new comments and activity on your posts.',
    importance: Importance.high,
  );

  /// The key the backend is assumed to send the target post's id under in a
  /// message's `data` payload, per this branch's task list ("assume the
  /// backend sends a data field like `postId`").
  static const _postIdDataKey = 'postId';

  /// The most recently registered push token, kept only so [deregister] can
  /// call `DELETE /devices/:pushToken` without needing to fetch the token
  /// again; `FirebaseMessaging.instance.getToken()` can return a different
  /// value across calls once a token has rotated.
  String? _registeredToken;

  /// Runs the full push notification setup: requests permission, retrieves
  /// and registers the device token, wires the foreground/tap handlers, and
  /// initializes local notification display.
  ///
  /// Callers are expected to guard this call in their own try/catch (see
  /// `bootstrap.dart`): `Firebase.initializeApp()` throws if the native
  /// `google-services.json`/`GoogleService-Info.plist` config is missing,
  /// which is expected in an environment with no real Firebase project, and
  /// push notifications are an optional bonus feature the rest of the app
  /// must keep working without.
  Future<void> initialize() async {
    await Firebase.initializeApp();

    await _initLocalNotifications();
    await _firebaseMessaging.requestPermission();

    final token = await _firebaseMessaging.getToken();
    if (token != null) {
      await _registerToken(token);
    }

    // Tokens can rotate (app reinstall, token expiry, backup restore), so
    // every refresh needs to be re-registered with the backend, not just
    // the token retrieved above at startup.
    _firebaseMessaging.onTokenRefresh.listen(_registerToken);

    // FCM shows a system notification automatically for a background or
    // terminated-state message that carries a `notification` payload; only
    // the foreground case needs flutter_local_notifications, since FCM does
    // not auto-display anything while the app is already in the foreground.
    FirebaseMessaging.onMessage.listen(_showLocalNotification);

    // A tap on a background-delivered notification resumes the app through
    // this stream; a tap that instead cold-started the app from a
    // terminated state is only observable through getInitialMessage below.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageTap(initialMessage);
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    // Permission is requested through FirebaseMessaging.requestPermission
    // above instead, so the Darwin init here does not also prompt the user
    // a second time for the same alert/sound/badge permissions.
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        final postId = response.payload;
        if (postId != null) {
          _navigateToPost(postId);
        }
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) {
      return;
    }

    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: extractPostId(message.data),
    );
  }

  void _handleMessageTap(RemoteMessage message) {
    final postId = extractPostId(message.data);
    if (postId != null) {
      _navigateToPost(postId);
    }
  }

  void _navigateToPost(String postId) {
    _router.go('/posts/$postId');
  }

  /// Extracts the target post id from a message's `data` payload, or `null`
  /// if the message did not carry one.
  ///
  /// Pulled out as a standalone static method so it is testable without a
  /// real `RemoteMessage`/Firebase instance: the map shape is all this
  /// logic actually depends on.
  @visibleForTesting
  static String? extractPostId(Map<String, dynamic> data) =>
      data[_postIdDataKey] as String?;

  /// Builds the `POST /devices` request body for [pushToken], per the API
  /// Contract's `{ pushToken, platform }` shape.
  ///
  /// Pulled out as a standalone static method for the same reason as
  /// [extractPostId]: it is pure data shaping, testable without touching
  /// `dio` or Firebase.
  @visibleForTesting
  static Map<String, dynamic> buildDeviceRegistrationBody(String pushToken) => {
    'pushToken': pushToken,
    'platform': currentPlatformName,
  };

  /// The lowercase platform name sent as `platform` in the device
  /// registration body. The API Contract does not enumerate the expected
  /// values beyond the field's name, so this follows the obvious
  /// `Platform.isAndroid`/`Platform.isIOS` convention rather than inventing
  /// a stricter enum the backend was never told about.
  @visibleForTesting
  static String get currentPlatformName {
    if (kIsWeb) {
      return 'web';
    }
    if (Platform.isAndroid) {
      return 'android';
    }
    if (Platform.isIOS) {
      return 'ios';
    }
    return 'unknown';
  }

  Future<void> _registerToken(String token) async {
    try {
      await _dio.post<void>(
        ApiEndpoints.devices,
        data: buildDeviceRegistrationBody(token),
      );
      _registeredToken = token;
    } catch (_) {
      // Best-effort: a failed registration call is not surfaced anywhere
      // actionable (there is no UI slot for "push registration failed"),
      // and the next onTokenRefresh/app restart gets another chance.
      // Catches more than just DioException on purpose: this also runs as
      // an onTokenRefresh stream listener (see initialize()), where an
      // uncaught error would otherwise escape as an unhandled stream error
      // instead of staying contained to this best-effort operation.
    }
  }

  /// Deregisters the currently registered device token via
  /// `DELETE /devices/:pushToken`, if one was ever successfully registered.
  ///
  /// Called from `AuthStore.signOut`/`forceSignOut` so a session that is no
  /// longer valid on this device does not keep receiving push notifications
  /// meant for whoever signs in next.
  ///
  /// [accessToken], when supplied, is attached directly as this one
  /// request's `Authorization` header instead of relying on
  /// `AuthInterceptor`'s usual storage-backed attachment. `forceSignOut`
  /// needs this: by the time it runs, `AuthInterceptor` has already cleared
  /// the stored access token, so `onRequest` would otherwise have nothing
  /// left to attach and this authenticated call would 401. `signOut` does
  /// not need to pass one, since it deregisters before the stored token is
  /// cleared and the interceptor's normal path already has a valid token to
  /// attach.
  Future<void> deregister({String? accessToken}) async {
    final token = _registeredToken;
    if (token == null) {
      return;
    }
    try {
      await _dio.delete<void>(
        ApiEndpoints.deviceByPushToken(token),
        options: accessToken == null
            ? null
            : Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      // Only forgotten once the server actually confirms it: clearing this
      // unconditionally (e.g. in a `finally`) would mean a failed call
      // (offline sign-out, a transient 5xx) silently gives up on ever
      // deregistering this token, leaving it registered server-side with
      // no way for a later retry in this same session to know it still
      // needs to.
      _registeredToken = null;
    } catch (_) {
      // Best-effort, same reasoning as _registerToken above: this is
      // documented on the class as never throwing, since AuthStore.signOut
      // awaits it with no guard of its own beyond that contract.
    }
  }
}
