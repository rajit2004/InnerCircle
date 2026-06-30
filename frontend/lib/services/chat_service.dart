import 'api_client.dart';

class ChatService {
  // BUG FIX (frontend, 2026-06-30): sendMessage() (the SSE-based one) is
  // removed. It called ApiClient.streamChat(), which no longer matches
  // what the backend sends -- see api_client.dart and bugs.md Bug 1 for
  // the full explanation. sendMessageSync() below was already correctly
  // written and already calling the right endpoint (/api/chat/sync);
  // chat_screen.dart just wasn't using it. This is now the only chat
  // method, since it's the only one that actually matches the backend.
  static Future<Map<String, dynamic>> sendMessage(
      String personaId,
      String content, {
        String? conversationId,
      }) async {
    final body = {
      'personaId': personaId,
      'content': content,
      if (conversationId != null) 'conversationId': conversationId,
    };
    return await ApiClient.post('/api/chat/sync', body: body) as Map<String, dynamic>;
  }
}