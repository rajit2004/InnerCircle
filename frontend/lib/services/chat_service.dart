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
}
