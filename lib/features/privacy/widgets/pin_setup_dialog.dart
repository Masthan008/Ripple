import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/haptic_feedback.dart';

/// PinSetupDialog — Allows user to set a new security PIN before locking a chat.
class PinSetupDialog extends ConsumerStatefulWidget {
  const PinSetupDialog({super.key});

  @override
  ConsumerState<PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends ConsumerState<PinSetupDialog> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _savePin() {
    final pin = _pinController.text.trim();
    final confirm = _confirmController.text.trim();

    if (pin.length < 4 || pin.length > 6) {
      setState(() => _error = 'PIN must be between 4 and 6 digits');
      return;
    }
    if (pin != confirm) {
      setState(() => _error = 'PINs do not match. Please verify.');
      return;
    }

    AppHaptics.mediumTap();
    Navigator.of(context).pop(pin);
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? Colors.white10 : const Color(0xFFF4F4F5),
                ),
                child: Icon(Icons.shield_outlined, color: textPrimary, size: 24),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Set Chat Lock PIN',
              style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Create a 4 to 6 digit security PIN to protect locked chats',
              style: TextStyle(color: textMuted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              style: TextStyle(color: textPrimary, letterSpacing: 6, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'Enter New PIN',
                counterText: '',
                hintStyle: TextStyle(color: textMuted, letterSpacing: 0),
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF4F4F5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              style: TextStyle(color: textPrimary, letterSpacing: 6, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'Confirm PIN',
                counterText: '',
                hintStyle: TextStyle(color: textMuted, letterSpacing: 0),
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF4F4F5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFFE5484D), fontSize: 12, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _savePin,
              style: ElevatedButton.styleFrom(
                backgroundColor: textPrimary,
                foregroundColor: isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Save & Lock Chat', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: textMuted)),
            ),
          ],
        ),
      ),
    );
  }
}
