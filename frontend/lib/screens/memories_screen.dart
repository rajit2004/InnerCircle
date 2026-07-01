import 'package:flutter/material.dart';

import '../models/memory.dart';
import '../services/memory_service.dart';

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

  Future<void> _deleteMemory(Memory memory) async {
    try {
      await MemoryService.deleteMemory(memory.id);
      if (!mounted) return;
      setState(() => _memories.removeWhere((item) => item.id == memory.id));
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
      return RefreshIndicator(
        onRefresh: _fetchMemories,
        child: ListView(
          children: const [
            SizedBox(height: 180),
            Center(child: Text('No memories saved yet')),
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
          return Card(
            elevation: 0,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              title: Text(memory.fact),
              subtitle: Text('Importance: ${memory.importance}'),
              trailing: IconButton(
                tooltip: 'Delete memory',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteMemory(memory),
              ),
            ),
          );
        },
      ),
    );
  }
}
