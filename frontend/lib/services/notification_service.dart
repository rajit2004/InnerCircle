import 'package:flutter/material.dart';

import 'api_client.dart';
import '../models/scheduled_message.dart';

// FEATURE (notification management, 2026-07-04): thin wrapper around the new
// GET/DELETE/toggle endpoints on NotificationController. Deliberately does
// NOT touch push-token registration or request notification permissions --
// this project doesn't have the firebase_messaging package wired into
// pubspec.yaml yet, so there's no real FCM token to register from the
// client side. What this DOES give you is full control over what check-ins
// are scheduled and when, backed by real persisted data -- actually
// receiving those as device push notifications is a separate follow-up that
// needs firebase_messaging added, permission requests, and wiring the
// resulting token to POST /api/notifications/register (which already exists
// and already works, it just has nothing calling it yet).
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
}