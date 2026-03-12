import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Biometric / PIN authentication service for chat lock.
class ChatLockService {
  static final _localAuth = LocalAuthentication();

  // ── CHECK BIOMETRIC AVAILABLE ──────────────────────────
  static Future<bool> isBiometricAvailable() async {
    try {
      final canAuth = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canAuth || isDeviceSupported;
    } catch (e) {
      debugPrint('Biometric check error: $e');
      return false;
    }
  }

  // ── AUTHENTICATE ───────────────────────────────────────
  static Future<bool> authenticate({
    String reason = 'Authenticate to open this chat',
  }) async {
    try {
      final available = await isBiometricAvailable();
      if (!available) return true; // No biometrics → allow access

      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // allows PIN too
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('Auth error: $e');
      return false;
    }
  }
}
