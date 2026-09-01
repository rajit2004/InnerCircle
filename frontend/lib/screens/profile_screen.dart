import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/api_client.dart';
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
        SnackBar(content: Text('Failed: ${e.toString().replaceFirst('Exception: ', '')}')),
      );
    }
  }

  Future<void> _confirmLogout() async {
    AppSound.lightImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Log out?'),
        content: const Text("You'll need your email and password to sign back in."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Log out')),
        ],
      ),
    );
    if (confirmed == true) {
      await AuthService.logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    AppSound.selectionClick();
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 80);
      if (picked == null) return;

      setState(() => _loading = true);
      final updated = await UserService.uploadAvatar(File(picked.path));
      if (!mounted) return;
      setState(() {
        _profile = updated;
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo updated')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: AppColors.error),
      );
    }
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
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadAvatar();
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit display name'),
              onTap: () {
                Navigator.pop(ctx);
                _editDisplayName(_profile!);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();
    if (!widget.showAppBar) return content;
    return Scaffold(appBar: AppBar(title: const Text('Profile')), body: content);
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: ShimmerPlaceholder(width: 200, height: 200));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 40, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: _loadProfile, icon: const Icon(Icons.refresh), label: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final profile = _profile!;
    final hasAvatar = profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _loadProfile,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {
                    AppSound.selectionClick();
                    _showAvatarOptions();
                  },
                  child: hasAvatar ? _NetworkAvatar(url: profile.avatarUrl!) : _BouncyAvatar(initial: _initial(profile.email)),
                ),
                const SizedBox(height: 14),
                Text(
                  profile.displayName?.isNotEmpty == true ? profile.displayName! : profile.email,
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
          _SubscriptionCard(isPremium: profile.isPremium, updating: _updatingTier, onToggle: _toggleSubscription, onUpgrade: _openUpgrade),
          const SizedBox(height: 20),

          // ── Account Details ──────────────────────────────────────
          Text('Account details', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                _DetailTile(
                  icon: Icons.person_outline_rounded,
                  label: 'Display name',
                  value: profile.displayName?.isNotEmpty == true ? profile.displayName! : 'Not set',
                  trailing: IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _editDisplayName(profile)),
                ),
                const Divider(height: 1, indent: 56),
                _DetailTile(icon: Icons.mail_outline_rounded, label: 'Email', value: profile.email),
                const Divider(height: 1, indent: 56),
                _DetailTile(
                  icon: Icons.cake_outlined,
                  label: 'Date of birth',
                  value: profile.dateOfBirth != null ? _formatDob(profile.dateOfBirth!) : 'Not set',
                  trailing: IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _editDateOfBirth(profile)),
                ),
                const Divider(height: 1, indent: 56),
                _DetailTile(
                  icon: Icons.language_rounded,
                  label: 'Language',
                  value: profile.language ?? 'en',
                  trailing: IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _editLanguage(profile)),
                ),
                const Divider(height: 1, indent: 56),
                _DetailTile(
                  icon: Icons.access_time_rounded,
                  label: 'Timezone',
                  value: profile.timezone ?? 'UTC',
                  trailing: IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _editTimezone(profile)),
                ),
                const Divider(height: 1, indent: 56),
                _DetailTile(icon: Icons.calendar_today_outlined, label: 'Member since', value: _formatDate(profile.memberSince)),
                const Divider(height: 1, indent: 56),
                _DetailTile(icon: Icons.fingerprint_rounded, label: 'Account ID', value: profile.id),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Security ─────────────────────────────────────────────
          Text('Security', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          _NudgeTile(
            icon: Icons.lock_outline_rounded,
            title: 'Change password',
            subtitle: 'Update your account password',
            onTap: () => _changePassword(),
          ),
          const SizedBox(height: 20),

          // ── Preferences ──────────────────────────────────────────
          Text('Preferences', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          _NudgeTile(
            icon: Icons.notifications_outlined,
            title: 'Check-in reminders',
            subtitle: 'Manage scheduled persona check-ins',
            onTap: () => Navigator.push(
              context,
              PageRouteBuilder(
                transitionDuration: const Duration(milliseconds: 350),
                reverseTransitionDuration: const Duration(milliseconds: 250),
                pageBuilder: (_, _, _) => const NotificationsScreen(),
                transitionsBuilder: (_, animation, _, child) {
                  final fadeAnim = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
                  final slideAnim = Tween<Offset>(
                    begin: const Offset(0.03, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
                  return FadeTransition(
                    opacity: fadeAnim,
                    child: SlideTransition(position: slideAnim, child: child),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          _NudgeTile(
            icon: Icons.settings_outlined,
            title: 'Settings',
            subtitle: 'Appearance and app info',
            onTap: () => Navigator.push(
              context,
              PageRouteBuilder(
                transitionDuration: const Duration(milliseconds: 350),
                reverseTransitionDuration: const Duration(milliseconds: 250),
                pageBuilder: (_, _, _) => const SettingsScreen(),
                transitionsBuilder: (_, animation, _, child) {
                  final fadeAnim = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
                  final slideAnim = Tween<Offset>(
                    begin: const Offset(0.03, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
                  return FadeTransition(
                    opacity: fadeAnim,
                    child: SlideTransition(position: slideAnim, child: child),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Danger Zone ──────────────────────────────────────────
          Text('Danger zone', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.error)),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: const Icon(Icons.delete_forever_rounded, color: AppColors.error),
              title: const Text('Delete account', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
              subtitle: const Text('Permanently delete your account and all data'),
              onTap: _confirmDeleteAccount,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: const Icon(Icons.logout_rounded, color: AppColors.error),
              title: const Text('Log out', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
              onTap: _confirmLogout,
            ),
          ),
        ],
      ),
    );
  }

  // ── Edit Display Name ──────────────────────────────────────────
  Future<void> _editDisplayName(UserProfile profile) async {
    AppSound.selectionClick();
    final controller = TextEditingController(text: profile.displayName ?? '');
    final newName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Theme.of(ctx).dividerColor, borderRadius: BorderRadius.circular(2)))),
              Text('Edit display name', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(controller: controller, autofocus: true, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Display name', hintText: 'How should we call you?', prefixIcon: Icon(Icons.person_outline_rounded))),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Save'))),
            ],
          ),
        ),
      ),
    );
    if (newName == null) return;
    try {
      final updated = await UserService.updateProfile(displayName: newName.isEmpty ? null : newName);
      if (!mounted) return;
      setState(() => _profile = updated);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Display name updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: AppColors.error),
      );
    }
  }

  // ── Edit Date of Birth ─────────────────────────────────────────
  Future<void> _editDateOfBirth(UserProfile profile) async {
    AppSound.selectionClick();
    final picked = await showDatePicker(
      context: context,
      initialDate: profile.dateOfBirth ?? DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    try {
      final dob = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      final updated = await UserService.updateProfile(dateOfBirth: dob);
      if (!mounted) return;
      setState(() => _profile = updated);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Date of birth updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: AppColors.error),
      );
    }
  }

  // ── Edit Language ──────────────────────────────────────────────
  Future<void> _editLanguage(UserProfile profile) async {
    AppSound.selectionClick();
    final languages = <String, String>{
      'English': 'en', 'Spanish': 'es', 'French': 'fr', 'German': 'de',
      'Hindi': 'hi', 'Portuguese': 'pt', 'Japanese': 'ja', 'Korean': 'ko',
      'Chinese': 'zh', 'Arabic': 'ar', 'Russian': 'ru', 'Italian': 'it',
    };
    final currentCode = profile.language ?? 'en';
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Language'),
        children: languages.entries.map((e) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, e.value),
          child: Row(
            children: [
              if (e.value == currentCode) const Icon(Icons.check_rounded, size: 18, color: AppColors.primary) else const SizedBox(width: 18),
              const SizedBox(width: 12),
              Text(e.key),
            ],
          ),
        )).toList(),
      ),
    );
    if (selected == null || selected == currentCode) return;
    try {
      final updated = await UserService.updateProfile(language: selected);
      if (!mounted) return;
      setState(() => _profile = updated);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Language updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: AppColors.error),
      );
    }
  }

  // ── Edit Timezone ──────────────────────────────────────────────
  Future<void> _editTimezone(UserProfile profile) async {
    AppSound.selectionClick();
    final controller = TextEditingController(text: profile.timezone ?? 'UTC');
    final newTz = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Theme.of(ctx).dividerColor, borderRadius: BorderRadius.circular(2)))),
              Text('Edit timezone', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Common: UTC, America/New_York, Asia/Kolkata, Europe/London', style: Theme.of(ctx).textTheme.bodySmall),
              const SizedBox(height: 16),
              TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Timezone', hintText: 'e.g. UTC, America/New_York', prefixIcon: Icon(Icons.access_time_rounded))),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Save'))),
            ],
          ),
        ),
      ),
    );
    if (newTz == null || newTz.isEmpty) return;
    try {
      final updated = await UserService.updateProfile(timezone: newTz);
      if (!mounted) return;
      setState(() => _profile = updated);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Timezone updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: AppColors.error),
      );
    }
  }

  // ── Change Password ────────────────────────────────────────────
  Future<void> _changePassword() async {
    AppSound.selectionClick();
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Change password'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: currentCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Current password', prefixIcon: Icon(Icons.lock_outline_rounded))),
              const SizedBox(height: 12),
              TextField(controller: newCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'New password', prefixIcon: Icon(Icons.lock_rounded))),
              const SizedBox(height: 12),
              TextField(controller: confirmCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm new password', prefixIcon: Icon(Icons.lock_rounded))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Update')),
        ],
      ),
    );

    if (result != true) return;
    if (!mounted) return;

    if (newCtrl.text != confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match'), backgroundColor: AppColors.error));
      return;
    }
    if (newCtrl.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be at least 8 characters'), backgroundColor: AppColors.error));
      return;
    }

    try {
      await UserService.changePassword(currentPassword: currentCtrl.text, newPassword: newCtrl.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: AppColors.error),
      );
    }
  }

  // ── Delete Account ─────────────────────────────────────────────
  Future<void> _confirmDeleteAccount() async {
    AppSound.lightImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete account?'),
        content: const Text('This action cannot be undone. All your data, conversations, and memories will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete forever'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    // Double confirm
    final doubleConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Are you absolutely sure?'),
        content: const Text('Type your understanding that this cannot be undone. Press Delete to proceed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete my account'),
          ),
        ],
      ),
    );
    if (doubleConfirm != true) return;

    try {
      await UserService.deleteAccount();
      if (!mounted) return;
      await AuthService.logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: AppColors.error),
      );
    }
  }

  String _initial(String email) {
    final trimmed = email.trim();
    return trimmed.isEmpty ? 'U' : trimmed.substring(0, 1).toUpperCase();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatDob(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

// ── Network Avatar ─────────────────────────────────────────────────

class _NetworkAvatar extends StatelessWidget {
  final String url;
  const _NetworkAvatar({required this.url});

  @override
  Widget build(BuildContext context) {
    final fullUrl = url.startsWith('http') ? url : '$baseUrl$url';
    return Container(
      width: 84,
      height: 84,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        fullUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
          ),
          child: const Center(child: Icon(Icons.person_rounded, size: 40, color: Colors.white)),
        ),
      ),
    );
  }
}

