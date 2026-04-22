import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/chronos_unlock_service.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../models/message_model.dart';

/// Chronos Locked Bubble — Contextual Time-Capsules™
///
/// Displays a mysterious, glowing orb in place of a locked message.
/// The orb shows the unlock condition type (icon + hint) and animates
/// with a slow pulsing glow. When the condition is met, the orb
/// shatters into particles and reveals the actual message.
///
/// For 'shake' conditions, listens to the accelerometer directly.
class ChronosLockedBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMe;
  final String chatId;
  final bool isGroup;

  const ChronosLockedBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.chatId,
    this.isGroup = false,
  });

  @override
  State<ChronosLockedBubble> createState() => _ChronosLockedBubbleState();
}

class _ChronosLockedBubbleState extends State<ChronosLockedBubble>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _orbRotationController;
  late AnimationController _unlockController;

  StreamSubscription? _shakeSubscription;
  bool _isUnlocking = false;
  double _lastAccelMagnitude = 0;
  int _shakeCount = 0;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _orbRotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _unlockController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Listen for shake if condition is 'shake'
    if (widget.message.chronosConditionType == 'shake') {
      _listenForShake();
    }
  }

  void _listenForShake() {
    _shakeSubscription = accelerometerEventStream().listen((event) {
      final magnitude = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );

      if (magnitude > 20 && _lastAccelMagnitude <= 20) {
        _shakeCount++;
        if (_shakeCount >= 3) {
          _triggerUnlock();
        }
      }
      _lastAccelMagnitude = magnitude;
    });
  }

  Future<void> _triggerUnlock() async {
    if (_isUnlocking) return;
    setState(() => _isUnlocking = true);

    AppHaptics.heavyTap();

    // Play unlock animation
    await _unlockController.forward();

    // Update Firestore
    try {
      final collection = widget.isGroup ? 'groups' : 'chats';
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(widget.chatId)
          .collection('messages')
          .doc(widget.message.id)
          .update({'isChronosLocked': false});
    } catch (e) {
      debugPrint('Chronos unlock error: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _orbRotationController.dispose();
    _unlockController.dispose();
    _shakeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.message.chronosConditionType ?? 'time';
    final value = widget.message.chronosConditionValue ?? '';
    final icon = ChronosUnlockService.conditionIcons[type] ?? Icons.lock_rounded;
    final hint = ChronosUnlockService.formatCondition(type, value);

    return AnimatedBuilder(
      animation: Listenable.merge([
        _pulseController,
        _orbRotationController,
        _unlockController,
      ]),
      builder: (context, _) {
        // Unlock explosion
        if (_isUnlocking) {
          final t = _unlockController.value;
          return Opacity(
            opacity: (1.0 - t).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 1.0 + (t * 0.5),
              child: _buildOrb(icon, hint, type),
            ),
          );
        }

        return _buildOrb(icon, hint, type);
      },
    );
  }

  Widget _buildOrb(IconData icon, String hint, String type) {
    final pulseVal = _pulseController.value;
    final rotVal = _orbRotationController.value;

    final glowColor = _getGlowColor(type);

    return Container(
      margin: EdgeInsets.only(
        left: widget.isMe ? 60 : 12,
        right: widget.isMe ? 12 : 60,
        top: 4,
        bottom: 4,
      ),
      child: Align(
        alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                glowColor.withOpacity(0.05 + pulseVal * 0.08),
                const Color(0xFF0A1628).withOpacity(0.9),
                glowColor.withOpacity(0.03 + pulseVal * 0.05),
              ],
              stops: const [0.0, 0.5, 1.0],
              transform: GradientRotation(rotVal * 2 * pi),
            ),
            border: Border.all(
              color: glowColor.withOpacity(0.2 + pulseVal * 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: glowColor.withOpacity(0.1 + pulseVal * 0.1),
                blurRadius: 20 + pulseVal * 10,
                spreadRadius: pulseVal * 3,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Orb icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      glowColor.withOpacity(0.3 + pulseVal * 0.2),
                      glowColor.withOpacity(0.05),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withOpacity(0.2),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // "Chronos Message" label
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [
                    glowColor,
                    glowColor.withOpacity(0.6),
                  ],
                ).createShader(bounds),
                child: const Text(
                  'CHRONOS MESSAGE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.5,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Condition hint
              Text(
                hint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5 + pulseVal * 0.2),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 8),

              // Progress dots animation
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final offset = (rotVal * 3 + i) % 3;
                  return Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: glowColor.withOpacity(
                        offset < 1 ? 0.8 : 0.2,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getGlowColor(String type) {
    switch (type) {
      case 'battery':
        return Colors.amber;
      case 'time':
        return const Color(0xFF6366F1); // Indigo
      case 'location':
        return const Color(0xFF10B981); // Emerald
      case 'shake':
        return const Color(0xFFF43F5E); // Rose
      default:
        return AppColors.aquaCore;
    }
  }
}
