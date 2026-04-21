import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/animations.dart';

/// Custom page transitions for GoRouter
class PageTransitions {
  PageTransitions._();

  /// Spring slide from right (standard push)
  static CustomTransitionPage springSlideRight({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage(
      key: key,
      child: child,
      transitionsBuilder: AppAnimations.slideFromRight,
    );
  }

  /// Spring slide from bottom (modal style)
  static CustomTransitionPage springSlideBottom({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage(
      key: key,
      child: child,
      transitionsBuilder: AppAnimations.slideFromBottom,
    );
  }

  /// Fade with scale (dialogs, overlays)
  static CustomTransitionPage fadeScale({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage(
      key: key,
      child: child,
      transitionsBuilder: AppAnimations.fadeScale,
    );
  }

  /// Ripple scale (hero-like effect)
  static CustomTransitionPage rippleScale({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage(
      key: key,
      child: child,
      transitionsBuilder: AppAnimations.rippleScale,
    );
  }
}

/// Animated page wrapper with entrance animation
class AnimatedPageWrapper extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const AnimatedPageWrapper({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  @override
  State<AnimatedPageWrapper> createState() => _AnimatedPageWrapperState();
}

class _AnimatedPageWrapperState extends State<AnimatedPageWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnim = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.7, curve: AppAnimations.smoothSpring),
      ),
    );

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnim.value,
          child: Transform.translate(
            offset: Offset(0, _slideAnim.value),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Staggered list animation wrapper
class StaggeredListWrapper extends StatefulWidget {
  final List<Widget> children;
  final Duration staggerDelay;
  final Axis direction;

  const StaggeredListWrapper({
    super.key,
    required this.children,
    this.staggerDelay = const Duration(milliseconds: 50),
    this.direction = Axis.vertical,
  });

  @override
  State<StaggeredListWrapper> createState() => _StaggeredListWrapperState();
}

class _StaggeredListWrapperState extends State<StaggeredListWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: 300 + (widget.children.length * widget.staggerDelay.inMilliseconds),
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
    return widget.direction == Axis.vertical
        ? Column(
            children: List.generate(
              widget.children.length,
              (index) => _buildAnimatedItem(index),
            ),
          )
        : Row(
            children: List.generate(
              widget.children.length,
              (index) => _buildAnimatedItem(index),
            ),
          );
  }

  Widget _buildAnimatedItem(int index) {
    final animation = AppAnimations.staggered(
      _controller,
      index,
      widget.children.length,
      delay: widget.staggerDelay,
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            widget.direction == Axis.horizontal ? (1 - animation.value) * 30 : 0,
            widget.direction == Axis.vertical ? (1 - animation.value) * 30 : 0,
          ),
          child: Opacity(
            opacity: animation.value,
            child: child,
          ),
        );
      },
      child: widget.children[index],
    );
  }
}

/// Hero-style shared element transition wrapper
class SharedElementTransition extends StatelessWidget {
  final String tag;
  final Widget child;
  final VoidCallback? onTap;

  const SharedElementTransition({
    super.key,
    required this.tag,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Hero(
        tag: tag,
        transitionOnUserGestures: true,
        flightShuttleBuilder: (
          flightContext,
          animation,
          flightDirection,
          fromHeroContext,
          toHeroContext,
        ) {
          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    Tween<double>(begin: 12, end: 0).evaluate(animation),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(
                        Tween<double>(begin: 0.3, end: 0.5).evaluate(animation),
                      ),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: toHeroContext.widget,
              );
            },
          );
        },
        child: Material(
          color: Colors.transparent,
          child: child,
        ),
      ),
    );
  }
}

/// Parallax scroll effect widget
class ParallaxScrollEffect extends StatelessWidget {
  final ScrollController scrollController;
  final Widget child;
  final double parallaxFactor;

  const ParallaxScrollEffect({
    super.key,
    required this.scrollController,
    required this.child,
    this.parallaxFactor = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scrollController,
      builder: (context, child) {
        final offset = scrollController.hasClients
            ? scrollController.position.pixels * parallaxFactor
            : 0.0;
        return Transform.translate(
          offset: Offset(0, -offset),
          child: child,
        );
      },
      child: child,
    );
  }
}
