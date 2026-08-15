import 'package:flutter/material.dart';

import '../models/persona.dart';
import '../models/scheduled_message.dart';
import '../services/api_client.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../services/sound_service.dart';
import '../widgets/persona_avatar.dart';
import '../widgets/shared_widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<ScheduledMessage> _scheduled = [];
  List<Persona> _personas = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        NotificationService.listScheduled(),
        ApiClient.get('/api/personas'),
      ]);
      final scheduled = results[0] as List<ScheduledMessage>;
      final personas = (results[1] as List)
          .map((p) => Persona.fromJson(p as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _scheduled = scheduled;
        _personas = personas;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _toggleActive(ScheduledMessage sm, bool active) async {
    AppSound.lightImpact();
    setState(() {
      _scheduled = _scheduled.map((s) {
        if (s.id != sm.id) return s;
        return ScheduledMessage(
          id: s.id,
          personaId: s.personaId,
          personaName: s.personaName,
          personaAvatarEmoji: s.personaAvatarEmoji,
          scheduledAt: s.scheduledAt,
          daysOfWeek: s.daysOfWeek,
          messageType: s.messageType,
          active: active,
          lastSentAt: s.lastSentAt,
        );
      }).toList();
    });
    try {
      await NotificationService.setActive(sm.id, active);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: ${_friendly(e)}')),
      );
      _load();
    }
  }

  Future<void> _cancel(ScheduledMessage sm) async {
    AppSound.lightImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel check-in?'),
        content: Text(
          '${sm.personaName} won\'t check in with you at ${sm.timeLabel} anymore.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel it'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(
        () => _scheduled = _scheduled.where((s) => s.id != sm.id).toList());
    try {
      await NotificationService.cancel(sm.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel: ${_friendly(e)}')),
      );
      _load();
    }
  }

  Future<void> _openAddSheet() async {
    if (_personas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No personas available to schedule.')),
      );
      return;
    }
    AppSound.selectionClick();
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddScheduleSheet(personas: _personas),
    );
    if (created == true) _load();
  }

  String _friendly(Object e) => e.toString().replaceFirst('Exception: ', '');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Check-in reminders')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New reminder'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: ShimmerPlaceholder(width: double.infinity, height: 80),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 42,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_scheduled.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            const SizedBox(height: 100),
            Icon(Icons.notifications_none_rounded, size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Center(child: Text('No check-ins scheduled',
                style: Theme.of(context).textTheme.titleMedium)),
            const SizedBox(height: 6),
            Center(
              child: Text(
                'Tap "New reminder" to have a persona check in on you',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        itemCount: _scheduled.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final sm = _scheduled[index];
          return StaggeredEntrance(
            index: index,
            child: _ScheduleCard(
              scheduled: sm,
              onToggle: (active) => _toggleActive(sm, active),
              onDelete: () => _cancel(sm),
            ),
          );
        },
      ),
    );
  }
}

// ── Schedule Card ────────────────────────────────────────────────────────

class _ScheduleCard extends StatelessWidget {
  final ScheduledMessage scheduled;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  const _ScheduleCard({
    required this.scheduled,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Opacity(
            opacity: scheduled.active ? 1 : 0.4,
            child: PersonaAvatar(
                personaName: scheduled.personaName, size: 46),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(scheduled.personaName,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  '${scheduled.timeLabel} \u00b7 ${scheduled.daysLabel}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          // Custom animated toggle
          _AnimatedToggle(
            value: scheduled.active,
            onChanged: onToggle,
          ),
          IconButton(
            tooltip: 'Cancel',
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            color: AppColors.error,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ── Animated Toggle ──────────────────────────────────────────────────────

class _AnimatedToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _AnimatedToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: AppMotion.micro,
        width: 48,
        height: 28,
        decoration: BoxDecoration(
          color: value
              ? AppColors.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Align(
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Add Schedule Sheet ───────────────────────────────────────────────────

class _AddScheduleSheet extends StatefulWidget {
  final List<Persona> personas;
  const _AddScheduleSheet({required this.personas});

  @override
  State<_AddScheduleSheet> createState() => _AddScheduleSheetState();
}

class _AddScheduleSheetState extends State<_AddScheduleSheet> {
  late Persona _selectedPersona;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  final Set<int> _selectedDays = {1, 2, 3, 4, 5, 6, 7};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedPersona = widget.personas.first;
  }

  Future<void> _pickTime() async {
    AppSound.selectionClick();
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least one day.')),
      );
      return;
    }
    setState(() => _saving = true);
    AppSound.lightImpact();
    try {
      await NotificationService.schedule(
        personaId: _selectedPersona.id,
        time: _time,
        daysOfWeek: _selectedDays.toList()..sort(),
      );
      if (!mounted) return;
      AppSound.mediumImpact();
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to schedule: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('New check-in reminder',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            Text('Who', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.personas.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final persona = widget.personas[index];
                  final selected =
                      persona.id == _selectedPersona.id;
                  return GestureDetector(
                    onTap: () {
                      AppSound.selectionClick();
                      setState(() => _selectedPersona = persona);
                    },
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: selected
                                ? Border.all(
                                    color: AppColors.primary, width: 2)
                                : null,
                          ),
                          child: PersonaAvatar(
                              personaName: persona.name, size: 48),
                        ),
                        const SizedBox(height: 4),
                        Text(persona.name,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Text('When', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickTime,
              icon: const Icon(Icons.access_time_rounded),
              label: Text(_time.format(context)),
            ),
            const SizedBox(height: 20),
            Text('Which days',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  ScheduledMessage.weekdayLabels.entries.map((entry) {
                final selected = _selectedDays.contains(entry.key);
                return FilterChip(
                  label: Text(entry.value),
                  selected: selected,
                  onSelected: (isSelected) {
                    AppSound.selectionClick();
                    setState(() {
                      if (isSelected) {
                        _selectedDays.add(entry.key);
                      } else {
                        _selectedDays.remove(entry.key);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Schedule it'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
