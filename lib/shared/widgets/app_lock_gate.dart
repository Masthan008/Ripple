import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AppLockGate — wraps the app root to enforce biometric/PIN authentication
/// when app lock is enabled. Uses WidgetsBindingObserver to detect app
/// lifecycle changes (background → foreground).
class AppLockGate extends StatefulWidget {
  final Widget child;
  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate>
    with WidgetsBindingObserver {
  bool _isLocked = false;
  bool _isAuthenticating = false;
  bool _appLockEnabled = false;
  String _lockTimeout = 'immediately';
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('app_lock_enabled') ?? false;
    final timeout = prefs.getString('app_lock_timeout') ?? 'immediately';

    if (mounted) {
      setState(() {
        _appLockEnabled = enabled;
        _lockTimeout = timeout;
        // Lock on first launch if enabled
        if (enabled) _isLocked = true;
      });
    }

    // Auto-authenticate on initial launch
    if (enabled) {
      _authenticate();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_appLockEnabled) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      _checkIfShouldLock();
    }
  }

  void _checkIfShouldLock() {
    if (!_appLockEnabled || _backgroundedAt == null) return;

    final elapsed = DateTime.now().difference(_backgroundedAt!);
    final shouldLock = switch (_lockTimeout) {
      'immediately' => true,
      '1min' => elapsed.inSeconds >= 60,
      '15min' => elapsed.inMinutes >= 15,
      '1hour' => elapsed.inHours >= 1,
      _ => true,
    };

    if (shouldLock && !_isLocked) {
      setState(() => _isLocked = true);
      _authenticate();
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    _isAuthenticating = true;

    try {
      final auth = LocalAuthentication();
      final canAuth =
          await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (!canAuth) {
        // Can't authenticate — graceful unlock
        if (mounted) setState(() => _isLocked = false);
        return;
      }

      final authenticated = await auth.authenticate(
        localizedReason: 'Unlock Ripple',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      if (authenticated && mounted) {
        setState(() => _isLocked = false);
      }
    } catch (_) {
      // On error, stay locked but don't crash
    } finally {
      _isAuthenticating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isLocked)
          Positioned.fill(
            child: _AppLockScreen(onUnlock: _authenticate),
          ),
      ],
    );
  }
}

/// Full-screen lock overlay with frosted glass effect.
class _AppLockScreen extends StatelessWidget {
  final VoidCallback onUnlock;
  const _AppLockScreen({required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Frosted glass backdrop
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              color: const Color(0xFF060D1A).withOpacity(0.95),
            ),
          ),
          // Lock UI
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF0EA5E9).withOpacity(0.3),
                        const Color(0xFF6366F1).withOpacity(0.2),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFF0EA5E9).withOpacity(0.4),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Color(0xFF0EA5E9),
                    size: 36,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Ripple is Locked',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Use fingerprint, face, or PIN to unlock',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: onUnlock,
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: const Text('Unlock'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF0EA5E9).withOpacity(0.2),
                    foregroundColor: const Color(0xFF0EA5E9),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color:
                            const Color(0xFF0EA5E9).withOpacity(0.4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
