import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/models/chat_message.dart';
import 'package:frontend/services/chat_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ChatMessage serialization', () {
    test('round-trips through toJson/fromJson', () {
      final original = ChatMessage(
        id: 'm1',
        role: 'assistant',
        content: 'Hello there',
        timestamp: DateTime.utc(2026, 1, 2, 3, 4, 5),
        reaction: '❤️',
      );

      final restored = ChatMessage.fromJson(original.toJson());

      expect(restored.id, 'm1');
      expect(restored.role, 'assistant');
      expect(restored.content, 'Hello there');
      expect(restored.timestamp, original.timestamp);
      expect(restored.reaction, '❤️');
      expect(restored.failed, isFalse);
    });

    test('handles minimal payload without id or timestamp', () {
      final restored = ChatMessage.fromJson({'role': 'user', 'content': 'hi'});

      expect(restored.id, isNull);
      expect(restored.timestamp, isNull);
      expect(restored.reaction, isNull);
    });
  });

  group('ChatCache', () {
    test('save then load returns conversation and messages', () async {
      final messages = [
        ChatMessage(
          id: 'a',
          role: 'user',
          content: 'hey',
          timestamp: DateTime.utc(2026, 5, 1),
        ),
        ChatMessage(id: 'b', role: 'assistant', content: 'hi!'),
      ];

      await ChatCache.save('persona-1', 'conv-1', messages);
      final loaded = await ChatCache.load('persona-1');

      expect(loaded, isNotNull);
      expect(loaded!['conversationId'], 'conv-1');
      final restored = loaded['messages'] as List<ChatMessage>;
      expect(restored, hasLength(2));
      expect(restored.first.content, 'hey');
      expect(restored.last.role, 'assistant');
    });

    test('failed messages are not cached', () async {
      final messages = [
        ChatMessage(role: 'user', content: 'ok'),
        ChatMessage(role: 'user', content: 'bad', failed: true),
      ];

      await ChatCache.save('persona-2', 'conv-2', messages);
      final loaded = await ChatCache.load('persona-2');

      final restored = loaded!['messages'] as List<ChatMessage>;
      expect(restored, hasLength(1));
      expect(restored.single.content, 'ok');
    });

    test('null conversation id clears the cache', () async {
      await ChatCache.save('persona-3', 'conv-3', [
        ChatMessage(role: 'user', content: 'hey'),
      ]);
      await ChatCache.save('persona-3', null, []);

      expect(await ChatCache.load('persona-3'), isNull);
    });

    test('load returns null for corrupt payload', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('chat_cache_persona-4', 'not-json');

      expect(await ChatCache.load('persona-4'), isNull);
    });

    test('load returns null for empty message list', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'chat_cache_persona-5',
        jsonEncode({'conversationId': 'c', 'messages': []}),
      );

      expect(await ChatCache.load('persona-5'), isNull);
    });

    test('clear removes the cached conversation', () async {
      await ChatCache.save('persona-6', 'conv-6', [
        ChatMessage(role: 'user', content: 'hey'),
      ]);
      await ChatCache.clear('persona-6');

      expect(await ChatCache.load('persona-6'), isNull);
    });
  });
}
