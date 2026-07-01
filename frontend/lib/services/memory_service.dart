import 'api_client.dart';
import '../models/memory.dart';

class MemoryService {
  static Future<List<Memory>> getMemories({String? personaId}) async {
    final endpoint = personaId != null
        ? '/api/memories?personaId=$personaId'
        : '/api/memories';
    final data = await ApiClient.get(endpoint);
    if (data == null) return [];
    return (data as List).map((json) => Memory.fromJson(json)).toList();
  }

  static Future<void> deleteMemory(String id) async {
    await ApiClient.delete('/api/memories/$id');
  }
}
