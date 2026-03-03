import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Standalone pulsing online status dot
class OnlineDot extends StatefulWidget {
  final bool isOnline;
  final double size;

  const OnlineDot({
    super.key,
    required this.isOnline,
    this.size = 12,
  });

  @override
  State<OnlineDot> createState() => _OnlineDotState();
}

class _OnlineDotState extends State<OnlineDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isOnline) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(OnlineDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOnline && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isOnline) {
      _controller.stop();
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
      builder: (_, __) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isOnline
                ? AppColors.onlineGreen
                : AppColors.offlineGray,
            border: Border.all(
              color: AppColors.abyssBackground,
              width: 2,
            ),
            boxShadow: widget.isOnline
                ? [
                    BoxShadow(
                      color: AppColors.onlineGreen.withValues(
                        alpha: 0.4 + (_controller.value * 0.3),
                      ),
                      blurRadius: 4 + (_controller.value * 4),
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }
}
