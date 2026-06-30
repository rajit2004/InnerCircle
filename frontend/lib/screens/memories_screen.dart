import 'package:flutter/material.dart';
import '../models/memory.dart';
import '../services/memory_service.dart';

class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({super.key});

  @override
  _MemoriesScreenState createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen> {
  List<Memory> _memories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchMemories();
  }

  _fetchMemories() async {
    try {
      final list = await MemoryService.getMemories();
      setState(() {
        _memories = list;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load memories: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Memories')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: _memories.length,
        itemBuilder: (context, index) {
          final m = _memories[index];
          return ListTile(
            title: Text(m.fact),
            subtitle: Text('Importance: ${m.importance}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                try {
                  await MemoryService.deleteMemory(m.id);
                  setState(() => _memories.removeAt(index));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
                }
              },
            ),
          );
        },
      ),
    );
  }
}
