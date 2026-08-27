import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController _bgController;
  late final AnimationController _particleController;

  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final Animation<double> _rotate;
  late final Animation<double> _subtitleFade;
  late final Animation<Offset> _subtitleSlide;
  late final Animation<double> _bgProgress;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _scale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.1, 0.5, curve: Curves.easeOut),
      ),
    );
    _rotate = Tween<double>(begin: -0.5, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
      ),
    );
    _subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.45, 0.75, curve: Curves.easeOut),
      ),
    );
    _subtitleSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.45, 0.75, curve: Curves.easeOutCubic),
    ));
    _bgProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bgController, curve: Curves.linear),
    );

    _mainController.forward();
    _bgController.repeat();
    _particleController.forward();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _bgController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_mainController, _bgController]),
        builder: (context, _) {
          return Container(
            decoration: BoxDecoration(
              gradient: _buildAnimatedGradient(),
            ),
            child: Stack(
              children: [
                // Decorative floating particles
                ..._buildParticles(),
                // Main content
                Center(
                  child: FadeTransition(
                    opacity: _fade,
                    child: ScaleTransition(
                      scale: _scale,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo with ring animation
                          Transform.rotate(
                            angle: _rotate.value,
                            child: _buildLogo(),
                          ),
                          const SizedBox(height: 36),
                          // App name
                          _buildAppName(),
                          const SizedBox(height: 8),
                          // Subtitle
                          SlideTransition(
                            position: _subtitleSlide,
                            child: FadeTransition(
                              opacity: _subtitleFade,
                              child: _buildSubtitle(),
                            ),
                          ),
                          const SizedBox(height: 48),
                          // Loading indicator
                          _buildLoadingIndicator(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  LinearGradient _buildAnimatedGradient() {
    final t = _bgProgress.value;
    final angle = t * 2 * pi;

    // Rotate through persona colors
    final colors = [
      AppColors.primary,
      AppColors.momDark,
      AppColors.bestFriendDark,
      AppColors.girlfriendDark,
      AppColors.bigSisterDark,
      AppColors.primaryDark,
    ];

    final index = (t * colors.length).floor() % colors.length;
    final nextIndex = (index + 1) % colors.length;
    final localT = (t * colors.length) % 1.0;

    return LinearGradient(
      begin: Alignment(
        cos(angle),
        sin(angle),
      ),
      end: Alignment(
        -cos(angle),
        -sin(angle),
      ),
      colors: [
        Color.lerp(colors[index], colors[nextIndex], localT)!,
        Color.lerp(
          colors[(index + 2) % colors.length],
          colors[(nextIndex + 2) % colors.length],
          localT,
        )!,
      ],
    );
  }

  List<Widget> _buildParticles() {
    final random = Random(42);
    return List.generate(12, (i) {
      final size = 4.0 + random.nextDouble() * 8;
      final left = random.nextDouble() * MediaQuery.sizeOf(context).width;
      final top = random.nextDouble() * MediaQuery.sizeOf(context).height;
      final delay = i * 0.08;

      final fadeAnim = Tween<double>(begin: 0.0, end: 0.15 + random.nextDouble() * 0.15).animate(
        CurvedAnimation(
          parent: _particleController,
          curve: Interval(delay, (delay + 0.3).clamp(0.0, 1.0), curve: Curves.easeOut),
        ),
      );

      return Positioned(
        left: left,
        top: top,
        child: FadeTransition(
          opacity: fadeAnim,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ),
      );
    });
  }

  Widget _buildLogo() {
    return Container(
      width: 110,
      height: 110,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.15),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.1),
            blurRadius: 48,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: const Icon(
        Icons.favorite_rounded,
        color: Colors.white,
        size: 50,
      ),
    );
  }

  Widget _buildAppName() {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Colors.white, Color(0xFFE8D5F5)],
      ).createShader(bounds),
      child: const Text(
        'InnerCircle',
        style: TextStyle(
          color: Colors.white,
          fontSize: 36,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
        ),
      ),
    );
  }

  Widget _buildSubtitle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Text(
        'someone who understands',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 14,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return SizedBox(
      width: 28,
      height: 28,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: AlwaysStoppedAnimation(
          Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}
