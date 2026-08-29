import 'api_client.dart';
import '../models/persona.dart';

// ignore_for_file: use_null_aware_elements

// FEATURE (custom personas, 2026-07-06): create/delete for the personas a
// user builds themselves. Fetching the list itself already went through
// ApiClient.get('/api/personas') directly in home_screen.dart before this
// existed, so that part isn't duplicated here -- this only adds the two
// actions that didn't exist yet.
class PersonaService {
  static Future<Persona> createPersona({
    required String name,
    required String relationshipType,
    required String personalityDescription,
    String? avatarEmoji,
    String? personality,
    String? voice,
  }) async {
    final data =
    await ApiClient.post(
      '/api/personas',
      body: {
        'name': name,
        'relationshipType': relationshipType,
        'personalityDescription': personalityDescription,
        if (avatarEmoji != null && avatarEmoji.isNotEmpty)
          'avatarEmoji': avatarEmoji,
        if (personality != null) 'personality': personality,
        if (voice != null) 'voice': voice,
      },
    )
    as Map<String, dynamic>;
    return Persona.fromJson(data);
  }

  static Future<void> deletePersona(String personaId) async {
    await ApiClient.delete('/api/personas/$personaId');
  }
}