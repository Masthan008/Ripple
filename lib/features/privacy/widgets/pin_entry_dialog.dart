import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/services/privacy_service.dart';
import '../../../core/services/decoy_provider.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/haptic_feedback.dart';

/// PinEntryDialog — Modern, Theme-Aware PIN Verification Dialog.
/// Rigorously validates against authentic stored PIN or decoy trigger.
class PinEntryDialog extends ConsumerStatefulWidget {
  final String title;
  const PinEntryDialog({
    super.key,
    this.title = 'Enter PIN to Unlock',
  });

  @override
  ConsumerState<PinEntryDialog> createState() => _PinEntryDialogState();
}

class _PinEntryDialogState extends ConsumerState<PinEntryDialog> with SingleTickerProviderStateMixin {
  String _pin = '';
  String? _errorMessage;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _tryBiometricUnlock();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _tryBiometricUnlock() async {
    try {
      final auth = LocalAuthentication();
      final canCheck = await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (canCheck) {
        final authenticated = await auth.authenticate(
          localizedReason: 'Scan fingerprint or face to unlock chat',
          options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
        );
        if (authenticated && mounted) {
          AppHaptics.mediumTap();
          Navigator.of(context).pop(true);
        }
      }
    } catch (_) {}
  }

  void _onNumberPressed(int number) {
    if (_pin.length < 6) {
      AppHaptics.lightTap();
      setState(() {
        _pin += number.toString();
        _errorMessage = null;
      });
      if (_pin.length >= 4) {
        _checkPinQuick();
      }
    }
  }

  Future<void> _checkPinQuick() async {
    final isDecoy = await PrivacyService.checkFakePasscode(_pin);
    if (isDecoy) {
      ref.read(decoyModeProvider.notifier).state = true;
      if (mounted) Navigator.of(context).pop(true);
      return;
    }

    final isValid = await PrivacyService.verifyPin(_pin);
    if (isValid && mounted) {
      AppHaptics.mediumTap();
      Navigator.of(context).pop(true);
    }
  }

  void _onBackspacePressed() {
    if (_pin.isNotEmpty) {
      AppHaptics.lightTap();
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _errorMessage = null;
      });
    }
  }

  Future<void> _onSubmit() async {
    if (_pin.isEmpty) return;

    final isDecoy = await PrivacyService.checkFakePasscode(_pin);
    if (isDecoy) {
      ref.read(decoyModeProvider.notifier).state = true;
      if (mounted) Navigator.of(context).pop(true);
      return;
    }

    final isValid = await PrivacyService.verifyPin(_pin);
    if (isValid) {
      AppHaptics.mediumTap();
      if (mounted) Navigator.of(context).pop(true);
    } else {
      AppHaptics.error();
      _shakeController.forward(from: 0.0);
      setState(() {
        _errorMessage = 'Incorrect PIN. Try again.';
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(rippleThemeProvider);
    final isDark = theme.isDark;

    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardBorder = isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF09090B);
    final textMuted = isDark ? Colors.white60 : const Color(0xFF71717A);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: AnimatedBuilder(
        animation: _shakeController,
        builder: (context, child) {
          final offset = (_shakeController.value < 0.5
                  ? _shakeController.value
                  : 1.0 - _shakeController.value) *
              16 *
              (0.5 - (_shakeController.value * 2)).sign;
          return Transform.translate(
            offset: Offset(offset, 0),
            child: child,
          );
        },
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cardBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? Colors.white10 : const Color(0xFFF4F4F5),
                ),
                child: Icon(
                  Icons.lock_rounded,
                  color: textPrimary,
                  size: 26,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                widget.title,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Enter your 4-6 digit secret security PIN',
                style: TextStyle(color: textMuted, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Pin indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  final hasChar = index < _pin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasChar ? textPrimary : Colors.transparent,
                      border: Border.all(
                        color: hasChar ? textPrimary : cardBorder,
                        width: 1.8,
                      ),
                    ),
                  );
                }),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Color(0xFFE5484D), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
              const SizedBox(height: 24),
              // Numeric Keypad
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.35,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  if (index == 9) {
                    return IconButton(
                      icon: Icon(Icons.backspace_outlined, color: textMuted, size: 22),
                      onPressed: _onBackspacePressed,
                    );
                  } else if (index == 10) {
                    return _buildKeypadButton(0, textPrimary, isDark);
                  } else if (index == 11) {
                    return IconButton(
                      icon: Icon(Icons.check_circle_rounded, color: textPrimary, size: 32),
                      onPressed: _onSubmit,
                    );
                  } else {
                    return _buildKeypadButton(index + 1, textPrimary, isDark);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadButton(int number, Color textPrimary, bool isDark) {
    return Material(
      color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF4F4F5),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _onNumberPressed(number),
        child: Center(
          child: Text(
            '$number',
            style: TextStyle(
              color: textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
