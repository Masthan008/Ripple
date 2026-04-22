import 'package:flutter/material.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/haptic_feedback.dart';
import 'dart:ui';

/// A widget that displays text with a high-intensity "Impact" aesthetic.
/// It triggers a heavy haptic feedback when tapped or when it first appears
/// (optional, but tap is safer to avoid spam).
class ImpactText extends StatefulWidget {
  final String text;
  final double fontSize;

  const ImpactText({super.key, required this.text, required this.fontSize});

  @override
  State<ImpactText> createState() => _ImpactTextState();
}

class _ImpactTextState extends State<ImpactText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    
    // Play an intro animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.forward().then((_) => _controller.reverse());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerImpact() {
    AppHaptics.heavyTap();
    _controller.forward().then((_) => _controller.reverse());
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _triggerImpact,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Text(
          widget.text,
          style: AppTextStyles.chatBubble.copyWith(
            color: Colors.white,
            fontSize: widget.fontSize * 1.15, // Slightly larger
            fontWeight: FontWeight.w900, // Black weight
            letterSpacing: 1.2,
            fontStyle: FontStyle.italic,
            shadows: [
              BoxShadow(
                color: Colors.redAccent.withOpacity(0.5),
                blurRadius: 10,
                spreadRadius: 2,
              ),
              const BoxShadow(
                color: Colors.orangeAccent,
                blurRadius: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
