import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/motion.dart';
import '../services/sound_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  static const _pages = [
    _OnboardingPageData(
      icon: Icons.favorite_rounded,
      gradient: [Color(0xFFF08CA0), Color(0xFFE85D75)],
      title: 'Someone who\nunderstands',
      subtitle: 'Not a chatbot. Not a therapist.\nReal companions who text like people who care.',
    ),
    _OnboardingPageData(
      icon: Icons.chat_bubble_rounded,
      gradient: [Color(0xFF6B4C7A), Color(0xFF4E3659)],
      title: 'Conversations\nthat feel real',
      shortSubtitles: [
        'Short, natural replies',
        'They remember what you tell them',
        'No robotic "How can I help?"',
      ],
    ),
    _OnboardingPageData(
      icon: Icons.psychology_rounded,
      gradient: [Color(0xFFFFCB77), Color(0xFFF5A623)],
      title: 'Your circle,\nyour way',
      shortSubtitles: [
        'Built-in companions or create your own',
        'Each has a distinct personality',
        'They learn and grow with you',
      ],
    ),
    _OnboardingPageData(
      icon: Icons.shield_rounded,
      gradient: [Color(0xFF5FC3B0), Color(0xFF2E9484)],
      title: 'Private and\npersonal',
      shortSubtitles: [
        'Your conversations stay yours',
        'No data shared with anyone',
        'Talk about anything, freely',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    if (page != _currentPage) {
      AppSound.selectionClick();
      setState(() => _currentPage = page);
    }
  }

  Future<void> _complete() async {
    AppSound.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      _complete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    final isLast = _currentPage == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 16),
                  child: !isLast
                      ? TextButton(
                          onPressed: _complete,
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : const SizedBox(height: 48),
                ),
              ),
              // Page view
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    final p = _pages[index];
                    return _buildPage(p, index);
                  },
                ),
              ),
              // Dots + CTA
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Column(
                  children: [
                    // Progress dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pages.length, (i) {
                        final isActive = i == _currentPage;
                        return AnimatedContainer(
                          duration: AppMotion.micro,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: isActive ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isActive
                                ? _pages[_currentPage].gradient.first
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 28),
                    // CTA button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _next,
                        style: FilledButton.styleFrom(
                          backgroundColor: page.gradient.first,
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          isLast ? 'Get started' : 'Continue',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingPageData page, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated icon
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 700),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.6 + 0.4 * value,
                child: Opacity(
                  opacity: value.clamp(0.0, 1.0),
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
                    page.gradient.first.withValues(alpha: 0.2),
                    page.gradient.last.withValues(alpha: 0.1),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: page.gradient.first.withValues(alpha: 0.2),
                    blurRadius: 40,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Icon(
                page.icon,
                size: 52,
                color: page.gradient.first,
              ),
            ),
          ),
          const SizedBox(height: 48),
          // Title
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: child,
                ),
              );
            },
            child: Text(
              page.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 30,
                    height: 1.2,
                  ),
            ),
          ),
          const SizedBox(height: 20),
          // Subtitle
          if (page.subtitle != null)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: child,
                );
              },
              child: Text(
                page.subtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.6,
                    ),
              ),
            )
          else if (page.shortSubtitles != null)
            ...List.generate(page.shortSubtitles!.length, (i) {
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 500 + i * 150),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, 12 * (1 - value)),
                    child: Opacity(
                      opacity: value,
                      child: child,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: page.gradient.first,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        page.shortSubtitles![i],
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _OnboardingPageData {
  final IconData icon;
  final List<Color> gradient;
  final String title;
  final String? subtitle;
  final List<String>? shortSubtitles;

  const _OnboardingPageData({
    required this.icon,
    required this.gradient,
    required this.title,
    this.subtitle,
    this.shortSubtitles,
  });
}
