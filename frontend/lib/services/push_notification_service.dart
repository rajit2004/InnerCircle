import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_service.dart';

/// FEATURE (push notifications, 2026-07-05): this is the piece that was
/// missing before -- everything in notifications_screen.dart managed
/// *scheduling*, but nothing on the client ever obtained a real FCM token or
/// registered it with the backend's already-working POST
/// /api/notifications/register. Without this, a scheduled check-in would
/// fire correctly server-side at the right time and then have nowhere to
/// deliver to -- NotificationService.sendPush() on the backend would just
/// log it instead.
///
/// What this adds:
///   1. Requests notification permission (required on Android 13+, and on
///      iOS if that's ever added).
///   2. Gets a real FCM token and registers it with the backend.
///   3. Re-registers automatically if the token ever rotates
///      (FirebaseMessaging.onTokenRefresh -- tokens aren't permanent).
///   4. Shows an actual system notification when a push arrives while the
///      app is in the foreground. FCM does NOT do this for you on Android --
///      foreground messages only fire the onMessage stream; background and
///      terminated states get an automatic system notification for free
///      because the backend's payload includes a `notification` block (see
///      NotificationService.sendPush on the backend), but foreground does
///      not, hence flutter_local_notifications is used to close that gap.
///
/// What this does NOT do: nothing here can make this work without a real
/// Firebase project. See PUSH_NOTIFICATIONS_SETUP.md for the one manual
/// step (creating the project + adding google-services.json) that has to
/// happen outside of code.
class PushNotificationService {
  static const _channelId = 'high_importance_channel';
  static const _channelName = 'Check-in reminders';
  static const _channelDescription =
      'Notifications when a persona checks in on you';

  static final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Call once, after the user is authenticated (registering a token needs
  /// a Bearer token, so this belongs after login -- see HomeScreen.initState,
  /// which runs both right after login and on every cold start where the
  /// user is already signed in).
  ///
  /// Deliberately swallows its own errors. Push notifications are a nice-to-
  /// have layered on top of a working app -- a missing Firebase config, a
  /// denied permission, or a flaky network call here should never be able
  /// to block someone from reaching the home screen and using the app.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await _createNotificationChannel();
      await _requestPermission();
      await _registerCurrentToken();

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        NotificationService.registerToken(newToken, _platformName())
            .catchError((e) {
          debugPrint('PushNotificationService: token refresh registration failed: $e');
        });
      });

      FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    } catch (e) {
      // Expected until PUSH_NOTIFICATIONS_SETUP.md's Firebase console step
      // is done -- firebase_options.dart's placeholder values will make
      // Firebase.initializeApp() (called in main.dart, before this runs)
      // throw. Logging rather than rethrowing keeps the rest of the app
      // working normally in the meantime.
      debugPrint('PushNotificationService.initialize() failed: $e');
    }
  }

  static Future<void> _createNotificationChannel() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(initSettings);

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> _requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('Push notification permission: ${settings.authorizationStatus}');
  }

  static Future<void> _registerCurrentToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) {
      debugPrint('PushNotificationService: no FCM token available yet');
      return;
    }
    await NotificationService.registerToken(token, _platformName());
  }

  static void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  static String _platformName() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }
}

/// Must be a top-level (not class-member) function annotated exactly like
/// this -- FirebaseMessaging.onBackgroundMessage requires a top-level or
/// static entry point so it can be invoked from a separate isolate when the
/// app is fully terminated. Kept intentionally minimal: messages with a
/// `notification` payload (which is what the backend always sends, see
/// NotificationService.sendPush) are already auto-displayed by FCM/the OS
/// in the background/terminated state without any code here -- this handler
/// exists mainly so background message handling is registered at all, and
/// as a hook point if data-only messages are ever added later.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background FCM message received: ${message.messageId}');
}