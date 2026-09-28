import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';

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
//
// Configurable at build time via --dart-define=BASE_URL=... so the same binary
// can target any of the above without editing source. Defaults to the Android
// emulator alias (the host machine's localhost from inside the emulator).
const String baseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'http://10.0.2.2:8080',
);

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

  static const Duration _timeout = Duration(seconds: 30);

  static Future<dynamic> get(String endpoint, {bool auth = true}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final response = await http
        .get(uri, headers: await _headers(auth: auth))
        .timeout(_timeout);
    return _handleResponse(response);
  }

  static Future<dynamic> post(
    String endpoint, {
    dynamic body,
    bool auth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final response = await http
        .post(
          uri,
          headers: await _headers(auth: auth),
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(_timeout);
    return _handleResponse(response);
  }

  static Future<dynamic> delete(String endpoint, {bool auth = true}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final response = await http
        .delete(uri, headers: await _headers(auth: auth))
        .timeout(_timeout);
    return _handleResponse(response);
  }

  // FEATURE (message reactions, round 12): first PUT usage in this client --
  // added alongside get/post/delete rather than reusing post, since the
  // reaction endpoint is a genuine update-in-place, not a create.
  static Future<dynamic> put(
    String endpoint, {
    dynamic body,
    bool auth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final response = await http
        .put(
          uri,
          headers: await _headers(auth: auth),
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(_timeout);
    return _handleResponse(response);
  }

  static dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.bodyBytes.isEmpty) return null;
      return jsonDecode(utf8.decode(response.bodyBytes));
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      final currentRoute = navigatorKey.currentContext != null
          ? ModalRoute.of(navigatorKey.currentContext!)
          : null;
      final path = currentRoute?.settings.name ?? '';
      final onAuthScreen =
          path == '/' || path == '/login' || path == '/register';

      if (!onAuthScreen) {
        clearToken();
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      }
      final message = _extractErrorMessage(response.body);
      throw Exception('Server error ${response.statusCode}: $message');
    }

    final message = _extractErrorMessage(response.body);
    throw Exception('Server error ${response.statusCode}: $message');
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

  // FEATURE (streaming, Phase 5): sends a POST and returns the SSE frames
  // the backend emits on the response body as a lazy Stream of decoded JSON
  // payloads (each `data:` line). Unlike a browser EventSource, this is a
  // one-shot authenticated POST that never auto-reconnects, which is what
  // caused Spring Security to 403 the old SSE implementation (Round 4).
  // Non-2xx responses are read fully and routed through the same
  // _handleResponse() error mapping as every other verb, so quota/auth
  // errors thrown before the stream starts surface identically.
  static Future<Stream<dynamic>> postStream(
    String endpoint, {
    dynamic body,
    bool auth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _headers(auth: auth);
    final client = http.Client();
    try {
      final request = http.Request('POST', uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final streamed = await client
          .send(request)
          .timeout(const Duration(seconds: 15));
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        final response = await http.Response.fromStream(streamed);
        client.close();
        _handleResponse(response);
        return const Stream<dynamic>.empty();
      }
      return _sseLines(streamed.stream, client);
    } catch (_) {
      client.close();
      rethrow;
    }
  }

  static Stream<dynamic> _sseLines(
    http.ByteStream byteStream,
    http.Client client,
  ) async* {
    try {
      final lines = byteStream
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in lines) {
        // SSE frames allow an optional space after the colon; Spring's
        // SseEmitter writes "data:" with no space, so accept both forms.
        if (!line.startsWith('data:')) continue;
        final payload = line.substring(5).trimLeft();
        if (payload.isEmpty) continue;
        try {
          yield jsonDecode(payload);
        } catch (_) {
          // Ignore malformed frames rather than killing the stream.
        }
      }
    } finally {
      client.close();
    }
  }
}
