import 'api_client.dart';

class ChatService {
  static Future<Stream<String>> sendMessage(String personaId, String content, {String? conversationId}) async {
    final body = {
      'personaId': personaId,
      'content': content,
      if (conversationId != null) 'conversationId': conversationId,
    };
    return ApiClient.streamChat(body);
  }

  static Future<Map<String, dynamic>> sendMessageSync(String personaId, String content, {String? conversationId}) async {
    final body = {
      'personaId': personaId,
      'content': content,
      if (conversationId != null) 'conversationId': conversationId,
    };
    return await ApiClient.post('/api/chat/sync', body: body);
  }
}