import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Dopamine-inducing visual effects for enhanced user engagement
/// Based on 2025 UI trends: micro-interactions, confetti, playful animations
class DopamineEffects {
  
  /// Show confetti burst at specific position
  static void showConfettiBurst(
    BuildContext context, {
    Offset? position,
    int particleCount = 30,
    List<Color>? colors,
    Duration duration = const Duration(milliseconds: 1500),
  }) {
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    final center = position ??
        (renderBox != null
            ? renderBox.localToGlobal(renderBox.size.center(Offset.zero))
            : Offset(MediaQuery.of(context).size.width / 2,
                MediaQuery.of(context).size.height / 2));

    final overlayEntry = OverlayEntry(
      builder: (context) => ConfettiBurstWidget(
        position: center,
        particleCount: particleCount,
        colors: colors ??
            [
              Colors.red,
              Colors.blue,
              Colors.green,
              Colors.yellow,
              Colors.purple,
              Colors.orange,
              Colors.pink,
              Colors.cyan,
            ],
        duration: duration,
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(duration, () => overlayEntry.remove());
  }

  /// Show achievement unlock animation
  static void showAchievementUnlock(
    BuildContext context, {
    required String title,
    required String description,
    IconData icon = Icons.emoji_events,
    Color? accentColor,
    VoidCallback? onDismiss,
  }) {
    final overlay = Overlay.of(context);
    
    final overlayEntry = OverlayEntry(
      builder: (context) => AchievementOverlay(
        title: title,
        description: description,
        icon: icon,
        accentColor: accentColor ?? const Color(0xFFFFD700),
        onDismiss: () {
          onDismiss?.call();
        },
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 3), () {
      overlayEntry.remove();
      onDismiss?.call();
    });
  }

  /// Pulse animation for important actions
  static Widget pulseWrapper({
    required Widget child,
    Duration duration = const Duration(milliseconds: 1000),
    double scale = 1.1,
  }) {
    return _PulseAnimation(
      duration: duration,
      scale: scale,
      child: child,
    );
  }

  /// Glow effect that intensifies on interaction
  static Widget glowButton({
    required Widget child,
    required VoidCallback onTap,
    Color glowColor = Colors.cyan,
    double glowIntensity = 20,
  }) {
    return _GlowButton(
      onTap: onTap,
      glowColor: glowColor,
      glowIntensity: glowIntensity,
      child: child,
    );
  }

  /// Message send animation with dopamine trigger
  static Widget messageSendAnimation({
    required Widget child,
    required VoidCallback onComplete,
    Duration duration = const Duration(milliseconds: 600),
  }) {
    return _MessageSendAnimation(
      duration: duration,
      onComplete: onComplete,
      child: child,
    );
  }

  /// Bouncy scale animation for reactions
  static Widget bouncyReaction({
    required Widget child,
    required VoidCallback onTap,
  }) {
    return _BouncyReaction(onTap: onTap, child: child);
  }

  /// Streak celebration animation
  static void showStreakCelebration(
    BuildContext context, {
    required int streakDays,
    VoidCallback? onComplete,
  }) {
    showAchievementUnlock(
      context,
      title: '$streakDays Day Streak! 🔥',
      description: 'Keep the momentum going!',
      icon: Icons.local_fire_department,
      accentColor: Colors.orange,
      onDismiss: onComplete,
    );
    
    // Add extra confetti for milestones
    if (streakDays % 7 == 0 || streakDays == 30 || streakDays == 100) {
      Future.delayed(const Duration(milliseconds: 300), () {
        showConfettiBurst(
          context,
          particleCount: streakDays >= 30 ? 80 : 50,
          colors: [Colors.orange, Colors.red, Colors.yellow],
        );
      });
    }
  }

  /// New message notification with satisfying pop
  static Widget newMessagePop({
    required Widget child,
    required bool isNew,
  }) {
    return _NewMessagePop(isNew: isNew, child: child);
  }
}

/// Confetti burst overlay widget
class ConfettiBurstWidget extends StatefulWidget {
  final Offset position;
  final int particleCount;
  final List<Color> colors;
  final Duration duration;

  const ConfettiBurstWidget({
    super.key,
    required this.position,
    required this.particleCount,
    required this.colors,
    required this.duration,
  });

  @override
  State<ConfettiBurstWidget> createState() => _ConfettiBurstWidgetState();
}

class _ConfettiBurstWidgetState extends State<ConfettiBurstWidget>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;
  late List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    
    _controllers = [];
    _animations = [];
    _particles = [];

    final random = math.Random();
    
    for (int i = 0; i < widget.particleCount; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: widget.duration,
      );
      
      final animation = CurvedAnimation(
        parent: controller,
        curve: Curves.easeOut,
      );

      _particles.add(_Particle(
        color: widget.colors[random.nextInt(widget.colors.length)],
        angle: (random.nextDouble() * 2 * math.pi),
        velocity: 100 + random.nextDouble() * 200,
        size: 8 + random.nextDouble() * 12,
        rotation: random.nextDouble() * 2 * math.pi,
      ));

      _controllers.add(controller);
      _animations.add(animation);
      controller.forward();
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(widget.particleCount, (index) {
        return AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            final progress = _animations[index].value;
            final particle = _particles[index];
            
            final dx = math.cos(particle.angle) * particle.velocity * progress;
            final dy = math.sin(particle.angle) * particle.velocity * progress + 
                       200 * progress * progress; // gravity
            
            final opacity = 1 - progress;
            final scale = 1 - progress * 0.5;

            return Positioned(
              left: widget.position.dx + dx - particle.size / 2,
              top: widget.position.dy + dy - particle.size / 2,
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: Transform.rotate(
                    angle: particle.rotation + progress * 4 * math.pi,
                    child: Container(
                      width: particle.size,
                      height: particle.size,
                      decoration: BoxDecoration(
                        color: particle.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

class _Particle {
  final Color color;
  final double angle;
  final double velocity;
  final double size;
  final double rotation;

  _Particle({
    required this.color,
    required this.angle,
    required this.velocity,
    required this.size,
    required this.rotation,
  });
}

/// Achievement unlock overlay
class AchievementOverlay extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onDismiss;

  const AchievementOverlay({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.onDismiss,
  });

  @override
  State<AchievementOverlay> createState() => _AchievementOverlayState();
}

class _AchievementOverlayState extends State<AchievementOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
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
    return GestureDetector(
      onTap: widget.onDismiss,
      child: Container(
        color: Colors.black54,
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: child,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.accentColor.withOpacity(0.2),
                    Colors.black.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: widget.accentColor.withOpacity(0.5), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: widget.accentColor.withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: widget.accentColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.icon,
                      size: 48,
                      color: widget.accentColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pulse animation wrapper
class _PulseAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double scale;

  const _PulseAnimation({
    required this.child,
    required this.duration,
    required this.scale,
  });

  @override
  State<_PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<_PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);
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
      builder: (context, child) => Transform.scale(
        scale: 1 + (_controller.value * (widget.scale - 1)),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Glow button with animated glow effect
class _GlowButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color glowColor;
  final double glowIntensity;

  const _GlowButton({
    required this.child,
    required this.onTap,
    required this.glowColor,
    required this.glowIntensity,
  });

  @override
  State<_GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<_GlowButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: widget.glowColor.withOpacity(_isPressed ? 0.8 : 0.4),
              blurRadius: _isPressed ? widget.glowIntensity * 2 : widget.glowIntensity,
              spreadRadius: _isPressed ? 4 : 2,
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

/// Message send animation with scale + slide
class _MessageSendAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final VoidCallback onComplete;

  const _MessageSendAnimation({
    required this.child,
    required this.duration,
    required this.onComplete,
  });

  @override
  State<_MessageSendAnimation> createState() => _MessageSendAnimationState();
}

class _MessageSendAnimationState extends State<_MessageSendAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward().then((_) => widget.onComplete());
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
      builder: (context, child) => FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: child,
          ),
        ),
      ),
      child: widget.child,
    );
  }
}

/// Bouncy reaction button
class _BouncyReaction extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _BouncyReaction({required this.onTap, required this.child});

  @override
  State<_BouncyReaction> createState() => _BouncyReactionState();
}

class _BouncyReactionState extends State<_BouncyReaction>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animate() {
    _controller.forward(from: 0).then((_) => widget.onTap());
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _animate,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final value = _controller.value;
          final scale = 1 + math.sin(value * math.pi * 2) * 0.3 * (1 - value);
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// New message pop animation
class _NewMessagePop extends StatefulWidget {
  final Widget child;
  final bool isNew;

  const _NewMessagePop({required this.isNew, required this.child});

  @override
  State<_NewMessagePop> createState() => _NewMessagePopState();
}

class _NewMessagePopState extends State<_NewMessagePop>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    if (widget.isNew) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _NewMessagePop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isNew && !oldWidget.isNew) {
      _controller.forward(from: 0);
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
        final scale = 1 + math.sin(_controller.value * math.pi) * 0.1;
        return Transform.scale(
          scale: scale,
          child: widget.child,
        );
      },
    );
  }
}
