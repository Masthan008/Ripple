import 'package:flutter/material.dart';

/// Enhanced animation curves and utilities for Ripple UI/UX
class AppAnimations {
  AppAnimations._();

  // ═══════════════════════════════════════════════════════════════════
  // SPRING PHYSICS CURVES
  // ═══════════════════════════════════════════════════════════════════
  
  /// Elastic spring for bouncy effects (message bubbles, cards)
  static const Curve elasticSpring = Curves.elasticOut;
  
  /// Smooth spring for subtle bounce (buttons, toggles)
  static const Curve smoothSpring = Curves.easeOutBack;
  
  /// Snappy spring for quick responses (switches, selections)
  static const Curve snappySpring = Curves.fastOutSlowIn;
  
  /// Liquid spring for fluid motion (pull-to-refresh, waves)
  static const Curve liquidSpring = Curves.easeInOutCubic;
  
  // ═══════════════════════════════════════════════════════════════════
  // DURATION CONSTANTS
  // ═══════════════════════════════════════════════════════════════════
  
  static const Duration micro = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration dramatic = Duration(milliseconds: 800);
  
  // ═══════════════════════════════════════════════════════════════════
  // PAGE TRANSITION BUILDERS
  // ═══════════════════════════════════════════════════════════════════
  
  /// Slide from right with spring
  static Widget slideFromRight(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: animation.drive(
        Tween(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: smoothSpring)),
      ),
      child: child,
    );
  }
  
  /// Slide from bottom with spring
  static Widget slideFromBottom(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: animation.drive(
        Tween(
          begin: const Offset(0.0, 1.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: smoothSpring)),
      ),
      child: child,
    );
  }
  
  /// Fade with scale (dialogs, overlays)
  static Widget fadeScale(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: elasticSpring),
        ),
        child: child,
      ),
    );
  }
  
  /// Ripple scale (hero-like effect)
  static Widget rippleScale(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: animation, curve: elasticSpring),
      ),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // STAGGERED ANIMATION HELPERS
  // ═══════════════════════════════════════════════════════════════════
  
  /// Create staggered animation for list items
  static Animation<double> staggered(
    AnimationController controller,
    int index,
    int totalItems, {
    Duration delay = const Duration(milliseconds: 50),
  }) {
    final start = index * delay.inMilliseconds / controller.duration!.inMilliseconds;
    final end = start + 0.5;
    
    return CurvedAnimation(
      parent: controller,
      curve: Interval(
        start.clamp(0.0, 1.0),
        end.clamp(0.0, 1.0),
        curve: smoothSpring,
      ),
    );
  }
  
  // ═══════════════════════════════════════════════════════════════════
  // MICRO-INTERACTIONS
  // ═══════════════════════════════════════════════════════════════════
  
  /// Pulse animation for attention
  static Animation<double> pulse(AnimationController controller) {
    return Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: controller,
        curve: Curves.easeInOut,
      ),
    );
  }
  
  /// Gentle breathe animation for idle state
  static Animation<double> breathe(AnimationController controller) {
    return Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: Curves.easeInOutSine,
      ),
    );
  }
}

/// Enhanced AnimatedBuilder with spring physics
class SpringAnimatedBuilder extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final double beginScale;
  final double endScale;
  final double beginOpacity;
  final double endOpacity;
  final Offset? beginOffset;
  final VoidCallback? onComplete;
  final bool autoPlay;

  const SpringAnimatedBuilder({
    super.key,
    required this.child,
    this.duration = AppAnimations.normal,
    this.curve = AppAnimations.elasticSpring,
    this.beginScale = 0.8,
    this.endScale = 1.0,
    this.beginOpacity = 0.0,
    this.endOpacity = 1.0,
    this.beginOffset,
    this.onComplete,
    this.autoPlay = true,
  });

  @override
  State<SpringAnimatedBuilder> createState() => _SpringAnimatedBuilderState();
}

class _SpringAnimatedBuilderState extends State<SpringAnimatedBuilder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;
  late Animation<Offset> _offsetAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _scaleAnim = Tween<double>(
      begin: widget.beginScale,
      end: widget.endScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    _opacityAnim = Tween<double>(
      begin: widget.beginOpacity,
      end: widget.endOpacity,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _offsetAnim = Tween<Offset>(
      begin: widget.beginOffset ?? Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    if (widget.autoPlay) {
      _controller.forward().then((_) => widget.onComplete?.call());
    }
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
        return Transform.scale(
          scale: _scaleAnim.value,
          child: Transform.translate(
            offset: _offsetAnim.value,
            child: Opacity(
              opacity: _opacityAnim.value,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Animated press effect for buttons
class AnimatedPressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Duration duration;
  final double pressedScale;

  const AnimatedPressButton({
    super.key,
    required this.child,
    required this.onTap,
    this.duration = AppAnimations.fast,
    this.pressedScale = 0.95,
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
    _scaleAnim = Tween<double>(begin: 1.0, end: widget.pressedScale).animate(
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
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
