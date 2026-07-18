import 'package:flutter/material.dart';

import 'api_client.dart';
import '../models/scheduled_message.dart';

// FEATURE (notification management, 2026-07-04): thin wrapper around the
// GET/DELETE/toggle endpoints on NotificationController for managing
// scheduled check-ins.
//
// FEATURE (push notifications, 2026-07-05): registerToken() below is the
// piece that used to be missing -- it's what actually calls the backend's
// POST /api/notifications/register with a real FCM token, closing the loop
// that PushNotificationService opens (get a token -> call this -> backend
// can now actually deliver to this device). See push_notification_service.dart
// for where this gets called from.
class NotificationService {
  static Future<List<ScheduledMessage>> listScheduled() async {
    final data = await ApiClient.get('/api/notifications/scheduled') as List;
    return data
        .map((e) => ScheduledMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> schedule({
    required String personaId,
    required TimeOfDay time,
    required List<int> daysOfWeek,
    String messageType = 'check_in',
  }) async {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    await ApiClient.post(
      '/api/notifications/schedule',
      body: {
        'personaId': personaId,
        'scheduledAt': '$hh:$mm:00',
        'daysOfWeek': daysOfWeek,
        'messageType': messageType,
      },
    );
  }

  static Future<void> cancel(String scheduledMessageId) async {
    await ApiClient.delete('/api/notifications/scheduled/$scheduledMessageId');
  }

  static Future<void> setActive(String scheduledMessageId, bool active) async {
    await ApiClient.post(
      '/api/notifications/scheduled/$scheduledMessageId/toggle',
      body: {'active': active},
    );
  }

  /// Registers a real FCM device token with the backend so scheduled
  /// check-ins can actually be delivered as push notifications. Called by
  /// PushNotificationService on init and whenever the token rotates.
  static Future<void> registerToken(String token, String platform) async {
    await ApiClient.post(
      '/api/notifications/register',
      body: {'token': token, 'platform': platform},
    );
  }
}