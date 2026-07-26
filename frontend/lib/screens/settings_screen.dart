import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

/// FEATURE (dark mode, 2026-07-06): reachable from Profile -> Settings.
/// Deliberately a simple two-state Light/Dark toggle rather than a
/// three-way Light/Dark/System choice -- see theme_controller.dart's doc
/// comment for why System support was scoped out (it needs a
/// WidgetsBindingObserver tracking live platform-brightness changes, real
/// added complexity for a feature whose core value is "let me pick dark
/// mode," not "perfectly mirror my OS setting").
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Appearance', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          Card(
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: ThemeController.mode,
              builder: (context, mode, _) {
                final isDark = mode == ThemeMode.dark;
                return SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  secondary: Icon(
                    isDark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    color: AppColors.primary,
                  ),
                  title: const Text('Dark mode'),
                  subtitle: Text(isDark ? 'On' : 'Off'),
                  value: isDark,
                  onChanged: (value) => ThemeController.setDark(value),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Text('About', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          const Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info_outline_rounded),
                  title: Text('InnerCircle'),
                  subtitle: Text('Version 1.0.0'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}