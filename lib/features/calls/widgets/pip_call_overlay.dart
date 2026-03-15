import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/haptic_feedback.dart';

/// Floating Picture-in-Picture call overlay.
/// Shows a draggable mini pill with call timer + end button over other screens.
class PipCallOverlay extends StatefulWidget {
  final String callerName;
  final bool isVideo;
  final VoidCallback onTapExpand;
  final VoidCallback onEndCall;

  const PipCallOverlay({
    super.key,
    required this.callerName,
    required this.isVideo,
    required this.onTapExpand,
    required this.onEndCall,
  });

  @override
  State<PipCallOverlay> createState() => _PipCallOverlayState();
}

class _PipCallOverlayState extends State<PipCallOverlay>
    with SingleTickerProviderStateMixin {
  Offset _position = const Offset(20, 80);
  Duration _duration = Duration.zero;
  Timer? _timer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _duration += const Duration(seconds: 1));
    });
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position = Offset(
              _position.dx + details.delta.dx,
              _position.dy + details.delta.dy,
            );
          });
        },
        onTap: widget.onTapExpand,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (_, child) {
            final scale = 1.0 + (_pulseController.value * 0.02);
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xE6060D1A),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.aquaCore.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.aquaCore.withValues(alpha: 0.2),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pulsing green dot
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF22C55E),
                  ),
                ),
                const SizedBox(width: 8),

                // Icon
                Icon(
                  widget.isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                  color: AppColors.aquaCore,
                  size: 16,
                ),
                const SizedBox(width: 8),

                // Name + timer
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.callerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: TextStyle(
                        color: AppColors.aquaCyan,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // End call button
                GestureDetector(
                  onTap: () {
                    AppHaptics.mediumTap();
                    widget.onEndCall();
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red,
                    ),
                    child: const Icon(Icons.call_end_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Static manager to show/hide the PiP overlay globally.
class PipManager {
  PipManager._();

  static OverlayEntry? _entry;
  static VoidCallback? _onExpand;
  static VoidCallback? _onEnd;

  /// Show the PiP overlay
  static void show({
    required BuildContext context,
    required String callerName,
    required bool isVideo,
    required VoidCallback onExpand,
    required VoidCallback onEndCall,
  }) {
    dismiss(); // Remove any existing PiP

    _onExpand = onExpand;
    _onEnd = onEndCall;

    _entry = OverlayEntry(
      builder: (_) => PipCallOverlay(
        callerName: callerName,
        isVideo: isVideo,
        onTapExpand: () {
          dismiss();
          _onExpand?.call();
        },
        onEndCall: () {
          dismiss();
          _onEnd?.call();
        },
      ),
    );

    Overlay.of(context).insert(_entry!);
  }

  /// Dismiss the PiP overlay
  static void dismiss() {
    _entry?.remove();
    _entry = null;
    _onExpand = null;
    _onEnd = null;
  }

  /// Check if PiP is currently showing
  static bool get isActive => _entry != null;
}
