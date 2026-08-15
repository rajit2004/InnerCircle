import 'package:flutter/material.dart';

/// Motion design tokens for InnerCircle.
///
/// Every animation in the app should reference these constants instead of
/// hardcoding durations and curves. This ensures consistency and makes it
/// trivial to adjust the overall feel from one place.
class AppMotion {
  AppMotion._();

  // ── Timing Tiers ──────────────────────────────────────────────────────
  // Micro: button press, toggle, icon morph
  static const Duration micro = Duration(milliseconds: 150);
  // Meso: card entrance, screen transitions, sheet open
  static const Duration meso = Duration(milliseconds: 320);
  // Macro: splash reveal, subscription celebration
  static const Duration macro = Duration(milliseconds: 700);

  // ── Curves ────────────────────────────────────────────────────────────
  static const Curve easeOut = Curves.easeOut;
  static const Curve easeOutCubic = Curves.easeOutCubic;
  static const Curve spring = Curves.elasticOut;
  static const Curve springSoft = Curves.easeOutBack;

  // ── Stagger Delays ────────────────────────────────────────────────────
  // Delay between consecutive items in a staggered list (e.g. persona cards)
  static const Duration staggerDelay = Duration(milliseconds: 40);

  // ── Reduced Motion ────────────────────────────────────────────────────
  /// Returns true if the platform requests reduced motion. All custom
  /// animations should check this and use near-instant durations when true.
  static bool reducedMotion(BuildContext context) {
    return MediaQuery.of(context).disableAnimations;
  }

  /// Returns the appropriate duration considering reduced-motion pref.
  /// If reduced motion is on, returns ~50ms (near-instant but not zero).
  static Duration effectiveDuration(BuildContext context, Duration preferred) {
    if (reducedMotion(context)) return const Duration(milliseconds: 50);
    return preferred;
  }

  /// Returns the appropriate curve considering reduced-motion pref.
  /// If reduced motion is on, returns linear (no overshoot/bounce).
  static Curve effectiveCurve(BuildContext context, Curve preferred) {
    if (reducedMotion(context)) return Curves.linear;
    return preferred;
  }
}
