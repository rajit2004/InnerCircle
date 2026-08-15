import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../theme/motion.dart';
import '../services/sound_service.dart';

/// FEATURE (dark mode, 2026-07-06): reachable from Profile -> Settings.
/// Dark mode toggle with crossfade transition for a premium feel.
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
                      horizontal: 16, vertical: 4),
                  secondary: AnimatedSwitcher(
                    duration: AppMotion.meso,
                    child: Icon(
                      isDark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      key: ValueKey(isDark),
                      color: AppColors.primary,
                    ),
                  ),
                  title: const Text('Dark mode'),
                  subtitle: AnimatedSwitcher(
                    duration: AppMotion.micro,
                    child: Text(
                      isDark ? 'On' : 'Off',
                      key: ValueKey(isDark),
                    ),
                  ),
                  value: isDark,
                  onChanged: (value) {
                    AppSound.lightImpact();
                    ThemeController.setDark(value);
                  },
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
