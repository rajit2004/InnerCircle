import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../services/sound_service.dart';
import '../widgets/shared_widgets.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import 'upgrade_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool showAppBar;

  const ProfileScreen({super.key, this.showAppBar = true});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  bool _loading = true;
  bool _updatingTier = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await UserService.getProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
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

  Future<void> _openUpgrade() async {
    AppSound.lightImpact();
    final upgraded = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const UpgradeScreen()),
    );
    if (upgraded == true) _loadProfile();
  }

  Future<void> _toggleSubscription() async {
    final profile = _profile;
    if (profile == null || _updatingTier) return;

    final goingPremium = !profile.isPremium;
    if (goingPremium) {
      _openUpgrade();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Switch to Free?'),
        content: const Text(
          "You'll lose access to premium-only personas and go back to a 50 messages/day limit.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Switch to Free'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _updatingTier = true);
    try {
      final updated = await UserService.updateSubscription('free');
      if (!mounted) return;
      setState(() {
        _profile = updated;
        _updatingTier = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _updatingTier = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update subscription: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  Future<void> _confirmLogout() async {
    AppSound.lightImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text('Log out?'),
        content: const Text(
          "You'll need your email and password to sign back in.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthService.logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();
    if (!widget.showAppBar) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: content,
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: ShimmerPlaceholder(width: 200, height: 200),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 40,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadProfile,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final profile = _profile!;

    return RefreshIndicator(
      onRefresh: _loadProfile,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          Center(
            child: Column(
              children: [
                // Animated avatar with bounce on tap
                GestureDetector(
                  onTap: () {
                    AppSound.selectionClick();
                    _showAvatarOptions();
                  },
                  child: _BouncyAvatar(initial: _initial(profile.email)),
                ),
                const SizedBox(height: 14),
                Text(
                  profile.displayName?.isNotEmpty == true
                      ? profile.displayName!
                      : profile.email,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(profile.email,
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 10),
                _TierBadge(isPremium: profile.isPremium),
              ],
            ),
          ),
          const SizedBox(height: 28),
          if (!profile.isPremium) ...[
            _UsageCard(profile: profile),
            const SizedBox(height: 16),
          ],
          _SubscriptionCard(
            isPremium: profile.isPremium,
            updating: _updatingTier,
            onToggle: _toggleSubscription,
            onUpgrade: _openUpgrade,
          ),
          const SizedBox(height: 16),
          _NudgeTile(
            icon: Icons.notifications_outlined,
            title: 'Check-in reminders',
            subtitle: 'Manage scheduled persona check-ins',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          ),
          const SizedBox(height: 16),
          _NudgeTile(
            icon: Icons.settings_outlined,
            title: 'Settings',
            subtitle: 'Appearance and app info',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                _ProfileTile(
                  icon: Icons.calendar_today_outlined,
                  label: 'Member since',
                  value: _formatDate(profile.memberSince),
                ),
                const Divider(height: 1, indent: 56),
                _ProfileTile(
                  icon: Icons.fingerprint_rounded,
                  label: 'Account ID',
                  value: profile.id,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 6),
              leading: const Icon(Icons.logout_rounded, color: AppColors.error),
              title: const Text('Log out',
                  style: TextStyle(
                      color: AppColors.error, fontWeight: FontWeight.w600)),
              onTap: _confirmLogout,
            ),
          ),
        ],
      ),
    );
  }

  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Change photo'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit display name'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  String _initial(String email) {
    final trimmed = email.trim();
    return trimmed.isEmpty ? 'U' : trimmed.substring(0, 1).toUpperCase();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}

// ── Bouncy Avatar ────────────────────────────────────────────────────────

class _BouncyAvatar extends StatefulWidget {
  final String initial;
  const _BouncyAvatar({required this.initial});

  @override
  State<_BouncyAvatar> createState() => _BouncyAvatarState();
}

class _BouncyAvatarState extends State<_BouncyAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.92), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.05), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {},
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 84,
          height: 84,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
          ),
          child: Center(
            child: Text(
              widget.initial,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Nudge Tile (with chevron nudge on press) ─────────────────────────────

class _NudgeTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NudgeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_NudgeTile> createState() => _NudgeTileState();
}

class _NudgeTileState extends State<_NudgeTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _nudge;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _nudge = Tween<double>(begin: 0.0, end: 4.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          widget.onTap();
        },
        onTapCancel: () => _controller.reverse(),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Icon(widget.icon, color: AppColors.primary),
          title: Text(widget.title),
          subtitle: Text(widget.subtitle),
          trailing: AnimatedBuilder(
            animation: _nudge,
            builder: (context, _) => Transform.translate(
              offset: Offset(_nudge.value, 0),
              child: const Icon(Icons.chevron_right_rounded),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tier Badge ───────────────────────────────────────────────────────────

class _TierBadge extends StatelessWidget {
  final bool isPremium;
  const _TierBadge({required this.isPremium});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        gradient: isPremium
            ? const LinearGradient(
                colors: [AppColors.bestFriendDark, AppColors.momDark],
              )
            : null,
        color: isPremium ? null : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPremium ? Icons.workspace_premium_rounded : Icons.lock_open_rounded,
            size: 15,
            color: isPremium ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            isPremium ? 'Premium' : 'Free plan',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isPremium ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Usage Card ───────────────────────────────────────────────────────────

class _UsageCard extends StatelessWidget {
  final UserProfile profile;
  const _UsageCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final limit =
        profile.dailyMessageLimit == 0 ? 50 : profile.dailyMessageLimit;
    final used = profile.messagesUsedToday.clamp(0, limit);
    final ratio = limit == 0 ? 0.0 : used / limit;
    final remaining = (limit - used).clamp(0, limit);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Today's messages",
                    style: Theme.of(context).textTheme.titleMedium),
                Text('$used / $limit',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  ratio > 0.85 ? AppColors.error : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              remaining == 0
                  ? "You've used all your free messages for today -- upgrade for unlimited."
                  : '$remaining message${remaining == 1 ? '' : 's'} left today.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Subscription Card ────────────────────────────────────────────────────

class _SubscriptionCard extends StatelessWidget {
  final bool isPremium;
  final bool updating;
  final VoidCallback onToggle;
  final VoidCallback onUpgrade;

  const _SubscriptionCard({
    required this.isPremium,
    required this.updating,
    required this.onToggle,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isPremium
                      ? Icons.workspace_premium_rounded
                      : Icons.lock_open_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isPremium ? "You're on Premium" : 'Free plan',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (!isPremium) ...[
              const _BenefitRow(text: 'Unlimited daily messages'),
              const _BenefitRow(text: 'Unlocks Girlfriend & Big Sister'),
            ] else
              Text(
                'Unlimited messages and every persona is unlocked.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: isPremium
                  ? OutlinedButton(
                      onPressed: updating ? null : onToggle,
                      child: updating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Switch back to Free'),
                    )
                  : FilledButton(
                      onPressed: onUpgrade,
                      child: const Text('Upgrade to Premium'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final String text;
  const _BenefitRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.check_rounded, size: 16, color: AppColors.success),
          const SizedBox(width: 6),
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading:
          Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
      title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      subtitle: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context)
            .textTheme
            .bodyLarge
            ?.copyWith(fontWeight: FontWeight.w500),
      ),
    );
  }
}
