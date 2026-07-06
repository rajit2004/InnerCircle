import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Renders a persona's avatar as a soft gradient circle with an icon,
/// instead of the raw `avatarEmoji` string the backend sends.
///
/// This is a deliberate choice, not just decoration. Two real problems with
/// rendering `persona.avatarEmoji` directly as text:
///
/// 1. Encoding fragility: multi-codepoint emoji (like the "👩‍👧" family emoji
///    the seed data uses for Mom) depend on the full round trip -- server
///    charset headers, the HTTP client's decoding, and the device's emoji
///    font -- all agreeing. Any one link in that chain being slightly off
///    turns it into mojibake (this is exactly what happened before the
///    UTF-8 decode fix in api_client.dart). A vector icon has none of these
///    failure modes.
/// 2. Visual consistency: emoji rendering varies by OS/manufacturer skin
///    (Xiaomi's MIUI emoji set looks different from stock Android, which
///    looks different from iOS) -- so the exact same persona can look
///    noticeably different across devices. An icon we draw ourselves looks
///    identical everywhere and can carry the brand's color language.
class PersonaAvatar extends StatelessWidget {
  final String personaName;
  final double size;

  const PersonaAvatar({super.key, required this.personaName, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final gradientColors = AppColors.personaGradient(personaName);
    final icon = AppColors.personaIcon(personaName);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.last.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.48),
    );
  }
}
