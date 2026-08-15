import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../services/sound_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;

  // Entrance animation
  late AnimationController _animController;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<Offset> _titleSlide;
  late Animation<Offset> _field1Slide;
  late Animation<Offset> _field2Slide;
  late Animation<Offset> _buttonSlide;
  late Animation<double> _allFade;

  // Shake animation for invalid fields
  late AnimationController _shakeController;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));

    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.4, curve: Curves.elasticOut),
    ));
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
    ));
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.15, 0.5, curve: Curves.easeOutCubic),
    ));
    _field1Slide =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.3, 0.6, curve: Curves.easeOutCubic),
      ),
    );
    _field2Slide =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.4, 0.7, curve: Curves.easeOutCubic),
      ),
    );
    _buttonSlide =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.55, 0.85, curve: Curves.easeOutCubic),
      ),
    );
    _allFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
    ));
    _shakeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) {
      // Shake the form to indicate error
      _shakeController.forward(from: 0.0);
      AppSound.heavyImpact();
      return;
    }
    setState(() => _loading = true);
    AppSound.lightImpact();
    try {
      await AuthService.login(
          _emailController.text.trim(), _passwordController.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (_, _, _) =>
              Container(color: Theme.of(context).scaffoldBackgroundColor),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      AppSound.heavyImpact();
      _shakeController.forward(from: 0.0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: AnimatedBuilder(
              animation: _shakeAnim,
              builder: (context, child) {
                final shakeOffset =
                    _shakeAnim.status == AnimationStatus.forward ||
                            _shakeAnim.status == AnimationStatus.completed
                        ? (1 - _shakeAnim.value) *
                            6 *
                            ((_shakeController.value * 4).toInt() % 2 == 0
                                ? 1.0
                                : -1.0)
                        : 0.0;
                return Transform.translate(
                  offset: Offset(shakeOffset, 0),
                  child: child,
                );
              },
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),
                    ScaleTransition(
                      scale: _logoScale,
                      child: FadeTransition(
                        opacity: _logoFade,
                        child: Container(
                          width: 72,
                          height: 72,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primaryDark
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.favorite_rounded,
                              color: Colors.white, size: 32),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SlideTransition(
                      position: _titleSlide,
                      child: Text('Welcome back',
                          style:
                              Theme.of(context).textTheme.headlineSmall),
                    ),
                    const SizedBox(height: 6),
                    SlideTransition(
                      position: _titleSlide,
                      child: Text('Someone in your circle missed you.',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ),
                    const SizedBox(height: 36),
                    SlideTransition(
                      position: _field1Slide,
                      child: FadeTransition(
                        opacity: _allFade,
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.mail_outline_rounded),
                          ),
                          validator: (v) => (v != null && v.contains('@'))
                              ? null
                              : 'Enter a valid email',
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SlideTransition(
                      position: _field2Slide,
                      child: FadeTransition(
                        opacity: _allFade,
                        child: TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon:
                                const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                              onPressed: () => setState(() =>
                                  _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (v) => (v != null && v.length >= 6)
                              ? null
                              : 'At least 6 characters',
                          onFieldSubmitted: (_) => _login(),
                        ),
                      ),
                    ),
                    FadeTransition(
                      opacity: _allFade,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.pushNamed(
                              context, '/forgot-password'),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SlideTransition(
                      position: _buttonSlide,
                      child: FilledButton(
                        onPressed: _loading ? null : _login,
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white),
                              )
                            : const Text('Log in'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FadeTransition(
                      opacity: _allFade,
                      child: TextButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/register'),
                        child: const Text(
                            "Don't have an account? Create one"),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
