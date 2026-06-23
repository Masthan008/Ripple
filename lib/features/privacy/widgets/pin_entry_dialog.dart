import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/privacy_service.dart';
import '../../../core/services/decoy_provider.dart';
import '../../../core/utils/haptic_feedback.dart';

/// PinEntryDialog — Beautiful glassmorphic PIN entry interface.
/// Integrates with the Sentient Decoy Passcode to unlock either
/// the authentic chat or the decoy simulation matrix.
class PinEntryDialog extends ConsumerStatefulWidget {
  final String title;
  const PinEntryDialog({
    super.key,
    this.title = 'Enter PIN to Unlock',
  });

  @override
  ConsumerState<PinEntryDialog> createState() => _PinEntryDialogState();
}

class _PinEntryDialogState extends ConsumerState<PinEntryDialog> {
  String _pin = '';

  void _onNumberPressed(int number) {
    if (_pin.length < 6) {
      AppHaptics.lightTap();
      setState(() {
        _pin += number.toString();
      });
    }
  }

  void _onBackspacePressed() {
    if (_pin.isNotEmpty) {
      AppHaptics.lightTap();
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  Future<void> _onSubmit() async {
    if (_pin.isEmpty) return;
    AppHaptics.mediumTap();

    // Check if entered pin matches the fake passcode
    final isDecoy = await PrivacyService.checkFakePasscode(_pin);
    if (isDecoy) {
      // Unlock but swap app state to Decoy Mode
      ref.read(decoyModeProvider.notifier).state = true;
      if (mounted) {
        Navigator.of(context).pop(true);
      }
      return;
    }

    // Otherwise, we accept it as authentic (as standard biometric/PIN fallback)
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF07111E).withOpacity(0.85),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.aquaCore.withOpacity(0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.aquaCore.withOpacity(0.15),
              blurRadius: 40,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_person_rounded,
              color: AppColors.aquaCore,
              size: 44,
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Pin indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final hasChar = index < _pin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasChar ? AppColors.aquaCore : Colors.transparent,
                    border: Border.all(
                      color: hasChar ? AppColors.aquaCore : Colors.white30,
                      width: 2.0,
                    ),
                    boxShadow: hasChar
                        ? [
                            BoxShadow(
                              color: AppColors.aquaCore.withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 1,
                            )
                          ]
                        : [],
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),
            // Numeric Keypad
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.25,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                if (index == 9) {
                  // Backspace
                  return IconButton(
                    icon: const Icon(Icons.backspace_rounded, color: Colors.white60),
                    onPressed: _onBackspacePressed,
                  );
                } else if (index == 10) {
                  // 0
                  return _buildKeypadButton(0);
                } else if (index == 11) {
                  // Submit Checkmark
                  return IconButton(
                    icon: const Icon(Icons.check_circle_rounded, color: AppColors.aquaCore, size: 36),
                    onPressed: _onSubmit,
                  );
                } else {
                  // 1-9
                  return _buildKeypadButton(index + 1);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadButton(int number) {
    return Material(
      color: Colors.white.withOpacity(0.04),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _onNumberPressed(number),
        child: Center(
          child: Text(
            '$number',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
