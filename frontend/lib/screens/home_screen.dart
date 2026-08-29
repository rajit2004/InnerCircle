import 'package:flutter/material.dart';

import '../models/persona.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/persona_service.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../services/sound_service.dart';
import '../widgets/exit_confirmation_wrapper.dart';
import '../services/push_notification_service.dart';
import '../widgets/persona_avatar.dart';
import '../widgets/shared_widgets.dart';
import 'chat_screen.dart';
import 'create_persona_screen.dart';
import 'memories_screen.dart';
import 'profile_screen.dart';
import 'upgrade_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  List<Persona> _personas = [];
  bool _loading = true;
  String? _error;
  int _selectedIndex = 0;
  bool _isPremium = false;
  late AnimationController _fabController;
  late Animation<double> _fabScale;
  bool _fabOpen = false;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
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
      final profile = await ApiClient.getStoredProfile();
      final isPremium = (profile['subscriptionTier'] ?? 'free').toLowerCase() == 'premium';
      if (!mounted) return;
      setState(() {
        _personas = list;
        _isPremium = isPremium;
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
    AppSound.lightImpact();
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  Future<void> _openCreatePersona() async {
    AppSound.lightImpact();
    if (!_isPremium) {
      _showUpgradeDialog();
      return;
    }
    setState(() => _fabOpen = true);
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreatePersonaScreen()),
    );
    setState(() => _fabOpen = false);
    if (created == true) _fetchPersonas();
  }

  Future<void> _deletePersona(Persona persona) async {
    AppSound.lightImpact();
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
                  child: AnimatedSwitcher(
                    duration: AppMotion.micro,
                    child: Icon(
                      _fabOpen ? Icons.close_rounded : Icons.add_rounded,
                      key: ValueKey(_fabOpen),
                    ),
                  ),
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

  Widget _buildPersonaPreviewChips() {
    final personas = [
      ('Mom', AppColors.momLight, AppColors.momDark, Icons.volunteer_activism_rounded),
      ('Best Friend', AppColors.bestFriendLight, AppColors.bestFriendDark, Icons.celebration_rounded),
      ('Girlfriend', AppColors.girlfriendLight, AppColors.girlfriendDark, Icons.favorite_rounded),
      ('Big Sister', AppColors.bigSisterLight, AppColors.bigSisterDark, Icons.shield_rounded),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: personas.map((p) {
          final gradient = AppColors.personaGradient(p.$1);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  gradient.first.withValues(alpha: 0.15),
                  gradient.last.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: gradient.first.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(p.$4, size: 16, color: p.$3),
                const SizedBox(width: 6),
                Text(
                  p.$1,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: p.$3,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
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
              Icon(Icons.cloud_off_outlined, size: 42,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium),
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
            const SizedBox(height: 100),
            // Animated gradient circle container
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
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.18),
                        AppColors.primaryDark.withValues(alpha: 0.08),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        blurRadius: 32,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.waving_hand_rounded,
                    size: 52,
                    color: AppColors.primary.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Center(
              child: Text(
                'Your circle is empty',
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
                  'Create your first companion and start a meaningful conversation',
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
            const SizedBox(height: 32),
            // Persona preview chips
            _buildPersonaPreviewChips(),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        AppSound.selectionClick();
        return _fetchPersonas();
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _personas.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final persona = _personas[index];
          final isLocked = !_isPremium &&
              persona.subscriptionTier.toLowerCase() == 'premium';
          return StaggeredEntrance(
            index: index,
            child: _PersonaCard(
              persona: persona,
              isLocked: isLocked,
              onTap: () {
                AppSound.selectionClick();
                if (isLocked) {
                  _showUpgradeDialog();
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ChatScreen(persona: persona)),
                  );
                }
              },
              onDelete: persona.isOwned ? () => _deletePersona(persona) : null,
            ),
          );
        },
      ),
    );
  }

  void _showUpgradeDialog() {
    AppSound.mediumImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.bestFriendLight, AppColors.bestFriendDark],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.workspace_premium_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'Premium Persona',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: const Text(
          'This persona is available with Premium. Upgrade to unlock all companions and unlimited messages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe later'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const UpgradeScreen()));
              if (mounted) _fetchPersonas();
            },
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }
}

