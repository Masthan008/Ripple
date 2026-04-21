import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../core/constants/app_colors.dart';

/// Dynamic glassmorphism card that responds to touch and background
class DynamicGlassCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double blurRadius;
  final bool enableGlow;

  const DynamicGlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.blurRadius = 20,
    this.enableGlow = true,
  });

  @override
  State<DynamicGlassCard> createState() => _DynamicGlassCardState();
}

class _DynamicGlassCardState extends State<DynamicGlassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  bool _isPressed = false;
  Offset _touchPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.enableGlow) {
      _glowController.repeat();
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        setState(() {
          _isPressed = true;
          _touchPosition = details.localPosition;
        });
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      onPanUpdate: (details) {
        setState(() => _touchPosition = details.localPosition);
      },
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (context, child) {
          final glowPhase = math.sin(_glowController.value * 2 * math.pi);
          final dynamicBlur = _isPressed
              ? widget.blurRadius * 0.5
              : widget.blurRadius + (glowPhase * 2);

          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                if (widget.enableGlow)
                  BoxShadow(
                    color: AppColors.aquaCore.withOpacity(
                        0.1 + (glowPhase * 0.1)),
                    blurRadius: 20 + (glowPhase * 10),
                    spreadRadius: -5,
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: dynamicBlur,
                  sigmaY: dynamicBlur,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(_isPressed ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.aquaCyan.withOpacity(
                          _isPressed ? 0.4 : 0.2 + (glowPhase * 0.1)),
                      width: 1,
                    ),
                  ),
                  child: widget.child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Glass card with shimmer loading effect
class ShimmerGlassCard extends StatefulWidget {
  final Widget child;
  final bool isLoading;

  const ShimmerGlassCard({
    super.key,
    required this.child,
    this.isLoading = false,
  });

  @override
  State<ShimmerGlassCard> createState() => _ShimmerGlassCardState();
}

class _ShimmerGlassCardState extends State<ShimmerGlassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.isLoading) {
      _shimmerController.repeat();
    }
  }

  @override
  void didUpdateWidget(ShimmerGlassCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !_shimmerController.isAnimating) {
      _shimmerController.repeat();
    } else if (!widget.isLoading && _shimmerController.isAnimating) {
      _shimmerController.stop();
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final shimmerValue = _shimmerController.value;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: widget.isLoading
                ? LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.05),
                      Colors.white.withOpacity(0.15),
                      Colors.white.withOpacity(0.05),
                    ],
                    stops: [
                      0.0,
                      0.5 + (math.sin(shimmerValue * 2 * math.pi) * 0.3),
                      1.0,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: widget.isLoading ? null : Colors.white.withOpacity(0.1),
            border: Border.all(
              color: AppColors.glassBorder,
              width: 1,
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}
