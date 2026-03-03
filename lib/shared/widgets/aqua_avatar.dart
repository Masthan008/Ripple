import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';

/// Circular/rounded avatar with cyan gradient ring border and glow
class AquaAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double size;
  final double ringWidth;
  final bool showOnlineDot;
  final bool isOnline;
  final bool isSquare;

  const AquaAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size = 48,
    this.ringWidth = 2.5,
    this.showOnlineDot = false,
    this.isOnline = false,
    this.isSquare = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = isSquare ? size * 0.28 : size / 2;

    return SizedBox(
      width: size + ringWidth * 2 + 4,
      height: size + ringWidth * 2 + 4,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Gradient ring border
          Container(
            width: size + ringWidth * 2 + 4,
            height: size + ringWidth * 2 + 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius + ringWidth + 2),
              gradient: AppColors.aquaGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.aquaCore.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ],
            ),
          ),
          // Inner background
          Container(
            width: size + 2,
            height: size + 2,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              color: AppColors.abyssBackground,
            ),
          ),
          // Avatar content
          ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius - 1),
            child: SizedBox(
              width: size,
              height: size,
              child: _buildAvatarContent(),
            ),
          ),
          // Online indicator dot
          if (showOnlineDot)
            Positioned(
              bottom: 0,
              right: 0,
              child: _OnlineDotIndicator(
                isOnline: isOnline,
                size: size * 0.28,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarContent() {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => _buildInitialsAvatar(),
        errorWidget: (_, __, ___) => _buildInitialsAvatar(),
      );
    }
    return _buildInitialsAvatar();
  }

  Widget _buildInitialsAvatar() {
    final initials = _getInitials(name ?? '?');
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0C4A6E), Color(0xFF0E7490)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.36,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final words = name.trim().split(' ');
    if (words.isEmpty || words[0].isEmpty) return '?';
    if (words.length == 1) return words[0][0].toUpperCase();
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }
}

/// Small pulsing online/offline dot
class _OnlineDotIndicator extends StatefulWidget {
  final bool isOnline;
  final double size;

  const _OnlineDotIndicator({required this.isOnline, required this.size});

  @override
  State<_OnlineDotIndicator> createState() => _OnlineDotIndicatorState();
}

class _OnlineDotIndicatorState extends State<_OnlineDotIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.isOnline) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_OnlineDotIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOnline && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isOnline && _controller.isAnimating) {
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
      animation: _scaleAnim,
      builder: (_, child) {
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
                      color: AppColors.onlineGreen.withValues(alpha: 0.5 * _scaleAnim.value),
                      blurRadius: 6 * _scaleAnim.value,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }
}
