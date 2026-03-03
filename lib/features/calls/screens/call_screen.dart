import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/aqua_avatar.dart';
import '../../../shared/widgets/floating_particles.dart';
import '../../../shared/widgets/water_ripple_painter.dart';

/// Call Screen — PRD §6.4
/// Incoming / outgoing call UI with glass morphism
class CallScreen extends StatelessWidget {
  final String callerName;
  final String? callerPhoto;
  final bool isVideo;
  final bool isIncoming;

  const CallScreen({
    super.key,
    required this.callerName,
    this.callerPhoto,
    this.isVideo = false,
    this.isIncoming = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      body: Stack(
        children: [
          const FloatingParticles(particleCount: 5),

          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.aquaCore.withValues(alpha: 0.08),
                  AppColors.abyssBackground,
                  AppColors.abyssBackground,
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Call type label
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.glassPanel,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Text(
                    isIncoming
                        ? (isVideo ? 'Incoming Video Call' : 'Incoming Call')
                        : (isVideo ? 'Video Calling...' : 'Calling...'),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.aquaCore,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Caller avatar with glow
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.aquaCore.withValues(alpha: 0.25),
                        blurRadius: 50,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: AquaAvatar(
                    imageUrl: callerPhoto,
                    name: callerName,
                    size: 120,
                  ),
                ),

                const SizedBox(height: 24),

                // Caller name
                Text(callerName, style: AppTextStyles.display),
                const SizedBox(height: 8),
                Text(
                  isIncoming ? 'is calling you...' : 'Ringing...',
                  style: AppTextStyles.subtitle,
                ),

                const Spacer(flex: 3),

                // Action buttons
                if (isIncoming) _buildIncomingActions(context),
                if (!isIncoming) _buildOutgoingActions(context),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Decline
        _CallActionButton(
          icon: Icons.call_end_rounded,
          label: 'Decline',
          color: AppColors.errorRed,
          onTap: () => Navigator.of(context).pop(),
        ),
        // Accept
        _CallActionButton(
          icon: isVideo ? Icons.videocam_rounded : Icons.call_rounded,
          label: 'Accept',
          color: AppColors.onlineGreen,
          onTap: () {
            // TODO: Accept call via ZegoCloud
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  Widget _buildOutgoingActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Mute
        _CallActionButton(
          icon: Icons.mic_off_rounded,
          label: 'Mute',
          color: AppColors.textMuted,
          onTap: () {},
          isSmall: true,
        ),
        // End call
        _CallActionButton(
          icon: Icons.call_end_rounded,
          label: 'End',
          color: AppColors.errorRed,
          onTap: () => Navigator.of(context).pop(),
        ),
        // Speaker
        _CallActionButton(
          icon: Icons.volume_up_rounded,
          label: 'Speaker',
          color: AppColors.textMuted,
          onTap: () {},
          isSmall: true,
        ),
      ],
    );
  }
}

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isSmall;

  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = isSmall ? 52.0 : 64.0;
    return WaterRippleEffect(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.2),
              border: Border.all(color: color.withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 15,
                ),
              ],
            ),
            child: Icon(icon, color: color, size: isSmall ? 22 : 28),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontSize: 11,
              )),
        ],
      ),
    );
  }
}
