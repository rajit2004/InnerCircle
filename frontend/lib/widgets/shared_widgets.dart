import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';

// ── Shimmer Loading ──────────────────────────────────────────────────────

class ShimmerPlaceholder extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerPlaceholder({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? AppColorsDark.surfaceAlt : AppColors.surfaceAlt;
    final highlightColor = isDark
        ? AppColorsDark.surface.withValues(alpha: 0.6)
        : AppColors.surface.withValues(alpha: 0.9);
    final borderRadius = widget.borderRadius ?? BorderRadius.circular(8);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final dx = (_animation.value + 1) * bounds.width / 2;
            return LinearGradient(
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(
              Rect.fromLTWH(
                  dx - bounds.width / 2, 0, bounds.width, bounds.height),
            );
          },
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: borderRadius,
            ),
          ),
        );
      },
    );
  }
}

class ShimmerList extends StatelessWidget {
  final int itemCount;
  final double height;
  final double spacing;
  final double borderRadius;

  const ShimmerList({
    super.key,
    this.itemCount = 3,
    this.height = 80,
    this.spacing = 12,
    this.borderRadius = 18,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.symmetric(vertical: spacing),
      itemCount: itemCount,
      separatorBuilder: (_, _) => SizedBox(height: spacing),
      itemBuilder: (context, index) {
        return ShimmerPlaceholder(
          width: double.infinity,
          height: height,
          borderRadius: BorderRadius.circular(borderRadius),
        );
      },
    );
  }
}

/// Shimmer placeholder that mimics chat message bubbles — alternating
/// left/right aligned rounded rectangles of varying widths.
class ChatShimmer extends StatelessWidget {
  const ChatShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: 6,
      itemBuilder: (context, index) {
        final isUser = index % 3 == 0;
        final width = isUser
            ? MediaQuery.sizeOf(context).width * 0.55
            : MediaQuery.sizeOf(context).width * 0.4;
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: ShimmerPlaceholder(
            width: width,
            height: 48,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isUser ? 18 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 18),
            ),
          ),
        );
      },
    );
  }
}

// ── Animated Button ──────────────────────────────────────────────────────

class AnimatedPressButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;
  final double scale;
  final bool enabled;

  const AnimatedPressButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.scale = 0.94,
    this.enabled = true,
  });

  @override
  State<AnimatedPressButton> createState() => _AnimatedPressButtonState();
}

class _AnimatedPressButtonState extends State<AnimatedPressButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.micro);
    _scaleAnim = Tween<double>(begin: 1.0, end: widget.scale).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => _controller.forward() : null,
      onTapUp: widget.enabled
          ? (_) {
              _controller.reverse();
              widget.onPressed();
            }
          : null,
      onTapCancel: widget.enabled ? () => _controller.reverse() : null,
      child: ScaleTransition(scale: _scaleAnim, child: widget.child),
    );
  }
}

// ── Badge ────────────────────────────────────────────────────────────────

class StatusBadge extends StatelessWidget {
  final int count;
  final Color? color;
  final bool showZero;
  final double size;

  const StatusBadge({
    super.key,
    required this.count,
    this.color,
    this.showZero = false,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    if (!showZero && count <= 0) return const SizedBox.shrink();
    final badgeColor = color ?? AppColors.error;
    final displayCount = count > 99 ? '99+' : count.toString();

    return AnimatedContainer(
      duration: AppMotion.micro,
      curve: Curves.easeOut,
      width: count > 9 ? null : size,
      height: size,
      padding: EdgeInsets.symmetric(horizontal: count > 9 ? 6 : 0, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor,
        shape: count > 9 ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: count > 9 ? BorderRadius.circular(size / 2) : null,
        border: Border.all(
          color: Theme.of(context).colorScheme.surface,
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          displayCount,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}

// ── Pulse Dot ────────────────────────────────────────────────────────────

class PulseDot extends StatefulWidget {
  final Color color;
  final double size;

  const PulseDot({super.key, required this.color, this.size = 8});

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.7, end: 1.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.7), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: FadeTransition(
        opacity: _opacity,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

// ── Gradient Chip ────────────────────────────────────────────────────────

class GradientChip extends StatelessWidget {
  final String label;
  final List<Color> colors;
  final IconData? icon;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const GradientChip({
    super.key,
    required this.label,
    this.colors = const [AppColors.primary, AppColors.primaryDark],
    this.icon,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon!, size: fontSize + 2, color: Colors.white70),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Page Transition ──────────────────────────────────────────────────────

class PageTransition extends StatelessWidget {
  final Widget child;
  final Duration duration;

  const PageTransition({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 240),
  });

  static Future<T?> push<T>(
    BuildContext context,
    Widget page, {
    Duration duration = const Duration(milliseconds: 240),
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: duration,
        reverseTransitionDuration: duration,
        pageBuilder: (_, animation, _) => page,
        transitionsBuilder: (context, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => child;
}

// ── Staggered Animation Wrapper ──────────────────────────────────────────

/// Wraps a child with a staggered slide-up + fade entrance animation.
/// Use in ListView.builder itemBuilder to animate each item with increasing delay.
class StaggeredEntrance extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration duration;
  final Duration staggerDelay;

  const StaggeredEntrance({
    super.key,
    required this.child,
    required this.index,
    this.duration = AppMotion.meso,
    this.staggerDelay = AppMotion.staggerDelay,
  });

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    final delay =
        (widget.index * widget.staggerDelay.inMilliseconds / 1000.0)
            .clamp(0.0, 0.6);
    final end = (delay + 0.5).clamp(0.0, 1.0);

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Interval(delay, end, curve: Curves.easeOutCubic),
    ));

    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(delay, (delay + 0.4).clamp(0.0, 1.0),
            curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(opacity: _fade, child: widget.child),
    );
  }
}
