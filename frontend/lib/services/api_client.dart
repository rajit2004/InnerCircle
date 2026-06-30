import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Change this to your backend URL:
// Android emulator: http://10.0.2.2:8080
// iOS simulator / macOS: http://localhost:8080
// Physical device: http://<your_computer_ip>:8080
const String baseUrl = 'http://localhost:8080';

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

  static Future<Stream<String>> streamChat(Map<String, dynamic> body) async {
    final token = await getToken();
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final uri = Uri.parse('$baseUrl/api/chat');
    final request = http.Request('POST', uri)
      ..headers.addAll(headers)
      ..body = jsonEncode(body);

    final response = await request.send();
    if (response.statusCode != 200) {
      throw Exception('Failed to start chat: ${response.statusCode}');
    }
    return response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .where((line) => line.startsWith('data: '))
        .map((line) => line.substring(6).trim())
        .where((data) => data.isNotEmpty);
  }
}