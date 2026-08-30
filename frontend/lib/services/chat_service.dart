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

  // FEATURE (message reactions, round 12): sets or clears (reaction == null)
  // the reaction on a single message. Fire-and-forget from the UI's
  // perspective -- the caller updates local state optimistically and this
  // just persists it server-side.
  static Future<void> setReaction(String messageId, String? reaction) async {
    await ApiClient.put(
      '/api/chat/messages/$messageId/reaction',
      body: {'reaction': reaction},
    );
  }

  // FEATURE (clear chat, 2026-07-06): deletes the most recent server-side
  // conversation for this persona, so "clear chat" actually wipes history
  // instead of only resetting local state.
  static Future<void> deleteConversation(String personaId) async {
    await ApiClient.delete('/api/chat?personaId=$personaId');
  }

  // FEATURE (regenerate, round 15): deletes the last assistant message and
  // re-runs the LLM to get a fresh reply. Returns the same shape as
  // sendMessage: {reply, conversationId, messageId}.
  static Future<Map<String, dynamic>> regenerate(
      String personaId, String conversationId) async {
    return await ApiClient.post(
      '/api/chat/regenerate',
      body: {
        'personaId': personaId,
        'conversationId': conversationId,
      },
    ) as Map<String, dynamic>;
  }
}