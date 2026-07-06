import 'api_client.dart';
import '../models/user_profile.dart';

class UserService {
  static Future<UserProfile> getProfile() async {
    final data = await ApiClient.get('/api/users/me') as Map<String, dynamic>;
    return UserProfile.fromJson(data);
  }
}
