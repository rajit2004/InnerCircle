import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// InnerCircle design system.
///
/// Design intent: this is a companion app people open when they want warmth,
/// not a productivity tool. The default Material3 seeded theme (a single
/// seed color auto-generating everything) reads as generic and slightly
/// cold -- every persona ends up wearing the same tint, so "Mom" and "Big
/// Sister" look and feel identical before you've read a single word. That
/// undersells the actual product idea (four distinct companions), and
/// nothing about the visual language says "this app is about people/emotion"
/// versus "this is a CRUD app."
///
/// Fix: one warm, editorial brand anchor for the app shell (AppBar, buttons,
/// focus states) + a distinct, deliberately-chosen accent color per persona,
/// used consistently everywhere that persona shows up (avatar, chat bubbles,
/// tier chip). The persona colors are picked to carry emotional meaning, not
/// just to look different from each other:
///   Mom          -> warm terracotta  (nurturing, grounded, "home")
///   Best Friend  -> golden amber     (energetic, upbeat, sunny)
///   Girlfriend   -> rose pink        (romantic, soft)
///   Big Sister   -> deep teal        (protective, steady, cool-headed)
class AppColors {
  AppColors._();

  // Brand anchor -- deep plum. Sits between "serious" and "playful," warmer
  // than a corporate blue/indigo, more grown-up than a bright pastel.
  static const primary = Color(0xFF6B4C7A);
  static const primaryDark = Color(0xFF4E3659);
  static const onPrimary = Color(0xFFFFFFFF);

  // Warm neutral surfaces -- intentionally NOT pure white/pure black.
  // Pure white backgrounds next to pure black text feel clinical; a warm
  // off-white + warm charcoal reads softer without sacrificing contrast.
  static const background = Color(0xFFFBF6F3);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF3EAE6);
  static const textPrimary = Color(0xFF2D2A32);
  static const textSecondary = Color(0xFF6F6873);
  static const divider = Color(0xFFE8DFDB);

  static const error = Color(0xFFB3403A);
  static const success = Color(0xFF3F8F6D);

  // Persona accents. Each is a {light, dark} pair so avatars/chips can use
  // a subtle gradient instead of a single flat tone. FEATURE (dark mode,
  // 2026-07-06): these stay identical in dark mode on purpose -- brand/
  // accent colors that stay constant while only the neutral surfaces invert
  // is a standard, deliberate dark-mode pattern (keeps persona identity
  // consistent regardless of theme), not an oversight.
  static const momLight = Color(0xFFF0A98C);
  static const momDark = Color(0xFFD97F5C);

  static const bestFriendLight = Color(0xFFFFCB77);
  static const bestFriendDark = Color(0xFFF5A623);

  static const girlfriendLight = Color(0xFFF08CA0);
  static const girlfriendDark = Color(0xFFE85D75);

  static const bigSisterLight = Color(0xFF5FC3B0);
  static const bigSisterDark = Color(0xFF2E9484);

  static const defaultLight = Color(0xFFB6A6D4);
  static const defaultDark = Color(0xFF8C74B0);

  /// Maps a persona name to its {light, dark} gradient pair. Matches by
  /// substring against the seeded persona names (Mom, Best Friend,
  /// Girlfriend, Big Sister) with a neutral fallback for any persona added
  /// later that doesn't match one of the four -- so a new persona degrades
  /// gracefully instead of throwing or defaulting to an arbitrary color.
  static List<Color> personaGradient(String personaName) {
    final name = personaName.toLowerCase();
    if (name.contains('mom')) return [momLight, momDark];
    if (name.contains('friend')) return [bestFriendLight, bestFriendDark];
    if (name.contains('girl')) return [girlfriendLight, girlfriendDark];
    if (name.contains('sister')) return [bigSisterLight, bigSisterDark];
    return [defaultLight, defaultDark];
  }

  static IconData personaIcon(String personaName) {
    final name = personaName.toLowerCase();
    if (name.contains('mom')) return Icons.volunteer_activism_rounded;
    if (name.contains('friend')) return Icons.celebration_rounded;
    if (name.contains('girl')) return Icons.favorite_rounded;
    if (name.contains('sister')) return Icons.shield_rounded;
    return Icons.auto_awesome_rounded;
  }
}

/// FEATURE (dark mode, 2026-07-06): dark counterpart to AppColors' neutral
/// surface tokens. Only the tokens that actually need to invert for a dark
/// theme are duplicated here (background/surface/surfaceAlt/text/divider) --
/// primary/persona accents/error/success are intentionally reused as-is
/// from AppColors (see the comment on the persona accent block above).
class AppColorsDark {
  AppColorsDark._();

  static const background = Color(0xFF1C1A1F);
  static const surface = Color(0xFF262329);
  static const surfaceAlt = Color(0xFF322D36);
  static const textPrimary = Color(0xFFF1EDF0);
  static const textSecondary = Color(0xFFB6AFBC);
  static const divider = Color(0xFF3D3843);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(
    brightness: Brightness.light,
    background: AppColors.background,
    surface: AppColors.surface,
    surfaceAlt: AppColors.surfaceAlt,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    divider: AppColors.divider,
    snackBarText: Colors.white,
  );

  // FEATURE (dark mode, 2026-07-06): mirrors `light` exactly, just built
  // from AppColorsDark's neutral tokens plus the same brand/persona/error/
  // success colors reused unchanged from AppColors. This is what
  // ThemeController + main.dart's ValueListenableBuilder switch to when
  // dark mode is on.
  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    background: AppColorsDark.background,
    surface: AppColorsDark.surface,
    surfaceAlt: AppColorsDark.surfaceAlt,
    textPrimary: AppColorsDark.textPrimary,
    textSecondary: AppColorsDark.textSecondary,
    divider: AppColorsDark.divider,
    snackBarText: AppColorsDark.background,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color surfaceAlt,
    required Color textPrimary,
    required Color textSecondary,
    required Color divider,
    required Color snackBarText,
  }) {
    final base = ThemeData(useMaterial3: true, brightness: brightness);

    final textTheme = base.textTheme.copyWith(
      headlineSmall: GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        fontSize: 24,
        color: textPrimary,
        height: 1.25,
      ),
      titleLarge: GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        fontSize: 19,
        color: textPrimary,
      ),
      titleMedium: GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        color: textPrimary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 15.5,
        color: textPrimary,
        height: 1.4,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        color: textSecondary,
        height: 1.4,
      ),
      labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
    );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      // Explicit mapping so screens can read AppColors.divider's live
      // equivalent via Theme.of(context).dividerColor.
      dividerColor: divider,
      textTheme: textTheme,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        secondary: AppColors.bestFriendDark,
        surface: surface,
        onSurface: textPrimary,
        error: AppColors.error,
        primaryContainer: AppColors.primary.withValues(alpha: 0.12),
        onPrimaryContainer: AppColors.primaryDark,
        secondaryContainer: surfaceAlt,
        onSecondaryContainer: textPrimary,
        surfaceContainerHighest: surfaceAlt,
        // Explicit mapping so screens can read AppColors.textSecondary's
        // live equivalent via Theme.of(context).colorScheme.onSurfaceVariant
        // instead of the static (light-only) AppColors constant.
        onSurfaceVariant: textSecondary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: divider, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.14),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AppColors.primary : textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.primary : textSecondary,
          );
        }),
      ),
      dividerTheme: DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: TextStyle(
          fontFamily: 'Inter',
          color: snackBarText,
          fontSize: 14,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}