import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'api_client.dart';
import '../models/user_profile.dart';

class UserService {
  static Future<UserProfile> getProfile() async {
    final data = await ApiClient.get('/api/users/me') as Map<String, dynamic>;
    return UserProfile.fromJson(data);
  }

  static Future<UserProfile> updateProfile({
    String? displayName,
    String? dateOfBirth,
    String? language,
    String? timezone,
  }) async {
    final body = <String, dynamic>{};
    if (displayName != null) body['displayName'] = displayName;
    if (dateOfBirth != null) body['dateOfBirth'] = dateOfBirth;
    if (language != null) body['language'] = language;
    if (timezone != null) body['timezone'] = timezone;

    final data = await ApiClient.put('/api/users/me', body: body) as Map<String, dynamic>;
    return UserProfile.fromJson(data);
  }

  static Future<UserProfile> uploadAvatar(File imageFile) async {
    final uri = Uri.parse('$baseUrl/api/users/me/avatar');
    final request = http.MultipartRequest('POST', uri);

    final token = await ApiClient.getToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.files.add(await http.MultipartFile.fromPath(
      'file',
      imageFile.path,
      filename: p.basename(imageFile.path),
    ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isNotEmpty) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return UserProfile.fromJson(data);
      }
      return getProfile();
    }
    throw Exception('Failed to upload avatar: ${response.statusCode}');
  }

  static Future<UserProfile> updateSubscription(String tier) async {
    final data = await ApiClient.post('/api/users/subscription', body: {'tier': tier}) as Map<String, dynamic>;
    final profile = UserProfile.fromJson(data);
    await ApiClient.setSubscriptionTier(profile.subscriptionTier);
    return profile;
  }

  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await ApiClient.put('/api/users/me/password', body: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  static Future<void> deleteAccount() async {
    await ApiClient.delete('/api/users/me');
    await ApiClient.clearToken();
  }
}
