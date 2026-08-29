import 'api_client.dart';
import '../models/user_profile.dart';

class UserService {
  static Future<UserProfile> getProfile() async {
    final data = await ApiClient.get('/api/users/me') as Map<String, dynamic>;
    return UserProfile.fromJson(data);
  }

  static Future<UserProfile> updateSubscription(String tier) async {
    final data =
    await ApiClient.post('/api/users/subscription', body: {'tier': tier})
    as Map<String, dynamic>;
    final profile = UserProfile.fromJson(data);
    await ApiClient.setSubscriptionTier(profile.subscriptionTier);
    return profile;
  }
}