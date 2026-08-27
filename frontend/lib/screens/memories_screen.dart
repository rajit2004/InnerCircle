import 'package:flutter/material.dart';

import '../models/memory.dart';
import '../services/memory_service.dart';
import '../theme/app_theme.dart';
import '../services/sound_service.dart';
import '../widgets/shared_widgets.dart';

class MemoriesScreen extends StatefulWidget {
  final bool showAppBar;

  const MemoriesScreen({super.key, this.showAppBar = true});

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen> {
  List<Memory> _memories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchMemories();
  }

  Future<void> _fetchMemories() async {
    try {
      final list = await MemoryService.getMemories();
      if (!mounted) return;
      setState(() {
        _memories = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load memories: $e')));
    }
  }

  Future<void> _deleteMemory(Memory memory) async {
    AppSound.lightImpact();
    try {
      await MemoryService.deleteMemory(memory.id);
      if (!mounted) return;
      setState(() => _memories.removeWhere((item) => item.id == memory.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Memory forgotten')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();
    if (!widget.showAppBar) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('Memories')),
      body: content,
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: ShimmerPlaceholder(width: double.infinity, height: 80),
      );
    }

    if (_memories.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchMemories,
        child: ListView(
          children: [
            const SizedBox(height: 100),
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 0.8 + 0.2 * value,
                    child: Opacity(
                      opacity: value,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.18),
                        AppColors.defaultLight.withValues(alpha: 0.1),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        blurRadius: 28,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.auto_awesome_outlined,
                    size: 44,
                    color: AppColors.primary.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Center(
              child: Text(
                'No memories yet',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Center(
                child: Text(
                  'Important things you share get remembered here',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.7),
                        height: 1.5,
                      ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchMemories,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _memories.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final memory = _memories[index];
          return StaggeredEntrance(
            index: index,
            child: Dismissible(
              key: ValueKey(memory.id),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) async {
                AppSound.selectionClick();
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    title: const Text('Forget this?'),
                    content: Text(
                        '"${memory.fact}" will be permanently deleted.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.error),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                return confirmed == true;
              },
              onDismissed: (_) => _deleteMemory(memory),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                margin: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: Colors.white),
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.12),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        size: 17,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(memory.fact,
                            style: Theme.of(context).textTheme.bodyLarge),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Delete memory',
                      icon: Icon(Icons.delete_outline_rounded,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant),
                      onPressed: () => _deleteMemory(memory),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
