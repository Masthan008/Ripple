import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App Lock Settings — configure biometric/PIN lock for the entire app.
class AppLockSettingsScreen extends StatefulWidget {
  const AppLockSettingsScreen({super.key});

  @override
  State<AppLockSettingsScreen> createState() => _AppLockSettingsScreenState();
}

class _AppLockSettingsScreenState extends State<AppLockSettingsScreen> {
  bool _appLockEnabled = false;
  String _lockTimeout = 'immediately'; // immediately, 1min, 15min, 1hour
  bool _isLoading = true;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final auth = LocalAuthentication();
    final canAuth = await auth.canCheckBiometrics || await auth.isDeviceSupported();

    if (mounted) {
      setState(() {
        _appLockEnabled = prefs.getBool('app_lock_enabled') ?? false;
        _lockTimeout = prefs.getString('app_lock_timeout') ?? 'immediately';
        _biometricAvailable = canAuth;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleAppLock(bool value) async {
    if (value && !_biometricAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No biometric or device security available'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    // Verify identity before enabling
    if (value) {
      final auth = LocalAuthentication();
      try {
        final authenticated = await auth.authenticate(
          localizedReason: 'Verify your identity to enable App Lock',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: false,
          ),
        );
        if (!authenticated) return;
      } catch (_) {
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_lock_enabled', value);
    if (mounted) {
      setState(() => _appLockEnabled = value);
    }
  }

  Future<void> _setLockTimeout(String timeout) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_lock_timeout', timeout);
    if (mounted) {
      setState(() => _lockTimeout = timeout);
      Navigator.pop(context);
    }
  }

  String _timeoutLabel(String value) {
    switch (value) {
      case 'immediately':
        return 'Immediately';
      case '1min':
        return 'After 1 minute';
      case '15min':
        return 'After 15 minutes';
      case '1hour':
        return 'After 1 hour';
      default:
        return 'Immediately';
    }
  }

  void _showTimeoutPicker() {
    final options = ['immediately', '1min', '15min', '1hour'];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A1628),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lock after...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'How long after leaving the app should it lock?',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ...options.map(
              (option) => ListTile(
                leading: Icon(
                  option == 'immediately'
                      ? Icons.lock_rounded
                      : Icons.timer_rounded,
                  color: _lockTimeout == option
                      ? const Color(0xFF0EA5E9)
                      : Colors.white54,
                ),
                title: Text(
                  _timeoutLabel(option),
                  style: TextStyle(
                    color: _lockTimeout == option
                        ? const Color(0xFF0EA5E9)
                        : Colors.white,
                    fontWeight: _lockTimeout == option
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                trailing: _lockTimeout == option
                    ? const Icon(Icons.check_rounded,
                        color: Color(0xFF0EA5E9))
                    : null,
                onTap: () => _setLockTimeout(option),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        title: const Row(
          children: [
            Icon(Icons.fingerprint_rounded,
                color: Color(0xFF0EA5E9), size: 22),
            SizedBox(width: 8),
            Text('App Lock'),
          ],
        ),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0EA5E9)))
          : ListView(
              children: [
                // Info banner
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF0EA5E9).withOpacity(0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.fingerprint_rounded,
                          color: Color(0xFF0EA5E9), size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'When enabled, you\'ll need to use fingerprint, '
                          'face recognition, or your device PIN to open Ripple.',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main toggle
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _appLockEnabled
                        ? const Color(0xFF0EA5E9).withOpacity(0.1)
                        : Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _appLockEnabled
                          ? const Color(0xFF0EA5E9).withOpacity(0.3)
                          : Colors.white12,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _appLockEnabled
                            ? Icons.lock_rounded
                            : Icons.lock_open_rounded,
                        color: _appLockEnabled
                            ? const Color(0xFF0EA5E9)
                            : Colors.white38,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'App Lock',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _appLockEnabled
                                  ? 'Ripple is protected'
                                  : 'Protect Ripple with biometrics',
                              style: TextStyle(
                                color: _appLockEnabled
                                    ? const Color(0xFF0EA5E9)
                                    : Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _appLockEnabled,
                        onChanged: _toggleAppLock,
                        activeThumbColor: const Color(0xFF0EA5E9),
                      ),
                    ],
                  ),
                ),

                if (_appLockEnabled) ...[
                  const SizedBox(height: 8),
                  // Timeout setting
                  ListTile(
                    leading: const Icon(Icons.timer_rounded,
                        color: Color(0xFF0EA5E9), size: 24),
                    title: const Text(
                      'Auto-lock Timeout',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'How long before the app locks after you leave',
                      style:
                          TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _timeoutLabel(_lockTimeout),
                          style: const TextStyle(
                            color: Color(0xFF0EA5E9),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right,
                            color: Colors.white38, size: 18),
                      ],
                    ),
                    onTap: _showTimeoutPicker,
                  ),
                ],

                if (!_biometricAvailable) ...[
                  const SizedBox(height: 16),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.orange.withOpacity(0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.orange, size: 22),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No biometric or device security is set up on this device. '
                            'Please set up a screen lock in your device settings first.',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 40),
              ],
            ),
    );
  }
}
