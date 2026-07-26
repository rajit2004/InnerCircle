import 'package:flutter/material.dart';

import '../models/memory.dart';
import '../services/memory_service.dart';
import '../theme/app_theme.dart';

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load memories: $e')));
    }
  }

  // UX FIX (2026-07-03): deleting used to fire immediately on tap with no
  // confirmation -- a memory is something the AI learned about you over a
  // real conversation, and a single mis-tap on the delete icon (easy to do
  // in a scrolling list) would silently erase it with no way to undo. Added
  // a confirmation dialog, same pattern as logout.
  Future<void> _confirmDelete(Memory memory) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text('Forget this?'),
        content: Text('"${memory.fact}" will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _deleteMemory(memory);
    }
  }

  Future<void> _deleteMemory(Memory memory) async {
    try {
      await MemoryService.deleteMemory(memory.id);
      if (!mounted) return;
      setState(() => _memories.removeWhere((item) => item.id == memory.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Memory forgotten')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();

    if (!widget.showAppBar) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Memories')),
      body: content,
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_memories.isEmpty) {
      // UX FIX (2026-07-03): gave this the same empty-state treatment as
      // the persona list -- an icon and a sentence that actually explains
      // *why* it's empty ("nothing yet, keep chatting") rather than a bare
      // status line that could read as a bug.
      return RefreshIndicator(
        onRefresh: _fetchMemories,
        child: ListView(
          children: [
            const SizedBox(height: 100),
            Icon(
              Icons.auto_awesome_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'No memories yet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Center(
                child: Text(
                  'Keep chatting -- important things you share get remembered here.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
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
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final memory = _memories[index];
          return Container(
            padding: const EdgeInsets.all(14),
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
                    child: Text(
                      memory.fact,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Delete memory',
                  // FEATURE (dark mode, 2026-07-06): dropped `const` -- see
                  // app_theme.dart's comment on why neutral colors need to
                  // read live from Theme.of(context) instead of the static
                  // (light-only) AppColors constant.
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () => _confirmDelete(memory),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}