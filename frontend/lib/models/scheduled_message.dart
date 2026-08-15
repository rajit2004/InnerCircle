import 'package:flutter/material.dart';

/// FEATURE (notification management, 2026-07-04): mirrors backend
/// ScheduledMessageResponse. daysOfWeek uses the same 1=Sunday..7=Saturday
/// convention as the backend (matching Postgres EXTRACT(DOW), see
/// NotificationService) -- kept as a raw CSV string here too and only
/// converted to a display label in the UI, so there's exactly one place
/// (weekdayLabels below) that has to agree with the backend's day numbering.
class ScheduledMessage {
  final String id;
  final String personaId;
  final String personaName;
  final String? personaAvatarEmoji;
  final TimeOfDay scheduledAt;
  final String daysOfWeek; // CSV, e.g. "1,2,3,4,5,6,7"
  final String messageType;
  final bool active;
  final DateTime? lastSentAt;

  ScheduledMessage({
    required this.id,
    required this.personaId,
    required this.personaName,
    this.personaAvatarEmoji,
    required this.scheduledAt,
    required this.daysOfWeek,
    required this.messageType,
    required this.active,
    this.lastSentAt,
  });

  factory ScheduledMessage.fromJson(Map<String, dynamic> json) {
    // BUG FIX: previously assumed scheduledAt was always a "HH:mm" string and
    // did int.parse on raw substrings -- a null, non-string, or malformed
    // value threw and took down the entire reminders list. Parse defensively.
    TimeOfDay parseTime(dynamic raw) {
      final str = raw?.toString();
      if (str == null || str.isEmpty) return const TimeOfDay(hour: 0, minute: 0);
      final parts = str.split(':');
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
    }

    return ScheduledMessage(
      id: json['id'] as String? ?? '',
      personaId: json['personaId'] as String? ?? '',
      personaName: json['personaName'] as String? ?? 'Unknown',
      personaAvatarEmoji: json['personaAvatarEmoji'] as String?,
      scheduledAt: parseTime(json['scheduledAt']),
      daysOfWeek: json['daysOfWeek'] as String? ?? '1,2,3,4,5,6,7',
      messageType: json['messageType'] as String? ?? 'check_in',
      active: json['active'] as bool? ?? true,
      lastSentAt: json['lastSentAt'] != null
          ? DateTime.tryParse(json['lastSentAt'] as String)
          : null,
    );
  }

  /// 1=Sunday..7=Saturday, matching the backend's convention exactly.
  static const Map<int, String> weekdayLabels = {
    1: 'Sun',
    2: 'Mon',
    3: 'Tue',
    4: 'Wed',
    5: 'Thu',
    6: 'Fri',
    7: 'Sat',
  };

  List<int> get selectedDays => daysOfWeek
      .split(',')
      .where((s) => s.trim().isNotEmpty)
      .map((s) => int.parse(s.trim()))
      .toList()
    ..sort();

  String get daysLabel {
    final days = selectedDays;
    if (days.length == 7) return 'Every day';
    if (days.isEmpty) return 'No days selected';
    return days.map((d) => weekdayLabels[d] ?? '?').join(', ');
  }

  String get timeLabel {
    final hour = scheduledAt.hourOfPeriod == 0 ? 12 : scheduledAt.hourOfPeriod;
    final minute = scheduledAt.minute.toString().padLeft(2, '0');
    final period = scheduledAt.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}