import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  final bool showAppBar;

  const ProfileScreen({super.key, this.showAppBar = true});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = await AuthService.currentUser();
    if (!mounted) return;
    setState(() {
      _user = user;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();

    if (!widget.showAppBar) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: content,
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final user = _user;
    if (user == null) {
      return const Center(child: Text('No profile saved'));
    }

    final tier = user.subscriptionTier.toLowerCase() == 'premium'
        ? 'premium'
        : 'free';

    return RefreshIndicator(
      onRefresh: _loadProfile,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    child: Text(
                      _initial(user.email),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        _SubscriptionPill(tier: tier),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            child: Column(
              children: [
                _ProfileTile(
                  icon: Icons.mail_outline,
                  label: 'Email',
                  value: user.email,
                ),
                const Divider(height: 1),
                _ProfileTile(
                  icon: Icons.badge_outlined,
                  label: 'Role',
                  value: user.role,
                ),
                const Divider(height: 1),
                _ProfileTile(
                  icon: Icons.workspace_premium_outlined,
                  label: 'Subscription',
                  value: tier,
                ),
                if (user.id.isNotEmpty) ...[
                  const Divider(height: 1),
                  _ProfileTile(
                    icon: Icons.fingerprint,
                    label: 'User ID',
                    value: user.id,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initial(String email) {
    final trimmed = email.trim();
    if (trimmed.isEmpty || trimmed == 'Unknown email') return 'U';
    return trimmed.substring(0, 1).toUpperCase();
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
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }
}

class _SubscriptionPill extends StatelessWidget {
  final String tier;

  const _SubscriptionPill({required this.tier});

  @override
  Widget build(BuildContext context) {
    final isPremium = tier == 'premium';
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isPremium
            ? colorScheme.tertiaryContainer
            : colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isPremium ? 'premium' : 'free',
        style: TextStyle(
          color: isPremium
              ? colorScheme.onTertiaryContainer
              : colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
