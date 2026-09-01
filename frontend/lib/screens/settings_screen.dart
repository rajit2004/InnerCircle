import 'package:flutter/material.dart';

import '../models/user_preferences.dart';
import '../services/user_preferences_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../theme/motion.dart';
import '../services/sound_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _prefsService = UserPreferencesService();
  UserPreferences? _prefs;
  bool _loadingPrefs = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() => _loadingPrefs = true);
    try {
      final prefs = await _prefsService.getPreferences();
      if (!mounted) return;
      setState(() {
        _prefs = prefs;
        _loadingPrefs = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _prefs = null;
        _loadingPrefs = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(context, 'Appearance', Icons.palette_outlined),
          const SizedBox(height: 10),
          Card(
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: ThemeController.mode,
              builder: (context, mode, _) {
                final isDark = mode == ThemeMode.dark;
                return SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  secondary: AnimatedSwitcher(
                    duration: AppMotion.meso,
                    child: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, key: ValueKey(isDark), color: AppColors.primary),
                  ),
                  title: const Text('Dark mode'),
                  subtitle: AnimatedSwitcher(duration: AppMotion.micro, child: Text(isDark ? 'On' : 'Off', key: ValueKey(isDark))),
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

          // ── Chat Preferences ──────────────────────────────────
          _buildSectionHeader(context, 'Chat preferences', Icons.chat_outlined),
          const SizedBox(height: 10),
          if (_loadingPrefs)
            const Card(child: Padding(padding: EdgeInsets.all(18), child: Center(child: CircularProgressIndicator())))
          else if (_prefs != null)
            Card(
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    leading: Icon(Icons.badge_outlined, color: AppColors.primary, size: 22),
                    title: const Text('Preferred name'),
                    subtitle: Text(_prefs!.preferredName ?? 'Not set'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _editPreferredName(),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    leading: Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary, size: 22),
                    title: const Text('Communication style'),
                    subtitle: Text(_prefs!.communicationStyle.toUpperCase()),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _editCommunicationStyle(),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    leading: Icon(Icons.format_list_bulleted_rounded, color: AppColors.primary, size: 22),
                    title: const Text('Response length'),
                    subtitle: Text(_prefs!.responseLength.toUpperCase()),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _editResponseLength(),
                  ),
                  const Divider(height: 1, indent: 56),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    secondary: Icon(Icons.memory_rounded, color: AppColors.primary, size: 22),
                    title: const Text('Memory'),
                    subtitle: Text(_prefs!.memoryEnabled ? 'Personas remember you' : 'Personas forget between sessions'),
                    value: _prefs!.memoryEnabled,
                    onChanged: (value) async {
                      AppSound.lightImpact();
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final updated = await _prefsService.updatePreferences(memoryEnabled: value);
                        if (!mounted) return;
                        setState(() => _prefs = updated);
                      } catch (e) {
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(content: Text('Failed: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: AppColors.error),
                        );
                      }
                    },
                  ),
                ],
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Text('Could not load preferences', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    FilledButton.tonal(onPressed: _loadPreferences, child: const Text('Retry')),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 24),
          _buildSectionHeader(context, 'About', Icons.info_outline_rounded),
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

  Future<void> _editPreferredName() async {
    AppSound.selectionClick();
    final controller = TextEditingController(text: _prefs?.preferredName ?? '');
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Theme.of(ctx).dividerColor, borderRadius: BorderRadius.circular(2)))),
              Text('Preferred name', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('How personas should address you', style: Theme.of(ctx).textTheme.bodySmall),
              const SizedBox(height: 16),
              TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Name', hintText: 'What should they call you?', prefixIcon: Icon(Icons.badge_outlined))),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Save'))),
            ],
          ),
        ),
      ),
    );
    if (result == null) return;
    try {
      final updated = await _prefsService.updatePreferences(preferredName: result.isEmpty ? null : result);
      if (!mounted) return;
      setState(() => _prefs = updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _editCommunicationStyle() async {
    AppSound.selectionClick();
    final styles = {'Casual': 'casual', 'Formal': 'formal', 'Playful': 'playful', 'Direct': 'direct'};
    final current = _prefs?.communicationStyle ?? 'casual';
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Communication style'),
        children: styles.entries.map((e) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, e.value),
          child: Row(
            children: [
              if (e.value == current) const Icon(Icons.check_rounded, size: 18, color: AppColors.primary) else const SizedBox(width: 18),
              const SizedBox(width: 12),
              Text(e.key),
            ],
          ),
        )).toList(),
      ),
    );
    if (selected == null || selected == current) return;
    try {
      final updated = await _prefsService.updatePreferences(communicationStyle: selected);
      if (!mounted) return;
      setState(() => _prefs = updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _editResponseLength() async {
    AppSound.selectionClick();
    final lengths = {'Very short': 'very_short', 'Short': 'short', 'Moderate': 'moderate', 'Detailed': 'detailed'};
    final current = _prefs?.responseLength ?? 'moderate';
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Response length'),
        children: lengths.entries.map((e) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, e.value),
          child: Row(
            children: [
              if (e.value == current) const Icon(Icons.check_rounded, size: 18, color: AppColors.primary) else const SizedBox(width: 18),
              const SizedBox(width: 12),
              Text(e.key),
            ],
          ),
        )).toList(),
      ),
    );
    if (selected == null || selected == current) return;
    try {
      final updated = await _prefsService.updatePreferences(responseLength: selected);
      if (!mounted) return;
      setState(() => _prefs = updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: AppColors.error),
      );
    }
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
        ),
      ],
    );
  }
}
