import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/memories_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/notifications_screen.dart';
import 'services/auth_service.dart';
import 'services/push_notification_service.dart';
import 'theme/app_theme.dart';
import 'widgets/splash_screen.dart';

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