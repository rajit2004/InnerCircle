import 'package:flutter/material.dart';

import '../models/persona.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/exit_confirmation_wrapper.dart';
import '../widgets/persona_avatar.dart';
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

    // UX FIX (2026-07-03): wrapped the whole home screen in
    // ExitConfirmationWrapper so the system back button from here (the
    // bottom of the nav stack -- the only place where "back" would
    // otherwise mean "quit the app") asks first instead of closing
    // instantly. See exit_confirmation_wrapper.dart for the full reasoning.
    return ExitConfirmationWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: Text(titles[_selectedIndex]),
          actions: [
            IconButton(
              tooltip: 'Logout',
              icon: const Icon(Icons.logout_rounded),
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
              icon: Icon(Icons.chat_bubble_outline_rounded),
              selectedIcon: Icon(Icons.chat_bubble_rounded),
              label: 'Chat',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome_rounded),
              label: 'Memories',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
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
              const Icon(
                Icons.cloud_off_outlined,
                size: 42,
                color: AppColors.textSecondary,
              ),
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
      // UX FIX (2026-07-03): previously just the text "No personas found"
      // with no icon, no context, no retry action visible without scrolling.
      // A blank-ish screen with three words is easy to mistake for the app
      // being broken. Given a proper empty state with an icon and an
      // explicit retry action.
      return RefreshIndicator(
        onRefresh: _fetchPersonas,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Icon(
              Icons.people_outline_rounded,
              size: 48,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'No one here yet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                'Pull down to try again',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchPersonas,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _personas.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final persona = _personas[index];
          return _PersonaCard(
            persona: persona,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ChatScreen(persona: persona)),
              );
            },
          );
        },
      ),
    );
  }
}

/// UX FIX (2026-07-03): replaced the plain ListTile row with a card that
/// leads with the persona's colored gradient avatar (see PersonaAvatar) and
/// shows the persona's actual greeting line as a preview -- so the list
/// reads as "four different people you could talk to," each visually
/// distinct at a glance, rather than four identical rows differentiated
/// only by their text label.
class _PersonaCard extends StatelessWidget {
  final Persona persona;
  final VoidCallback onTap;

  const _PersonaCard({required this.persona, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              PersonaAvatar(personaName: persona.name, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            persona.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _TierChip(tier: persona.subscriptionTier),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (persona.greeting?.isNotEmpty ?? false)
                          ? persona.greeting!
                          : _humanize(persona.role),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPremium
            ? AppColors.bestFriendDark.withValues(alpha: 0.14)
            : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPremium
                ? Icons.workspace_premium_rounded
                : Icons.lock_open_rounded,
            size: 11,
            color: isPremium ? AppColors.bestFriendDark : AppColors.textSecondary,
          ),
          const SizedBox(width: 3),
          Text(
            isPremium ? 'premium' : 'free',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: isPremium ? AppColors.bestFriendDark : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