// ── Bouncy Avatar ────────────────────────────────────────────────

class _BouncyAvatar extends StatefulWidget {
  final String initial;
  const _BouncyAvatar({required this.initial});

  @override
  State<_BouncyAvatar> createState() => _BouncyAvatarState();
}

class _BouncyAvatarState extends State<_BouncyAvatar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
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
            gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
          ),
          child: Center(
            child: Text(widget.initial, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

// ── Nudge Tile ───────────────────────────────────────────────────

class _NudgeTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NudgeTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  State<_NudgeTile> createState() => _NudgeTileState();
}

class _NudgeTileState extends State<_NudgeTile> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _nudge;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _nudge = Tween<double>(begin: 0.0, end: 4.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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

// ── Tier Badge ───────────────────────────────────────────────────

class _TierBadge extends StatelessWidget {
  final bool isPremium;
  const _TierBadge({required this.isPremium});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        gradient: isPremium ? const LinearGradient(colors: [AppColors.bestFriendDark, AppColors.momDark]) : null,
        color: isPremium ? null : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isPremium ? Icons.workspace_premium_rounded : Icons.lock_open_rounded, size: 15, color: isPremium ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(isPremium ? 'Premium' : 'Free plan', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: isPremium ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ── Usage Card ───────────────────────────────────────────────────

class _UsageCard extends StatelessWidget {
  final UserProfile profile;
  const _UsageCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final limit = profile.dailyMessageLimit == 0 ? 50 : profile.dailyMessageLimit;
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
                Text("Today's messages", style: Theme.of(context).textTheme.titleMedium),
                Text('$used / $limit', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratio, minHeight: 8,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(ratio > 0.85 ? AppColors.error : AppColors.primary),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              remaining == 0 ? "You've used all your free messages for today -- upgrade for unlimited." : '$remaining message${remaining == 1 ? '' : 's'} left today.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Subscription Card ────────────────────────────────────────────

class _SubscriptionCard extends StatelessWidget {
  final bool isPremium;
  final bool updating;
  final VoidCallback onToggle;
  final VoidCallback onUpgrade;

  const _SubscriptionCard({required this.isPremium, required this.updating, required this.onToggle, required this.onUpgrade});

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
                Icon(isPremium ? Icons.workspace_premium_rounded : Icons.lock_open_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(isPremium ? "You're on Premium" : 'Free plan', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 10),
            if (!isPremium) ...[
              const _BenefitRow(text: 'Unlimited daily messages'),
              const _BenefitRow(text: 'Unlocks Girlfriend & Big Sister'),
            ] else
              Text('Unlimited messages and every persona is unlocked.', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: isPremium
                  ? OutlinedButton(
                      onPressed: updating ? null : onToggle,
                      child: updating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Switch back to Free'),
                    )
                  : FilledButton(onPressed: onUpgrade, child: const Text('Upgrade to Premium')),
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

class _DetailTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  const _DetailTile({required this.icon, required this.label, required this.value, this.trailing});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      subtitle: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
      trailing: trailing,
    );
  }
}
