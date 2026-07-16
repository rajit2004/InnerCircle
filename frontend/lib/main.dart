import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/memories_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/notifications_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'widgets/splash_screen.dart';

void main() {
  runApp(const InnerCircleApp());
}

class InnerCircleApp extends StatelessWidget {
  const InnerCircleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InnerCircle',
      // DESIGN FIX (2026-07-03): replaced the ColorScheme.fromSeed() theme
      // with AppTheme.light -- a hand-built design system with a warm,
      // deliberate color and type language instead of Material3's
      // auto-generated one. See lib/theme/app_theme.dart for the full
      // rationale and DESIGN.md for the system overview.
      theme: AppTheme.light,
      initialRoute: '/',
      routes: {
        '/': (context) => FutureBuilder(
          future: AuthService.isLoggedIn(),
          builder: (context, snapshot) {
            // DESIGN FIX (2026-07-03): this branch used to be a bare
            // CircularProgressIndicator on a blank Scaffold -- the very
            // first thing anyone sees when opening the app. Swapped in the
            // branded SplashScreen (see widgets/splash_screen.dart) for
            // the same wait, at zero extra cost -- the wait was already
            // happening, this just gives it a face.
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SplashScreen();
            }
            if (snapshot.data == true) {
              return const HomeScreen();
            } else {
              return const LoginScreen();
            }
          },
        ),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/memories': (context) => const MemoriesScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/notifications': (context) => const NotificationsScreen(),
      },
    );
  }
}