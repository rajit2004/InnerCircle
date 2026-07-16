import 'api_client.dart';
import '../models/user_profile.dart';

class UserService {
  static Future<UserProfile> getProfile() async {
    final data = await ApiClient.get('/api/users/me') as Map<String, dynamic>;
    return UserProfile.fromJson(data);
  }

  // FEATURE (subscription upgrade, 2026-07-04): mock/manual tier toggle --
  // there's no payment gateway integrated in this project, so this calls a
  // backend endpoint that just sets the tier directly. See UserService.java
  // and UserController.java on the backend for the full reasoning. Returns
  // the updated profile so callers can refresh their display without a
  // second round trip.
  static Future<UserProfile> updateSubscription(String tier) async {
    final data =
    await ApiClient.post('/api/users/subscription', body: {'tier': tier})
    as Map<String, dynamic>;
    return UserProfile.fromJson(data);
  }
}