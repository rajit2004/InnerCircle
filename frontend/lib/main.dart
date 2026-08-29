import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/memories_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/auth_service.dart';
import 'services/push_notification_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'widgets/splash_screen.dart';

/// Global navigator key so ApiClient can redirect to login on 401/403
/// without needing a BuildContext.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<Map<String, dynamic>> _initApp() async {
  final loggedIn = await AuthService.isLoggedIn();
  final prefs = await SharedPreferences.getInstance();
  final onboardingSeen = prefs.getBool('onboarding_seen') ?? false;
  return {'loggedIn': loggedIn, 'onboardingSeen': onboardingSeen};
}

// FEATURE (push notifications, 2026-07-05): main() has to become async
// to initialize Firebase before anything else runs, and the background
// message handler has to be registered here, at the top level, before
// runApp -- FirebaseMessaging.onBackgroundMessage requires this exact
// setup to be able to invoke the handler from a separate isolate when
// the app is fully terminated. See PUSH_NOTIFICATIONS_SETUP.md for the
// one manual step (a real Firebase project) this still depends on --
// without it, Firebase.initializeApp() throws, which is caught here so
// the app still starts normally with push notifications simply inactive.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // FEATURE (dark mode, 2026-07-06): load the persisted theme preference
  // before the first frame so the app opens directly in the right mode
  // instead of flashing light mode and then switching.
  await ThemeController.load();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase initialization skipped/failed: $e');
  }

  runApp(const InnerCircleApp());
}

class InnerCircleApp extends StatelessWidget {
  const InnerCircleApp({super.key});

  @override
  Widget build(BuildContext context) {
    // FEATURE (dark mode, 2026-07-06): wrapping MaterialApp in a
    // ValueListenableBuilder listening to ThemeController.mode means
    // toggling dark mode anywhere in the app (see settings_screen.dart)
    // rebuilds the whole tree with the new theme immediately -- no need
    // to thread a callback through every screen.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'InnerCircle',
          // DESIGN FIX (2026-07-03): replaced the ColorScheme.fromSeed() theme
          // with AppTheme.light -- a hand-built design system with a warm,
          // deliberate color and type language instead of Material3's
          // auto-generated one. See lib/theme/app_theme.dart for the full
          // rationale and DESIGN.md for the system overview.
          //
          // FEATURE (dark mode, 2026-07-06): now picks AppTheme.light or
          // AppTheme.dark based on the current ThemeController.mode value
          // instead of always using AppTheme.light.
          theme: mode == ThemeMode.dark ? AppTheme.dark : AppTheme.light,
          initialRoute: '/',
          routes: {
            '/': (context) => FutureBuilder(
              future: _initApp(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SplashScreen();
                }
                final data = snapshot.data;
                final loggedIn = data?['loggedIn'] ?? false;
                final onboardingSeen = data?['onboardingSeen'] ?? false;
                if (!onboardingSeen) {
                  return const OnboardingScreen();
                }
                if (loggedIn) {
                  return const HomeScreen();
                } else {
                  return const LoginScreen();
                }
              },
            ),
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/onboarding': (context) => const OnboardingScreen(),
            '/home': (context) => const HomeScreen(),
            '/memories': (context) => const MemoriesScreen(),
            '/profile': (context) => const ProfileScreen(),
            '/notifications': (context) => const NotificationsScreen(),
            // FEATURE (dark mode, 2026-07-06)
            '/settings': (context) => const SettingsScreen(),
            // FEATURE (forgot password, 2026-07-06)
            '/forgot-password': (context) => const ForgotPasswordScreen(),
            '/reset-password': (context) => const ResetPasswordScreen(),
          },
        );
      },
    );
  }
}