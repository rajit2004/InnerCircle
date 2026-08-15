import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/persona.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/persona_service.dart';
import '../theme/app_theme.dart';
import '../widgets/exit_confirmation_wrapper.dart';
import '../services/push_notification_service.dart';
import '../widgets/persona_avatar.dart';
import '../widgets/shared_widgets.dart';
import 'chat_screen.dart';
import 'create_persona_screen.dart';
import 'memories_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  List<Persona> _personas = [];
  bool _loading = true;
  String? _error;
  int _selectedIndex = 0;
  late AnimationController _fabController;
  late Animation<double> _fabScale;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fabScale = CurvedAnimation(
      parent: _fabController,
      curve: Curves.elasticOut,
    );
    _fabController.forward();
    _fetchPersonas();
    PushNotificationService.initialize();
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
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
    HapticFeedback.lightImpact();
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  Future<void> _openCreatePersona() async {
    HapticFeedback.lightImpact();
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreatePersonaScreen()),
    );
    if (created == true) _fetchPersonas();
  }

  Future<void> _deletePersona(Persona persona) async {
    HapticFeedback.lightImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this persona?'),
        content: Text(
          '${persona.name} and your entire conversation history with them will be deleted. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await PersonaService.deletePersona(persona.id);
      if (!mounted) return;
      _fetchPersonas();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['InnerCircle', 'Memories', 'Profile'];

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
        floatingActionButton: _selectedIndex == 0
            ? ScaleTransition(
                scale: _fabScale,
                child: FloatingActionButton(
                  onPressed: _openCreatePersona,
                  tooltip: 'Create a persona',
                  child: const Icon(Icons.add_rounded),
                ),
              )
            : null,
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
      return const ShimmerList(itemCount: 4, height: 88);
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 42,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
      return RefreshIndicator(
        onRefresh: _fetchPersonas,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Icon(
              Icons.people_outline_rounded,
              size: 48,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.5),
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
      onRefresh: () async {
        HapticFeedback.lightImpact();
        return _fetchPersonas();
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _personas.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final persona = _personas[index];
          return _StaggeredPersonaCard(
            persona: persona,
            index: index,
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(persona: persona),
                ),
              );
            },
            onDelete: persona.owned ? () => _deletePersona(persona) : null,
          );
        },
      ),
    );
  }
}

class _StaggeredPersonaCard extends StatefulWidget {
  final Persona persona;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _StaggeredPersonaCard({
    required this.persona,
    required this.index,
    required this.onTap,
    this.onDelete,
  });

  @override
  State<_StaggeredPersonaCard> createState() => _StaggeredPersonaCardState();
}

class _StaggeredPersonaCardState extends State<_StaggeredPersonaCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    final delay = (widget.index * 0.1).clamp(0.0, 0.4);

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Interval(delay, (delay + 0.5).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    ));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(delay, (delay + 0.4).clamp(0.0, 1.0),
            curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(delay, (delay + 0.5).clamp(0.0, 1.0),
            curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: _PersonaCard(
            persona: widget.persona,
            onTap: widget.onTap,
            onDelete: widget.onDelete,
          ),
        ),
      ),
    );
  }
}

class _PersonaCard extends StatelessWidget {
  final Persona persona;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _PersonaCard({
    required this.persona,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Theme.of(context).dividerColor),
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
              if (onDelete != null)
                IconButton(
                  tooltip: 'Delete persona',
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: onDelete,
                ),
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
            : Theme.of(context).colorScheme.surfaceContainerHighest,
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
            color: isPremium
                ? AppColors.bestFriendDark
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 3),
          Text(
            isPremium ? 'premium' : 'free',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: isPremium
                  ? AppColors.bestFriendDark
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
