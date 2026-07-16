import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import 'notifications_screen.dart';

/// UX reasoning for this redesign vs. the previous profile screen:
///
/// 1. Real data, not inference. The old screen read subscriptionTier out of
///    SharedPreferences, which was set by HomeScreen *guessing* the tier
///    from whether any persona in GET /api/personas happened to be
///    premium-tier. That guess happens to be correct today (PersonaService
///    already filters premium personas out for free users), but a "profile"
///    screen is exactly the place people go to double-check their account
///    status when something feels off -- it should be backed by an answer
///    the backend states directly, not one the client reconstructs
///    indirectly. Now wired to GET /api/users/me.
/// 2. Free-tier people have a real, useful question this screen didn't
///    answer before: "how many messages do I have left today?" Added a
///    usage bar for that, using the same 50/day limit as ChatService's
///    actual enforcement -- so what this screen shows and what the backend
///    actually enforces can't drift apart into showing wrong information.
/// 3. FEATURE (subscription upgrade, 2026-07-04): added a real way to
///    change tier. There's no payment gateway in this project, so this is
///    presented as exactly what it is -- a direct toggle -- rather than
///    dressed up to look like a checkout flow that doesn't exist.
/// 4. FEATURE (notification management, 2026-07-04): added an entry point
///    to the new check-in reminders screen.
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

  Future<void> _toggleSubscription() async {
    final profile = _profile;
    if (profile == null || _updatingTier) return;

    final goingPremium = !profile.isPremium;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(goingPremium ? 'Switch to Premium?' : 'Switch to Free?'),
        content: Text(
          goingPremium
              ? "This unlocks Girlfriend and Big Sister, and removes your daily message limit. There's no payment involved -- this app doesn't have billing set up, so this just flips the switch directly."
              : "You'll lose access to premium-only personas and go back to a 50 messages/day limit.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(goingPremium ? 'Switch to Premium' : 'Switch to Free'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _updatingTier = true);
    try {
      final updated = await UserService.updateSubscription(
        goingPremium ? 'premium' : 'free',
      );
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
                size: 40,
                color: AppColors.textSecondary,
              ),
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
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _initial(profile.email),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  profile.displayName?.isNotEmpty == true
                      ? profile.displayName!
                      : profile.email,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(profile.email, style: Theme.of(context).textTheme.bodyMedium),
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
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: const Icon(
                Icons.notifications_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Check-in reminders'),
              subtitle: const Text('Manage scheduled persona check-ins'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                );
              },
            ),
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
                horizontal: 16,
                vertical: 6,
              ),
              leading: const Icon(
                Icons.logout_rounded,
                color: AppColors.error,
              ),
              title: const Text(
                'Log out',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: _confirmLogout,
            ),
          ),
        ],
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
        color: isPremium ? null : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPremium
                ? Icons.workspace_premium_rounded
                : Icons.lock_open_rounded,
            size: 15,
            color: isPremium ? Colors.white : AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            isPremium ? 'Premium' : 'Free plan',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isPremium ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageCard extends StatelessWidget {
  final UserProfile profile;
  const _UsageCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final limit = profile.dailyMessageLimit == 0
        ? 50
        : profile.dailyMessageLimit;
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
                Text(
                  "Today's messages",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '$used / $limit',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: AppColors.surfaceAlt,
                valueColor: AlwaysStoppedAnimation(
                  ratio > 0.85 ? AppColors.error : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              remaining == 0
                  ? "You've used all your free messages for today -- more unlock tomorrow, or upgrade for unlimited."
                  : '$remaining message${remaining == 1 ? '' : 's'} left today.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// FEATURE (subscription upgrade, 2026-07-04): honest about what this is --
/// a direct toggle, not a checkout flow. No payment gateway exists in this
/// project, so this card doesn't pretend otherwise.
class _SubscriptionCard extends StatelessWidget {
  final bool isPremium;
  final bool updating;
  final VoidCallback onToggle;

  const _SubscriptionCard({
    required this.isPremium,
    required this.updating,
    required this.onToggle,
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
              const SizedBox(height: 6),
              Text(
                "This app doesn't have real billing set up -- switching plans "
                    "just flips the setting directly, no payment involved.",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
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
                    ? const _ButtonSpinner()
                    : const Text('Switch back to Free'),
              )
                  : FilledButton(
                onPressed: updating ? null : onToggle,
                child: updating
                    ? const _ButtonSpinner()
                    : const Text('Switch to Premium'),
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

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
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
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      subtitle: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
    );
  }
}