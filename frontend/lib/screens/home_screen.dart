import 'package:flutter/material.dart';

import '../models/persona.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import 'chat_screen.dart';
import 'memories_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Persona> _personas = [];
  bool _loading = true;
  String? _error;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchPersonas();
  }

  Future<void> _fetchPersonas() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await ApiClient.get('/api/personas');
      final list = (data as List).map((p) => Persona.fromJson(p)).toList();
      final inferredTier =
          list.any((p) => p.subscriptionTier.toLowerCase() == 'premium')
          ? 'premium'
          : 'free';
      await AuthService.updateSubscriptionTier(inferredTier);

      if (!mounted) return;
      setState(() {
        _personas = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load personas: $_error')),
      );
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['InnerCircle', 'Memories', 'Profile'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _buildCurrentTab(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.memory_outlined),
            label: 'Memories',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_selectedIndex) {
      case 1:
        return const MemoriesScreen(showAppBar: false);
      case 2:
        return const ProfileScreen(showAppBar: false);
      default:
        return _buildPersonaList();
    }
  }

  Widget _buildPersonaList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 42),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _fetchPersonas,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_personas.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchPersonas,
        child: ListView(
          children: const [
            SizedBox(height: 180),
            Center(child: Text('No personas found')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchPersonas,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _personas.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final persona = _personas[index];
          return Card(
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              leading: CircleAvatar(child: Icon(_personaIcon(persona))),
              title: Text(
                persona.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                _humanize(persona.role),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: _TierChip(tier: persona.subscriptionTier),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(persona: persona),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  IconData _personaIcon(Persona persona) {
    final name = persona.name.toLowerCase();
    if (name.contains('mom')) return Icons.volunteer_activism;
    if (name.contains('friend')) return Icons.celebration_outlined;
    if (name.contains('girl')) return Icons.favorite_outline;
    if (name.contains('sister')) return Icons.shield_outlined;
    return Icons.auto_awesome_outlined;
  }

  String _humanize(String value) {
    if (value.trim().isEmpty) return 'Companion';
    final spaced = value.replaceAll('_', ' ');
    return spaced[0].toUpperCase() + spaced.substring(1);
  }
}

class _TierChip extends StatelessWidget {
  final String tier;

  const _TierChip({required this.tier});

  @override
  Widget build(BuildContext context) {
    final isPremium = tier.toLowerCase() == 'premium';
    final colorScheme = Theme.of(context).colorScheme;

    return Chip(
      avatar: Icon(
        isPremium ? Icons.workspace_premium_outlined : Icons.lock_open_outlined,
        size: 16,
      ),
      label: Text(isPremium ? 'premium' : 'free'),
      visualDensity: VisualDensity.compact,
      backgroundColor: isPremium
          ? colorScheme.tertiaryContainer
          : colorScheme.secondaryContainer,
      labelStyle: TextStyle(
        color: isPremium
            ? colorScheme.onTertiaryContainer
            : colorScheme.onSecondaryContainer,
      ),
      side: BorderSide.none,
    );
  }
}
