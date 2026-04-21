import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Enhanced shimmer skeleton with glassmorphism effect
class ShimmerSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final bool isCircle;
  final EdgeInsets margin;
  final Widget? child;

  const ShimmerSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
    this.isCircle = false,
    this.margin = EdgeInsets.zero,
    this.child,
  });

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _shimmerAnim = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerAnim,
      builder: (context, child) {
        return Container(
          margin: widget.margin,
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: widget.isCircle ? null : BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_shimmerAnim.value - 1, 0),
              end: Alignment(_shimmerAnim.value, 0),
              colors: [
                Colors.white.withOpacity(0.03),
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0.03),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            border: Border.all(
              color: AppColors.glassBorder.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// Chat list shimmer skeleton
class ChatListSkeleton extends StatelessWidget {
  final int itemCount;

  const ChatListSkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Avatar skeleton
              const ShimmerSkeleton(
                width: 56,
                height: 56,
                isCircle: true,
              ),
              const SizedBox(width: 12),
              // Text skeletons
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ShimmerSkeleton(
                            width: 150,
                            height: 16,
                            borderRadius: 4,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ShimmerSkeleton(
                          width: 40,
                          height: 12,
                          borderRadius: 4,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ShimmerSkeleton(
                      width: double.infinity,
                      height: 14,
                      borderRadius: 4,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Message bubble shimmer
class MessageBubbleSkeleton extends StatelessWidget {
  final bool isMe;

  const MessageBubbleSkeleton({super.key, this.isMe = false});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: isMe ? 60 : 12,
          right: isMe ? 12 : 60,
          bottom: 6,
        ),
        child: ShimmerSkeleton(
          width: isMe ? 200 : 180,
          height: 60,
          borderRadius: 16,
        ),
      ),
    );
  }
}

/// Profile card shimmer
class ProfileCardSkeleton extends StatelessWidget {
  const ProfileCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const ShimmerSkeleton(
          width: 120,
          height: 120,
          isCircle: true,
        ),
        const SizedBox(height: 16),
        ShimmerSkeleton(
          width: 200,
          height: 24,
          borderRadius: 8,
        ),
        const SizedBox(height: 8),
        ShimmerSkeleton(
          width: 150,
          height: 16,
          borderRadius: 4,
        ),
      ],
    );
  }
}

/// Status ring shimmer
class StatusRingSkeleton extends StatelessWidget {
  final int count;

  const StatusRingSkeleton({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: count,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ShimmerSkeleton(
                  width: 64,
                  height: 64,
                  isCircle: true,
                ),
                const SizedBox(height: 6),
                ShimmerSkeleton(
                  width: 50,
                  height: 12,
                  borderRadius: 4,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Glass card shimmer with border glow effect
class GlassCardSkeleton extends StatefulWidget {
  final double width;
  final double height;

  const GlassCardSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 120,
  });

  @override
  State<GlassCardSkeleton> createState() => _GlassCardSkeletonState();
}

class _GlassCardSkeletonState extends State<GlassCardSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _glowAnim = Tween<double>(begin: 0.1, end: 0.3).animate(
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
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.aquaCore.withOpacity(_glowAnim.value),
              width: 1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.05),
                Colors.white.withOpacity(0.02),
              ],
            ),
          ),
          child: const ShimmerSkeleton(),
        );
      },
    );
  }
}
