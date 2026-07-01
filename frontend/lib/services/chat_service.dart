import 'api_client.dart';

class ChatService {
  static Future<Map<String, dynamic>> sendMessage(
      String personaId,
      String content, {
        String? conversationId,
      }) async {
    final body = <String, dynamic>{'personaId': personaId, 'content': content};
    if (conversationId != null) {
      body['conversationId'] = conversationId;
    }

    return await ApiClient.post('/api/chat', body: body)
    as Map<String, dynamic>;
  }

  // FEATURE (chat history, 2026-07-02): fetches the most recent conversation
  // (and its messages) for a persona, so ChatScreen can restore where the
  // user left off instead of starting a brand new conversation every time
  // the screen is reopened. Returns {'conversationId': null, 'messages': []}
  // when there's no prior conversation with this persona yet -- callers
  // should treat that as "show the greeting only", same as before this
  // existed.
  static Future<Map<String, dynamic>> getHistory(String personaId) async {
    return await ApiClient.get('/api/chat/history?personaId=$personaId')
    as Map<String, dynamic>;
  }
}