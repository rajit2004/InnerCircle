import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// FEATURE (dark mode, 2026-07-06): single source of truth for the app's
/// current theme mode. Kept deliberately simple -- a two-way Light/Dark
/// toggle rather than a three-way Light/Dark/System choice, since properly
/// tracking live platform-brightness changes (for a "System" option) needs
/// a WidgetsBindingObserver wired at the app root and adds real complexity
/// for a feature whose actual value is "let me pick dark mode," not
/// "perfectly mirror my OS setting." A user who wants dark can just pick
/// Dark directly.
///
/// Wraps MaterialApp in main.dart via ValueListenableBuilder<ThemeMode> so
/// toggling rebuilds the whole tree with the new theme immediately.
class ThemeController {
  ThemeController._();

  static const _prefsKey = 'theme_mode_dark';

  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.light);

  /// Call once at startup, before runApp, so the persisted preference
  /// applies from the very first frame instead of flashing light mode
  /// first and then switching.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_prefsKey) ?? false;
    mode.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<void> setDark(bool isDark) async {
    mode.value = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, isDark);
  }

  static bool get isDark => mode.value == ThemeMode.dark;
}