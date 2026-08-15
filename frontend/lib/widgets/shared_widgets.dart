import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ShimmerPlaceholder extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final Axis direction;

  const ShimmerPlaceholder({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
    this.direction = Axis.horizontal,
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
    final baseColor =
        isDark ? AppColorsDark.surfaceAlt : AppColors.surfaceAlt;
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
            final progress = _animation.value;
            final dx = (progress + 1) * bounds.width / 2;
            return LinearGradient(
              begin: Alignment(-1.0, 0.0),
              end: Alignment(1.0, 0.0),
              colors: [baseColor, highlightColor, baseColor],
              tileMode: TileMode.clamp,
              stops: const [0.0, 0.5, 1.0],
            ).createShader(
              Rect.fromLTWH(dx - bounds.width / 2, 0, bounds.width, bounds.height),
            );
          },
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: isDark ? AppColorsDark.surfaceAlt : AppColors.surfaceAlt,
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

class AnimatedPressButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;
  final double scale;
  final Duration duration;
  final bool enabled;

  const AnimatedPressButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.scale = 0.94,
    this.duration = const Duration(milliseconds: 100),
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
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _scaleAnim =
        Tween<double>(begin: 1.0, end: widget.scale).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown() => _controller.forward();
  void _onTapUp() {
    _controller.reverse();
    if (widget.enabled) {
      widget.onPressed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => _onTapDown() : null,
      onTapUp: widget.enabled
          ? (_) {
              _onTapUp();
            }
          : null,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: widget.child,
      ),
    );
  }
}

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
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      width: count > 9 ? null : size,
      height: size,
      padding: EdgeInsets.symmetric(
        horizontal: count > 9 ? 6 : 0,
        vertical: 2,
      ),
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

class PulseDot extends StatefulWidget {
  final Color color;
  final double size;

  const PulseDot({
    super.key,
    required this.color,
    this.size = 8,
  });

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
    ]).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 1),
    ]).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

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
  Widget build(BuildContext context) {
    return child;
  }
}
