import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shown for the brief window while main.dart checks whether a saved auth
/// token exists (AuthService.isLoggedIn()) and decides whether to route to
/// HomeScreen or LoginScreen.
///
/// UX reasoning: the app previously handled this wait with a bare
/// CircularProgressIndicator on a blank white Scaffold -- functionally
/// fine, but it's the very first thing anyone sees when opening the app,
/// and a bare spinner on white communicates "this is loading" and nothing
/// else. It's also the one moment in the whole app where there's zero
/// competing content on screen, which makes it the cheapest possible place
/// to establish who this app is and what it feels like, before the person
/// has read a single word of UI. A named, animated brand moment costs
/// nothing functionally over a bare spinner and buys a lot of "this feels
/// considered" on first impression.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final Animation<Color?> _bgColor;
  late final Animation<double> _rotate;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _scale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
      ),
    );
    _bgColor = ColorTween(
      begin: AppColors.primaryDark,
      end: AppColors.primary,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _rotate = Tween<double>(begin: -0.3, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
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
    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.5,
                colors: [
                  _bgColor.value ?? AppColors.primary,
                  AppColors.primaryDark,
                ],
              ),
            ),
            child: Center(
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.rotate(
                        angle: _rotate.value,
                        child: Container(
                          width: 96,
                          height: 96,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.favorite_rounded,
                            color: Colors.white,
                            size: 44,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'InnerCircle',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'someone to talk to',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 15,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation(
                            Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
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