// ── Persona Card ─────────────────────────────────────────────────────────

class _PersonaCard extends StatefulWidget {
  final Persona persona;
  final bool isLocked;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _PersonaCard({
    required this.persona,
    required this.isLocked,
    required this.onTap,
    this.onDelete,
  });

  @override
  State<_PersonaCard> createState() => _PersonaCardState();
}

class _PersonaCardState extends State<_PersonaCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _glowAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gradient = AppColors.personaGradient(widget.persona.name);
    final locked = widget.isLocked;

    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) {
        _pressController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressController.reverse(),
      child: AnimatedBuilder(
        animation: _glowAnim,
        builder: (context, _) {
          final t = _glowAnim.value;
          return Transform.scale(
            scale: 1.0 - 0.02 * t,
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: locked
                        ? Colors.black.withValues(alpha: 0.1 + 0.05 * t)
                        : gradient.first.withValues(alpha: 0.2 + 0.2 * t),
                    blurRadius: 16 + 12 * t,
                    offset: Offset(0, 4 + 4 * t),
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    // ── Gradient background ──
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: locked
                              ? [
                                  gradient.first.withValues(alpha: 0.35),
                                  gradient.last.withValues(alpha: 0.25),
                                ]
                              : [
                                  gradient.first.withValues(alpha: 0.85),
                                  gradient.last,
                                ],
                        ),
                      ),
                    ),
                    // ── Decorative circles ──
                    Positioned(
                      top: -20,
                      right: -20,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: locked ? 0.05 : 0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -30,
                      left: -10,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: locked ? 0.03 : 0.07),
                        ),
                      ),
                    ),
                    // ── Content ──
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          // ── Avatar with ring ──
                          Opacity(
                            opacity: locked ? 0.5 : 1.0,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: PersonaAvatar(
                                personaName: widget.persona.name,
                                size: 56,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // ── Text content ──
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        widget.persona.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white.withValues(alpha: locked ? 0.7 : 1.0),
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _TierChip(
                                      tier: widget.persona.subscriptionTier,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  (widget.persona.greeting?.isNotEmpty ?? false)
                                      ? widget.persona.greeting!
                                      : _humanize(widget.persona.role),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: locked ? 0.5 : 0.85),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // ── Trailing actions ──
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (locked)
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                  child: const Icon(
                                    Icons.lock_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                )
                              else if (widget.onDelete != null)
                                GestureDetector(
                                  onTap: widget.onDelete,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withValues(alpha: 0.2),
                                    ),
                                    child: Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: Colors.white.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Icon(
                                locked
                                    ? Icons.arrow_forward_ios_rounded
                                    : Icons.arrow_forward_ios_rounded,
                                size: 16,
                                color: Colors.white.withValues(alpha: locked ? 0.4 : 0.6),
                              ),
                            ],
                          ),
                        ],
                      ),
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

  String _humanize(String value) {
    if (value.trim().isEmpty) return 'Companion';
    final spaced = value.replaceAll('_', ' ');
    return spaced[0].toUpperCase() + spaced.substring(1);
  }
}

// ── Tier Chip ────────────────────────────────────────────────────────────

class _TierChip extends StatelessWidget {
  final String tier;

  const _TierChip({required this.tier});

  @override
  Widget build(BuildContext context) {
    final isPremium = tier.toLowerCase() == 'premium';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isPremium
            ? Colors.white.withValues(alpha: 0.25)
            : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPremium
                ? Icons.workspace_premium_rounded
                : Icons.lock_open_rounded,
            size: 10,
            color: Colors.white,
          ),
          const SizedBox(width: 3),
          Text(
            isPremium ? 'premium' : 'free',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
