import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// BUG FIX (frontend, 2026-06-30): baseUrl was hardcoded to the iOS/macOS value
// (localhost), which silently fails on the Android emulator -- localhost from
// inside the emulator points at the emulator itself, not the host machine
// running the backend. 10.0.2.2 is the special alias the Android emulator
// provides for "the host machine's localhost". Since this project ships an
// android/ folder and is primarily being tested on an Android emulator,
// that's the default here.
//
// Android emulator:        http://10.0.2.2:8080
// iOS simulator / macOS:   http://localhost:8080
// Physical device:         http://<your_computer_ip>:8080
const String baseUrl = 'http://10.79.214.34:8080';

class ApiClient {
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _emailKey = 'user_email';
  static const String _roleKey = 'user_role';
  static const String _subscriptionTierKey = 'subscription_tier';

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<void> setSession({
    required String token,
    required String email,
    required String role,
    required String subscriptionTier,
    String? id,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    if (id != null && id.isNotEmpty) {
      await prefs.setString(_userIdKey, id);
    }
    await prefs.setString(_emailKey, email);
    await prefs.setString(_roleKey, role);
    await prefs.setString(_subscriptionTierKey, subscriptionTier);
  }

  static Future<Map<String, String?>> getStoredProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'id': prefs.getString(_userIdKey),
      'email': prefs.getString(_emailKey),
      'role': prefs.getString(_roleKey),
      'subscriptionTier': prefs.getString(_subscriptionTierKey),
    };
  }

  static Future<void> setSubscriptionTier(String subscriptionTier) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_subscriptionTierKey, subscriptionTier);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_subscriptionTierKey);
  }

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<dynamic> get(String endpoint, {bool auth = true}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final response = await http.get(uri, headers: await _headers(auth: auth));
    return _handleResponse(response);
  }

  static Future<dynamic> post(
    String endpoint, {
    dynamic body,
    bool auth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final response = await http.post(
      uri,
      headers: await _headers(auth: auth),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  static Future<dynamic> delete(String endpoint, {bool auth = true}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final response = await http.delete(
      uri,
      headers: await _headers(auth: auth),
    );
    return _handleResponse(response);
  }

  static dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } else {
      final message = _extractErrorMessage(response.body);
      throw Exception('Server error ${response.statusCode}: $message');
    }
  }

  static String _extractErrorMessage(String body) {
    if (body.trim().isEmpty) return 'No details returned by the server';

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'] ?? decoded['message'];
        if (error != null && error.toString().trim().isNotEmpty) {
          return error.toString();
        }
      }
    } catch (_) {
      // The backend sometimes returns plain text for old endpoints/tests.
    }

    return body;
  }

  // BUG FIX (frontend, 2026-06-30): streamChat() removed entirely.
  // It was implemented as an SSE client (filtering for "data: " lines,
  // expecting {"content": ..., "done": ...} per chunk), but the backend's
  // POST /api/chat endpoint no longer streams -- per the backend's own
  // FIXES.md (Round 4 and Round 6), it was deliberately changed to return
  // one plain JSON object {"reply": "...", "conversationId": "..."} in a
  // single response, because SSE on the backend's Tomcat servlet stack was
  // causing Spring Security to 403 the client's automatic SSE reconnect
  // request. Since the backend doesn't send SSE anymore, this method could
  // never produce any chunks -- every chat message would hang forever with
  // the typing indicator on screen and no reply ever arriving.
  // Use ApiClient.post('/api/chat', ...) directly instead, which the
  // existing _handleResponse() above already supports correctly.
}
