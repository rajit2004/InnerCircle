import 'package:flutter/material.dart';
import '../models/persona.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import 'chat_screen.dart';
import 'memories_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Persona> _personas = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchPersonas();
  }

  _fetchPersonas() async {
    try {
      final data = await ApiClient.get('/api/personas');
      final list = (data as List).map((p) => Persona.fromJson(p)).toList();
      setState(() {
        _personas = list;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load personas: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('InnerCircle'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () async {
              await AuthService.logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: _personas.length,
        itemBuilder: (context, index) {
          final p = _personas[index];
          return Card(
            child: ListTile(
              leading: Text(p.avatarEmoji ?? '🤖', style: const TextStyle(fontSize: 32)),
              title: Text(p.name),
              subtitle: Text(p.role),
              trailing: Chip(label: Text(p.subscriptionTier)),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(persona: p),
                  ),
                );
              },
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.memory), label: 'Memories'),
        ],
        onTap: (index) {
          if (index == 1) {
            Navigator.pushNamed(context, '/memories');
          }
        },
      ),
    );
  }
}