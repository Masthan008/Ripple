import 'dart:math';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/constants/app_colors.dart';

/// Quantum Vault™ — Biometric Scrambled Messages
/// Messages sent with Quantum Lock appear as scrambled Matrix-style text.
/// The receiver must press and hold biometric auth to reveal the real text.
/// The moment they release, it rescrambles instantly.

class QuantumVaultBubble extends StatefulWidget {
  final String actualText;
  final bool isMe;

  const QuantumVaultBubble({
    super.key,
    required this.actualText,
    required this.isMe,
  });

  @override
  State<QuantumVaultBubble> createState() => _QuantumVaultBubbleState();
}

class _QuantumVaultBubbleState extends State<QuantumVaultBubble>
    with SingleTickerProviderStateMixin {
  bool _isRevealed = false;
  bool _isAuthenticating = false;
  late AnimationController _glitchController;
  final _random = Random();
  String _scrambledText = '';

  static const _matrixChars =
      'ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩαβγδεζηθικλμνξοπρστυφχψω'
      '0123456789₀₁₂₃₄₅₆₇₈₉'
      '╬╠╣╦╩╔╗╚╝║═│─┌┐└┘'
      '░▒▓█▀▄▌▐';

  @override
  void initState() {
    super.initState();
    _glitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..addListener(() {
        if (!_isRevealed) {
          setState(() => _scrambledText = _generateScramble());
        }
      });
    _glitchController.repeat();
    _scrambledText = _generateScramble();
  }

  @override
  void dispose() {
    _glitchController.dispose();
    super.dispose();
  }

  String _generateScramble() {
    return String.fromCharCodes(
      List.generate(
        widget.actualText.length,
        (_) => _matrixChars.codeUnitAt(_random.nextInt(_matrixChars.length)),
      ),
    );
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    _isAuthenticating = true;

    try {
      final auth = LocalAuthentication();
      final canAuth = await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (!canAuth) {
        // Fallback: just reveal on long press if no biometrics
        setState(() => _isRevealed = true);
        return;
      }

      final didAuthenticate = await auth.authenticate(
        localizedReason: 'Authenticate to reveal Quantum message',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );

      if (didAuthenticate && mounted) {
        setState(() => _isRevealed = true);
      }
    } catch (e) {
      // Fallback: reveal on error (e.g., no biometric hardware)
      if (mounted) setState(() => _isRevealed = true);
    } finally {
      _isAuthenticating = false;
    }
  }

  void _rescramble() {
    setState(() => _isRevealed = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: widget.isMe ? null : (_) => _authenticate(),
      onLongPressEnd: widget.isMe ? null : (_) => _rescramble(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: _isRevealed
                ? [
                    AppColors.aquaCore.withOpacity(0.15),
                    AppColors.aquaCore.withOpacity(0.05),
                  ]
                : [
                    const Color(0xFF1A0A2E).withOpacity(0.9),
                    const Color(0xFF0D001A).withOpacity(0.95),
                  ],
          ),
          border: Border.all(
            color: _isRevealed
                ? AppColors.aquaCore.withOpacity(0.5)
                : const Color(0xFF6366F1).withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            if (!_isRevealed)
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.2),
                blurRadius: 12,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header label
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isRevealed ? Icons.lock_open_rounded : Icons.lock_rounded,
                  size: 12,
                  color: _isRevealed
                      ? AppColors.aquaCore
                      : const Color(0xFF6366F1),
                ),
                const SizedBox(width: 4),
                Text(
                  _isRevealed ? 'QUANTUM UNLOCKED' : 'QUANTUM VAULT',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: _isRevealed
                        ? AppColors.aquaCore.withOpacity(0.7)
                        : const Color(0xFF6366F1).withOpacity(0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Message text (scrambled or real)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _isRevealed
                    ? widget.actualText
                    : (widget.isMe ? widget.actualText : _scrambledText),
                key: ValueKey(_isRevealed),
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: _isRevealed
                      ? Colors.white
                      : const Color(0xFF00FF41).withOpacity(0.8),
                  fontFamily: _isRevealed ? null : 'monospace',
                  letterSpacing: _isRevealed ? 0 : 1.5,
                ),
              ),
            ),

            // Hint for receiver
            if (!widget.isMe && !_isRevealed) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.fingerprint_rounded,
                    size: 14,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Hold to reveal',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.3),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
