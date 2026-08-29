import 'package:flutter/material.dart';

import '../services/persona_service.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../services/sound_service.dart';

/// FEATURE (custom personas, 2026-07-06): stepped flow replacing the
/// single long form. Each step slides in horizontally with progress dots.
class CreatePersonaScreen extends StatefulWidget {
  const CreatePersonaScreen({super.key});

  @override
  State<CreatePersonaScreen> createState() => _CreatePersonaScreenState();
}

class _CreatePersonaScreenState extends State<CreatePersonaScreen>
    with TickerProviderStateMixin {
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

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _relationshipType = 'FRIEND';
  String _selectedEmoji = '🙂';
  bool _saving = false;
  bool _nsfwEnabled = false;

  int _currentStep = 0; // 0: Name, 1: Relationship, 2: Personality, 3: Avatar
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
    );
    _slideController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0 && _nameController.text.trim().isEmpty) {
      AppSound.heavyImpact();
      return;
    }
    if (_currentStep == 2 && _descriptionController.text.trim().isEmpty) {
      AppSound.heavyImpact();
      return;
    }
    AppSound.selectionClick();
    setState(() => _currentStep++);
    _slideController.forward(from: 0.0);
  }

  void _prevStep() {
    AppSound.selectionClick();
    setState(() => _currentStep--);
    _slideController.forward(from: 0.0);
  }

  Future<void> _create() async {
    setState(() => _saving = true);
    AppSound.lightImpact();
    try {
      await PersonaService.createPersona(
        name: _nameController.text.trim(),
        relationshipType: _relationshipType,
        personalityDescription: _descriptionController.text.trim(),
        avatarEmoji: _selectedEmoji,
        nsfwEnabled: _nsfwEnabled,
      );
      if (!mounted) return;
      AppSound.mediumImpact();
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      AppSound.lightImpact();
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
      appBar: AppBar(
        title: Text('Step ${_currentStep + 1} of 4'),
        actions: [
          if (_currentStep > 0)
            TextButton(
              onPressed: _prevStep,
              child: const Text('Back'),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress dots
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final isActive = i <= _currentStep;
                  final isCurrent = i == _currentStep;
                  return AnimatedContainer(
                    duration: AppMotion.micro,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isCurrent ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.primary
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
            // Step content
            Expanded(
              child: AnimatedBuilder(
                animation: _slideController,
                builder: (context, child) {
                  return SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildStepContent(),
                    ),
                  );
                },
              ),
            ),
            // Bottom button
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: _currentStep < 3
                    ? FilledButton(
                        onPressed: _nextStep,
                        child: const Text('Continue'),
                      )
                    : FilledButton(
                        onPressed: _saving ? null : _create,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white),
                              )
                            : const Text('Create'),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildNameStep();
      case 1:
        return _buildRelationshipStep();
      case 2:
        return _buildPersonalityStep();
      case 3:
        return _buildAvatarStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNameStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What should we call them?',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('Pick something you\'d naturally text.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 32),
          TextField(
            controller: _nameController,
            maxLength: 40,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _nextStep(),
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. Alex',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelationshipStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What are they to you?',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('This shapes how they talk to you.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 32),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _relationshipTypes.map((entry) {
              final (value, label, icon) = entry;
              final selected = _relationshipType == value;
              return GestureDetector(
                onTap: () {
                  AppSound.selectionClick();
                  setState(() => _relationshipType = value);
                },
                child: AnimatedContainer(
                  duration: AppMotion.micro,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary
                        : Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: selected
                        ? null
                        : Border.all(
                            color: Theme.of(context).dividerColor),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 18,
                          color: selected ? Colors.white : null),
                      const SizedBox(width: 6),
                      Text(label,
                          style: TextStyle(
                            color: selected ? Colors.white : null,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalityStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Describe their personality',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('A sentence or two about how they text.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 32),
          TextField(
            controller: _descriptionController,
            maxLength: 300,
            maxLines: 3,
            autofocus: true,
            decoration: const InputDecoration(
              hintText:
                  'e.g. witty and a little sarcastic, always checks in about my workouts',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          // Live preview bubble
          _buildPreviewBubble(),
          const SizedBox(height: 24),
          // NSFW toggle
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Unrestricted content',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text('Allow explicit and adult conversations',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Switch(
                  value: _nsfwEnabled,
                  onChanged: (val) {
                    AppSound.selectionClick();
                    setState(() => _nsfwEnabled = val);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pick their avatar',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('They\'ll show up with this everywhere.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 32),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _emojiOptions.map((emoji) {
              final selected = _selectedEmoji == emoji;
              return GestureDetector(
                onTap: () {
                  AppSound.selectionClick();
                  setState(() => _selectedEmoji = emoji);
                },
                child: AnimatedContainer(
                  duration: AppMotion.micro,
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                    border: selected
                        ? Border.all(color: AppColors.primary, width: 2.5)
                        : null,
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color:
                                  AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(emoji,
                      style: TextStyle(
                          fontSize: selected ? 26 : 24)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          // Final preview
          _buildPreviewBubble(),
        ],
      ),
    );
  }

  Widget _buildPreviewBubble() {
    final name = _nameController.text.trim();
    final personality = _descriptionController.text.trim();
    if (name.isEmpty && personality.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: AppColors.personaGradient(name.isNotEmpty ? name : 'default'),
              ),
            ),
            child: Center(
              child: Text(_selectedEmoji, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty ? name : 'Your persona',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  personality.isNotEmpty
                      ? personality
                      : 'They\'ll text like this...',
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
