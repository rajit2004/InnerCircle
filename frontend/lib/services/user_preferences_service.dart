import 'package:flutter/material.dart';
import '../models/user_preferences.dart';
import 'api_client.dart';

class UserPreferencesService extends ChangeNotifier {
  UserPreferences? _preferences;

  UserPreferences get preferences =>
      _preferences ??
      UserPreferences(userId: '');

  Future<UserPreferences> getPreferences() async {
    final response = await ApiClient.get('/api/user-preferences');
    _preferences = UserPreferences.fromJson(response);
    notifyListeners();
    return _preferences!;
  }

  Future<UserPreferences> updatePreferences({
    String? preferredName,
    String? communicationStyle,
    String? responseLength,
    String? interests,
    String? goals,
    bool? memoryEnabled,
  }) async {
    final body = <String, dynamic>{};
    if (preferredName != null) body['preferredName'] = preferredName;
    if (communicationStyle != null) {
      body['communicationStyle'] = communicationStyle;
    }
    if (responseLength != null) body['responseLength'] = responseLength;
    if (interests != null) body['interests'] = interests;
    if (goals != null) body['goals'] = goals;
    if (memoryEnabled != null) body['memoryEnabled'] = memoryEnabled;

    final response = await ApiClient.put('/api/user-preferences', body: body);
    _preferences = UserPreferences.fromJson(response);
    notifyListeners();
    return _preferences!;
  }
}
