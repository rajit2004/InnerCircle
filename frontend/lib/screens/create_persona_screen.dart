import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/persona_service.dart';
import '../theme/app_theme.dart';

/// FEATURE (custom personas, 2026-07-06): builds a persona from a
/// relationship template + short personality description -- not a raw
/// system prompt field. See PersonaService.buildSystemPrompt on the backend
/// for why: a free-text prompt field would bypass every safety/quality
/// constraint the built-in personas already follow (texting-length replies,
/// no markdown, PG-13 boundary) and turn "create a persona" into a
/// prompt-injection surface.
///
/// Emoji picker is a fixed grid of simple, common, single-codepoint emoji
/// rather than free-text entry -- same reasoning as the built-in personas'
/// emoji guidance from Round 8: compound/ZWJ emoji sequences are the ones
/// most likely to render inconsistently (or as mojibake) across Android
/// devices and fonts.
class CreatePersonaScreen extends StatefulWidget {
  const CreatePersonaScreen({super.key});

  @override
  State<CreatePersonaScreen> createState() => _CreatePersonaScreenState();
}

class _CreatePersonaScreenState extends State<CreatePersonaScreen> {
  static const _relationshipTypes = [
    ('PARENT', 'Parent', Icons.volunteer_activism_rounded),
    ('SIBLING', 'Sibling', Icons.groups_rounded),
    ('FRIEND', 'Friend', Icons.emoji_people_rounded),
    ('PARTNER', 'Partner', Icons.favorite_rounded),
    ('MENTOR', 'Mentor', Icons.school_rounded),
    ('OTHER', 'Other', Icons.auto_awesome_rounded),
  ];

  static const _emojiOptions = [
    '🙂', '😊', '😎', '🥰', '🤗', '😏',
    '💪', '🌟', '💕', '🤝', '👋', '🎉',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _relationshipType = 'FRIEND';
  String _selectedEmoji = '🙂';
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    HapticFeedback.lightImpact();

    try {
      await PersonaService.createPersona(
        name: _nameController.text.trim(),
        relationshipType: _relationshipType,
        personalityDescription: _descriptionController.text.trim(),
        avatarEmoji: _selectedEmoji,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create a persona')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  maxLength: 40,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g. Alex',
                  ),
                  validator: (v) => (v != null && v.trim().isNotEmpty)
                      ? null
                      : 'Give them a name',
                ),
                const SizedBox(height: 12),
                Text('Relationship', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _relationshipTypes.map((entry) {
                    final (value, label, icon) = entry;
                    final selected = _relationshipType == value;
                    return ChoiceChip(
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _relationshipType = value),
                      avatar: Icon(
                        icon,
                        size: 16,
                        color: selected ? Colors.white : null,
                      ),
                      label: Text(label),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _descriptionController,
                  maxLength: 300,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Personality',
                    hintText:
                    'e.g. witty and a little sarcastic, always checks in about my workouts',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => (v != null && v.trim().isNotEmpty)
                      ? null
                      : 'Describe their personality in a sentence or two',
                ),
                const SizedBox(height: 20),
                Text('Avatar', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _emojiOptions.map((emoji) {
                    final selected = _selectedEmoji == emoji;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedEmoji = emoji),
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          border: selected
                              ? Border.all(color: AppColors.primary, width: 2)
                              : null,
                        ),
                        child: Text(emoji, style: const TextStyle(fontSize: 22)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _saving ? null : _create,
                  child: _saving
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                      : const Text('Create'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}