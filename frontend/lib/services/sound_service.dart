import 'package:flutter/services.dart';

/// Minimal sound effects for InnerCircle.
///
/// Uses only system haptic feedback — no audio files, no external packages.
/// The vocabulary is intentionally small and consistent:
///   - selectionClick: opening pickers, scrolling
///   - lightImpact: sending messages, toggling switches
///   - mediumImpact: completing actions, reactions, upgrades
class AppSound {
  AppSound._();

  static void selectionClick() => HapticFeedback.selectionClick();
  static void lightImpact() => HapticFeedback.lightImpact();
  static void mediumImpact() => HapticFeedback.mediumImpact();
  static void heavyImpact() => HapticFeedback.heavyImpact();
}
