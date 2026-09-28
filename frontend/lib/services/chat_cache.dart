import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_message.dart';

/// Local cache of the most recent conversation per persona, stored as a
/// JSON blob in SharedPreferences so chat history paints instantly and
/// remains readable offline. The server stays the source of truth: every
/// successful network load/save refreshes the cache.
class ChatCache {
  static String _key(String personaId) => 'chat_cache_$personaId';

  static Future<void> save(
    String personaId,
    String? conversationId,
    List<ChatMessage> messages,
  ) async {
    try {
      if (conversationId == null || conversationId.isEmpty) {
        await clear(personaId);
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'conversationId': conversationId,
        'messages': messages
            .where((m) => !m.failed)
            .map((m) => m.toJson())
            .toList(),
      };
      await prefs.setString(_key(personaId), jsonEncode(data));
    } catch (_) {
      // Cache writes are best-effort; never break the chat UI for them.
    }
  }

  /// Returns a map with `conversationId` (String) and `messages`
  /// (List of ChatMessage), or null when there is no usable cached
  /// conversation.
  static Future<Map<String, dynamic>?> load(String personaId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(personaId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final rawMessages = decoded['messages'] as List<dynamic>? ?? [];
      final messages = rawMessages
          .whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .toList();
      if (messages.isEmpty) return null;
      final conversationId = decoded['conversationId'] as String?;
      if (conversationId == null || conversationId.isEmpty) return null;
      return {'conversationId': conversationId, 'messages': messages};
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear(String personaId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(personaId));
    } catch (_) {
      // Best-effort eviction.
    }
  }
}
