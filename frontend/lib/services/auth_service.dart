import 'api_client.dart';

class AuthService {
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final body = {'email': email, 'password': password};
    final response = await ApiClient.post('/api/auth/login', body: body, auth: false);
    if (response != null && response['token'] != null) {
      await ApiClient.setToken(response['token']);
    }
    return response;
  }

  static Future<Map<String, dynamic>> register(String email, String password) async {
    final body = {'email': email, 'password': password};
    final response = await ApiClient.post('/api/auth/register', body: body, auth: false);
    if (response != null && response['token'] != null) {
      await ApiClient.setToken(response['token']);
    }
    return response;
  }

  static Future<void> logout() async {
    await ApiClient.clearToken();
  }

  static Future<bool> isLoggedIn() async {
    return await ApiClient.getToken() != null;
  }
}