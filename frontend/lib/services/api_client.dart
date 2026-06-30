import 'dart:async';
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
const String baseUrl = 'http://10.0.2.2:8080';

class ApiClient {
  static const String _tokenKey = 'auth_token';

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
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

  static Future<dynamic> post(String endpoint, {dynamic body, bool auth = true}) async {
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
    final response = await http.delete(uri, headers: await _headers(auth: auth));
    return _handleResponse(response);
  }

  static dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } else {
      throw Exception('Server error: ${response.statusCode} - ${response.body}');
    }
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
// Use ApiClient.post('/api/chat/sync', ...) directly instead, which the
// existing _handleResponse() above already supports correctly.
}