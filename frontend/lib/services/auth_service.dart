import 'dart:convert';

import '../models/user.dart';
import 'api_client.dart';

class AuthService {
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final body = {'email': email, 'password': password};
    final response =
        await ApiClient.post('/api/auth/login', body: body, auth: false)
            as Map<String, dynamic>;
    await _saveSession(response);
    return response;
  }

  static Future<Map<String, dynamic>> register(
    String email,
    String password,
  ) async {
    final body = {'email': email, 'password': password};
    final response =
        await ApiClient.post('/api/auth/register', body: body, auth: false)
            as Map<String, dynamic>;
    await _saveSession(response);
    return response;
  }

  static Future<void> logout() async {
    await ApiClient.clearToken();
  }

  static Future<bool> isLoggedIn() async {
    return await ApiClient.getToken() != null;
  }

  static Future<User?> currentUser() async {
    final token = await ApiClient.getToken();
    if (token == null) return null;

    final stored = await ApiClient.getStoredProfile();
    final claims = _decodeJwtPayload(token);

    return User(
      id: stored['id'] ?? _asString(claims['sub']),
      email:
          stored['email'] ??
          _asString(claims['email'], fallback: 'Unknown email'),
      role: stored['role'] ?? _asString(claims['role'], fallback: 'USER'),
      subscriptionTier: stored['subscriptionTier'] ?? 'free',
      token: token,
    );
  }

  static Future<void> updateSubscriptionTier(String subscriptionTier) async {
    await ApiClient.setSubscriptionTier(subscriptionTier);
  }

  static Future<void> _saveSession(Map<String, dynamic> response) async {
    final token = response['token'] as String?;
    if (token == null || token.isEmpty) return;

    final claims = _decodeJwtPayload(token);
    final subscriptionTier = _asString(
      response['subscriptionTier'],
      fallback: 'free',
    );

    await ApiClient.setSession(
      token: token,
      id: _asString(claims['sub']),
      email: _asString(
        response['email'] ?? claims['email'],
        fallback: 'Unknown email',
      ),
      role: _asString(response['role'] ?? claims['role'], fallback: 'USER'),
      subscriptionTier: subscriptionTier,
    );
  }

  static Map<String, dynamic> _decodeJwtPayload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return {};

    try {
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(decoded);
      return payload is Map<String, dynamic> ? payload : {};
    } catch (_) {
      return {};
    }
  }

  static String _asString(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }
}
