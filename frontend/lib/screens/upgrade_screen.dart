import 'dart:math';
import 'package:flutter/material.dart';

import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../services/sound_service.dart';

/// FEATURE (subscription upgrade, 2026-07-04): full-screen modal redesign
/// replacing the in-profile toggle. This is the app's one monetizable
/// moment and gets dedicated design investment:
/// - Animated gradient background cycling through all four persona colors
/// - Side-by-side free vs premium comparison with animated checkmarks
/// - CTA button with shimmer sweep
/// - Celebration animation on successful upgrade
class UpgradeScreen extends StatefulWidget {
  const UpgradeScreen({super.key});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen>
    with TickerProviderStateMixin {
  bool _upgrading = false;
  bool _upgraded = false;

  // Animated gradient background
  late AnimationController _gradientController;
  late Animation<double> _gradientAngle;

  // Checkmark stagger animation
  late AnimationController _checkController;
  late List<Animation<double>> _checkScales;

  // Celebration
  late AnimationController _celebController;
  late Animation<double> _celebScale;
  late Animation<double> _celebFade;

  // CTA shimmer
  late AnimationController _shimmerController;
  late Animation<double> _shimmerPosition;

  static const _benefits = [
    'All four personas unlocked',
    'Unlimited daily messages',
    'Priority response speed',
    'Early access to new features',
  ];

  @override
  void initState() {
    super.initState();

    // Gradient rotation
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _gradientAngle = Tween<double>(begin: 0, end: 2 * pi).animate(
      CurvedAnimation(parent: _gradientController, curve: Curves.linear),
    );

    // Checkmark stagger
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _checkScales = List.generate(_benefits.length, (i) {
      final delay = i * 0.12;
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _checkController,
          curve: Interval(delay, (delay + 0.4).clamp(0.0, 1.0),
              curve: Curves.elasticOut),
        ),
      );
    });

    // Celebration
    _celebController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _celebScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _celebController,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );
    _celebFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _celebController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    // CTA shimmer
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _shimmerPosition = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    // Start checkmark stagger after a brief delay
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _checkController.forward();
    });
  }

  @override
  void dispose() {
    _gradientController.dispose();
    _checkController.dispose();
    _celebController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _upgrade() async {
    if (_upgrading) return;
    setState(() => _upgrading = true);
    AppSound.mediumImpact();

    try {
      await UserService.updateSubscription('premium');
      if (!mounted) return;
      AppSound.heavyImpact();
      setState(() {
        _upgrading = false;
        _upgraded = true;
      });
      _celebController.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() => _upgrading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_upgraded) return _buildCelebration();

    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedBuilder(
            animation: _gradientAngle,
            builder: (context, _) {
              return CustomPaint(
                painter: _GradientPainter(angle: _gradientAngle.value),
                size: MediaQuery.sizeOf(context),
              );
            },
          ),
          // Content
          SafeArea(
            child: Column(
              children: [
                // Close button
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        // Premium icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.15),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.workspace_premium_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Unlock Everything',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Every companion, unlimited conversations,\nand priority responses.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 36),
                        // Comparison cards
                        _buildComparisonCards(),
                        const SizedBox(height: 32),
                        // CTA button
                        _buildCTAButton(),
                        const SizedBox(height: 16),
                        Text(
                          "No payment required — this app doesn't have billing yet.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonCards() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildFreeCard()),
        const SizedBox(width: 12),
        Expanded(child: _buildPremiumCard()),
      ],
    );
  }

  Widget _buildFreeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Free',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _BenefitCheck(text: '2 personas', included: true),
          const SizedBox(height: 8),
          _BenefitCheck(text: '50 messages/day', included: true),
          const SizedBox(height: 8),
          _BenefitCheck(text: 'All personas', included: false),
          const SizedBox(height: 8),
          _BenefitCheck(text: 'Unlimited messages', included: false),
        ],
      ),
    );
  }

  Widget _buildPremiumCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Premium',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.bestFriendDark,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '★',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(_benefits.length, (i) {
            return AnimatedBuilder(
              animation: _checkScales[i],
              builder: (context, _) {
                return ScaleTransition(
                  scale: _checkScales[i],
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            size: 16, color: AppColors.success),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _benefits[i],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCTAButton() {
    return AnimatedBuilder(
      animation: _shimmerPosition,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              colors: [
                AppColors.bestFriendDark,
                AppColors.momDark,
                AppColors.bestFriendDark,
              ],
              stops: [
                (_shimmerPosition.value - 0.3).clamp(0.0, 1.0),
                _shimmerPosition.value.clamp(0.0, 1.0),
                (_shimmerPosition.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.bestFriendDark.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(28),
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: _upgrading ? null : _upgrade,
              child: Center(
                child: _upgrading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Upgrade to Premium',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCelebration() {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _celebController,
        builder: (context, _) {
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
            ),
            child: Center(
              child: FadeTransition(
                opacity: _celebFade,
                child: ScaleTransition(
                  scale: _celebScale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 56,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Welcome to Premium!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Every persona is unlocked.\nEnjoy unlimited conversations.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 16,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 48),
                      FilledButton(
                        onPressed: () => Navigator.pop(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                          minimumSize: const Size(200, 52),
                        ),
                        child: const Text('Start chatting'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Gradient Painter ─────────────────────────────────────────────────────

class _GradientPainter extends CustomPainter {
  final double angle;

  _GradientPainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final colors = [
      AppColors.primaryDark,
      AppColors.momDark,
      AppColors.primaryDark,
    ];

    final gradient = SweepGradient(
      center: Alignment.center,
      colors: colors,
      transform: GradientRotation(angle),
    );

    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
  }

  @override
  bool shouldRepaint(_GradientPainter old) => old.angle != angle;
}

// ── Benefit Check ────────────────────────────────────────────────────────

class _BenefitCheck extends StatelessWidget {
  final String text;
  final bool included;

  const _BenefitCheck({required this.text, required this.included});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          included ? Icons.check_rounded : Icons.close_rounded,
          size: 14,
          color: Colors.white.withValues(alpha: included ? 0.9 : 0.35),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: included ? 0.9 : 0.4),
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
