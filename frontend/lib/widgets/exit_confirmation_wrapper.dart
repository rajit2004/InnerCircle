import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Wraps a screen (intended for HomeScreen, the app's root/lowest screen in
/// the nav stack) so that pressing the system back button from there shows
/// a confirmation dialog instead of immediately closing the app.
///
/// UX reasoning: HomeScreen is the bottom of the navigation stack -- there's
/// nothing to "go back" to, so the system back button's default behavior is
/// to exit the app outright. That's fine for most apps, but this one holds
/// an in-progress conversation with a companion persona; a single accidental
/// back-tap (very easy on Android's gesture nav, especially swiping from the
/// edge while scrolling a chat) silently kills the app mid-thought with no
/// chance to undo. The confirmation costs one extra tap on the rare
/// intentional exit, and prevents the much worse rare-but-real accidental
/// one.
///
/// Uses PopScope (the modern replacement for the deprecated WillPopScope) --
/// canPop: false means the framework never pops on its own; onPopInvokedWithResult
/// fires on every back-gesture/button attempt so we can show the dialog and
/// exit manually only after the person confirms.
class ExitConfirmationWrapper extends StatelessWidget {
  final Widget child;

  const ExitConfirmationWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final shouldExit = await _showExitDialog(context);
        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      },
      child: child,
    );
  }

  Future<bool?> _showExitDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
                child: const Icon(
                  Icons.waving_hand_rounded,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Leaving already?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                "Your conversations are saved, so everyone here will remember where you left off.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: const BorderSide(color: AppColors.divider),
                        foregroundColor: AppColors.textPrimary,
                      ),
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('Stay'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: const Text('Exit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
