import 'package:flutter/material.dart';

import '../theme/side_b_theme.dart';

/// Applies one restrained SIDE B olive light sweep to a complete loading area.
///
/// A screen wraps all of its placeholders once, so its shimmer is synchronized
/// instead of each bar animating independently.
class OliveShimmer extends StatefulWidget {
  const OliveShimmer({super.key, required this.child, this.oliveOpacity = .34});

  final Widget child;
  final double oliveOpacity;

  @override
  State<OliveShimmer> createState() => _OliveShimmerState();
}

class _OliveShimmerState extends State<OliveShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  bool get _reduceMotion =>
      MediaQuery.of(context).disableAnimations || !TickerMode.of(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final position = -1.5 + (_controller.value * 3);
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(position - 1, 0),
            end: Alignment(position + 1, 0),
            colors: [
              Colors.transparent,
              SideBColors.olive.withOpacity(widget.oliveOpacity),
              Colors.transparent,
            ],
            stops: const [.25, .5, .75],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({super.key, this.width, this.height, this.radius = 3});

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: SizedBox(width: width, height: height),
  );
}
