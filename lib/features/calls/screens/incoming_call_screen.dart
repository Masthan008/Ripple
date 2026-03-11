import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/utils/env.dart';
import '../../../shared/widgets/aqua_avatar.dart';
import 'daily_call_screen.dart';

/// Incoming call screen — shown when a call notification is received.
/// Shows caller info, ringing UI, Accept/Decline buttons.
/// On accept → joins the Daily.co room via DailyCallScreen.
/// Auto-declines after 30 seconds.
class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final String channelName;
  final String callerName;
  final String callerUserId;
  final bool isVideo;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.channelName,
    required this.callerName,
    required this.callerUserId,
    this.isVideo = false,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _timeoutTimer;
  StreamSubscription? _callStatusSub;
  bool _answered = false;

  @override
  void initState() {
    super.initState();

    // Pulse animation for the avatar glow
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Auto-decline after 30 seconds
    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (!_answered && mounted) {
        _declineCall();
      }
    });

    // Listen for caller cancelling (status → 'ended' or 'cancelled')
    _callStatusSub = FirebaseService.firestore
        .collection('calls')
        .doc(widget.callId)
        .snapshots()
        .listen((doc) {
      if (!doc.exists) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      final status = doc.data()?['status'] as String? ?? '';
      if (status == 'ended' || status == 'cancelled' || status == 'missed') {
        if (mounted && !_answered) Navigator.of(context).pop();
      }
    });

    // Vibrate to alert user
    HapticFeedback.heavyImpact();
  }

  Future<void> _acceptCall() async {
    if (_answered) return;
    setState(() => _answered = true);
    _timeoutTimer?.cancel();
    _callStatusSub?.cancel();

    // Update call status to 'accepted'
    try {
      await FirebaseService.firestore
          .collection('calls')
          .doc(widget.callId)
          .update({'status': 'accepted'});
    } catch (_) {}

    final currentUser = FirebaseAuth.instance.currentUser;
    if (mounted) {
      // Replace this screen with DailyCallScreen
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => DailyCallScreen(
          callId: widget.callId,
          channelName: widget.channelName,
          currentUserId: currentUser?.uid ?? '',
          currentUserName: currentUser?.displayName ?? 'Me',
          otherUserName: widget.callerName,
          otherUserId: widget.callerUserId,
          isVideo: widget.isVideo,
          isGroup: false,
        ),
      ));
    }
  }

  Future<void> _declineCall() async {
    if (_answered) return;
    _timeoutTimer?.cancel();
    _callStatusSub?.cancel();

    try {
      await FirebaseService.firestore
          .collection('calls')
          .doc(widget.callId)
          .update({
        'status': 'declined',
        'endedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      body: Stack(
        children: [
          // Gradient background
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Text(
                    widget.isVideo
                        ? 'Incoming Video Call'
                        : 'Incoming Voice Call',
                    style: TextStyle(
                      color: AppColors.aquaCore,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Caller avatar with pulse glow
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, child) => Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.aquaCore.withValues(
                              alpha: 0.1 + 0.2 * _pulseController.value),
                          blurRadius: 30 + 20 * _pulseController.value,
                          spreadRadius: 5 + 10 * _pulseController.value,
                        ),
                      ],
                    ),
                    child: child,
                  ),
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: AppColors.aquaCore,
                    child: Text(
                      widget.callerName.isNotEmpty
                          ? widget.callerName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 48,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Caller name
                Text(
                  widget.callerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'is calling you...',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 16,
                  ),
                ),

                const Spacer(flex: 3),

                // Accept / Decline buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Decline
                      _CallActionButton(
                        icon: Icons.call_end_rounded,
                        label: 'Decline',
                        color: const Color(0xFFEF4444),
                        onTap: _declineCall,
                      ),
                      // Accept
                      _CallActionButton(
                        icon: widget.isVideo
                            ? Icons.videocam_rounded
                            : Icons.call_rounded,
                        label: 'Accept',
                        color: const Color(0xFF10B981),
                        onTap: _acceptCall,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timeoutTimer?.cancel();
    _callStatusSub?.cancel();
    super.dispose();
  }
}

// ─── Call Action Button ─────────────────────────────────

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.2),
              border: Border.all(color: color.withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
