import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/utils/animations.dart';
import '../../core/utils/haptic_feedback.dart';

/// Enhanced glassmorphism button with spring animations — theme-aware
class GlassButton extends ConsumerStatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool isPrimary;
  final bool isLoading;
  final double height;
  final EdgeInsets padding;
  final double borderRadius;
  final bool hasGlow;

  const GlassButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.isPrimary = true,
    this.isLoading = false,
    this.height = 56,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
    this.borderRadius = 16,
    this.hasGlow = true,
  });

  @override
  ConsumerState<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends ConsumerState<GlassButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimations.fast,
    );

    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _glowAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap == null || widget.isLoading) return;
    _controller.forward();
    AppHaptics.lightTap();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  void _onTap() {
    if (widget.onTap == null || widget.isLoading) return;
    AppHaptics.mediumTap();
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(rippleThemeProvider);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnim.value,
          child: GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            onTap: _onTap,
            child: Container(
              height: widget.height,
              padding: widget.padding,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                gradient: widget.isPrimary
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colors.primary.withOpacity(0.8),
                          theme.colors.secondary.withOpacity(0.6),
                        ],
                      )
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colors.glassSurface,
                          theme.colors.glassSurface.withOpacity(0.5),
                        ],
                      ),
                border: Border.all(
                  color: widget.isPrimary
                      ? theme.colors.primary.withOpacity(
                          0.5 + (_glowAnim.value * 0.3))
                      : theme.colors.glassBorder.withOpacity(
                          0.5 + (_glowAnim.value * 0.3)),
                  width: 1.5,
                ),
                boxShadow: widget.hasGlow && widget.isPrimary
                    ? [
                        BoxShadow(
                          color: theme.colors.primary.withOpacity(
                              0.3 * _glowAnim.value),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Center(
                    child: widget.isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                theme.colors.textPrimary,
                              ),
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.icon != null) ...[
                                Icon(
                                  widget.icon,
                                  color: theme.colors.textPrimary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                widget.label,
                                style: TextStyle(
                                  color: widget.isPrimary
                                      ? Colors.white
                                      : theme.colors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Icon button with glassmorphism and press animation — theme-aware
class GlassIconButton extends ConsumerStatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? iconColor;
  final bool hasBackground;

  const GlassIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 48,
    this.iconColor,
    this.hasBackground = true,
  });

  @override
  ConsumerState<GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends ConsumerState<GlassIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimations.micro,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.85).animate(
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
    final theme = ref.watch(rippleThemeProvider);

    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnim.value,
          child: GestureDetector(
            onTapDown: (_) {
              if (widget.onTap != null) {
                _controller.forward();
                AppHaptics.lightTap();
              }
            },
            onTapUp: (_) {
              _controller.reverse();
              widget.onTap?.call();
            },
            onTapCancel: () => _controller.reverse(),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: widget.hasBackground
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colors.glassSurface,
                      border: Border.all(
                        color: theme.colors.glassBorder,
                        width: 1,
                      ),
                    )
                  : null,
              child: Center(
                child: Icon(
                  widget.icon,
                  color: widget.iconColor ?? theme.colors.textPrimary,
                  size: widget.size * 0.5,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Floating action button with bioluminescent glow — theme-aware
class GlowFAB extends ConsumerStatefulWidget {
  final VoidCallback onTap;
  final IconData icon;
  final Color? glowColor;

  const GlowFAB({
    super.key,
    required this.onTap,
    required this.icon,
    this.glowColor,
  });

  @override
  ConsumerState<GlowFAB> createState() => _GlowFABState();
}

class _GlowFABState extends ConsumerState<GlowFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnim;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _glowAnim = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.05).animate(
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
    final theme = ref.watch(rippleThemeProvider);
    final effectiveGlowColor = widget.glowColor ?? theme.colors.primary;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnim.value,
          child: GestureDetector(
            onTap: () {
              AppHaptics.mediumTap();
              widget.onTap();
            },
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    effectiveGlowColor,
                    effectiveGlowColor.withOpacity(0.7),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: effectiveGlowColor.withOpacity(_glowAnim.value),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                widget.icon,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        );
      },
    );
  }
}
