import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/utils/l10n.dart';

class AccountSecurityScreen extends ConsumerStatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  ConsumerState<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends ConsumerState<AccountSecurityScreen> {
  static const _storage = FlutterSecureStorage();
  final _auth = LocalAuthentication();

  final _currentPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();

  bool _isChangingPass = false;
  bool _biometricEnabled = false;
  bool _canCheckBiometrics = false;
  bool _isTerminatingSessions = false;

  @override
  void initState() {
    super.initState();
    _initBiometrics();
  }

  Future<void> _initBiometrics() async {
    try {
      final canCheck = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      final enabledStr = await _storage.read(key: 'biometric_app_lock_enabled');
      if (mounted) {
        setState(() {
          _canCheckBiometrics = canCheck;
          _biometricEnabled = enabledStr == 'true';
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _currentPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _toggleBiometrics(bool value) async {
    if (value) {
      try {
        final authenticated = await _auth.authenticate(
          localizedReason: 'Scan fingerprint or Face ID to enable Biometric App Lock',
          options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
        );
        if (!authenticated) return;
      } catch (e) {
        _showError('Biometric authentication failed: $e');
        return;
      }
    }

    await _storage.write(key: 'biometric_app_lock_enabled', value: value ? 'true' : 'false');
    AppHaptics.selectionTick();
    if (mounted) {
      setState(() => _biometricEnabled = value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Biometric App Lock enabled' : 'Biometric App Lock disabled'),
          backgroundColor: AppColors.onlineGreen,
        ),
      );
    }
  }

  Future<void> _changePassword() async {
    final current = _currentPassController.text;
    final newPass = _newPassController.text;
    final confirm = _confirmPassController.text;

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      _showError('All password fields are required');
      return;
    }
    if (newPass.length < 6) {
      _showError('New password must be at least 6 characters');
      return;
    }
    if (newPass != confirm) {
      _showError('New passwords do not match');
      return;
    }

    setState(() => _isChangingPass = true);
    try {
      final user = FirebaseService.auth.currentUser!;
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: current,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPass);

      _currentPassController.clear();
      _newPassController.clear();
      _confirmPassController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully!'), backgroundColor: AppColors.onlineGreen),
        );
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Password update failed');
    } catch (_) {
      _showError('Authentication error. Try again.');
    } finally {
      if (mounted) setState(() => _isChangingPass = false);
    }
  }

  Future<void> _sendPasswordResetEmail() async {
    final email = FirebaseService.auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      _showError('No email linked to this account');
      return;
    }
    try {
      await FirebaseService.auth.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password reset link sent to $email'), backgroundColor: AppColors.onlineGreen),
        );
      }
    } catch (e) {
      _showError('Failed to send reset link: $e');
    }
  }

  Future<void> _showSetPinDialog(String uid) async {
    final pinCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Set 6-Digit 2SV PIN', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This PIN will be required whenever you sign in on a new device or pair with the Web Companion.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: pinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(color: Colors.white, letterSpacing: 4),
              decoration: const InputDecoration(
                hintText: 'Enter 6-digit PIN',
                hintStyle: TextStyle(color: Colors.white30),
              ),
            ),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(color: Colors.white, letterSpacing: 4),
              decoration: const InputDecoration(
                hintText: 'Confirm 6-digit PIN',
                hintStyle: TextStyle(color: Colors.white30),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () async {
              final pin = pinCtrl.text.trim();
              final confirm = confirmCtrl.text.trim();
              if (pin.length != 6 || int.tryParse(pin) == null) {
                _showError('PIN must be exactly 6 digits');
                return;
              }
              if (pin != confirm) {
                _showError('PINs do not match');
                return;
              }
              Navigator.pop(ctx);
              await FirebaseService.firestore.collection('users').doc(uid).update({
                'twoStepEnabled': true,
                'twoStepPin': pin,
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Two-Step Verification PIN activated!'), backgroundColor: AppColors.onlineGreen),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.aquaCore, foregroundColor: Colors.black),
            child: const Text('Save PIN'),
          ),
        ],
      ),
    );
  }

  Future<void> _disableTwoStep(String uid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Disable Two-Step Verification?', style: TextStyle(color: Colors.white)),
        content: const Text('Your account will no longer require a security PIN on new logins.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
            child: const Text('Disable'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseService.firestore.collection('users').doc(uid).update({
        'twoStepEnabled': false,
        'twoStepPin': FieldValue.delete(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Two-Step Verification disabled')),
        );
      }
    }
  }

  Future<void> _terminateOtherSessions(String uid) async {
    setState(() => _isTerminatingSessions = true);
    try {
      final sessions = await FirebaseService.firestore.collection('users').doc(uid).collection('webSessions').get();
      final batch = FirebaseService.firestore.batch();
      for (final doc in sessions.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All other active web and mobile sessions terminated.'), backgroundColor: AppColors.onlineGreen),
        );
      }
    } catch (e) {
      _showError('Failed to terminate sessions: $e');
    } finally {
      if (mounted) setState(() => _isTerminatingSessions = false);
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.errorRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(rippleThemeProvider);
    final isDark = theme.isDark;
    final textColor = isDark ? Colors.white : const Color(0xFF09090B);
    final textMuted = isDark ? Colors.white60 : const Color(0xFF71717A);
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    final cardBorder = isDark ? Colors.white12 : const Color(0xFFE4E4E7);

    final user = FirebaseService.auth.currentUser;
    final uid = user?.uid;
    final isEmailUser = user?.providerData.any((p) => p.providerId == 'password') ?? false;

    return Scaffold(
      backgroundColor: theme.colors.background,
      appBar: AppBar(
        title: Text(L10n.s(ref, 'security'), style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: uid == null
          ? const Center(child: Text('Please log in'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseService.firestore.collection('users').doc(uid).snapshots(),
              builder: (context, snapshot) {
                final userData = snapshot.data?.data() ?? {};
                final twoStepEnabled = userData['twoStepEnabled'] as bool? ?? false;

                return AnimationLimiter(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: AnimationConfiguration.toStaggeredList(
                        duration: const Duration(milliseconds: 400),
                        childAnimationBuilder: (w) => SlideAnimation(
                          verticalOffset: 40,
                          curve: Curves.easeOutBack,
                          child: FadeInAnimation(child: w),
                        ),
                        children: [
                          _sectionHeader('AUTHENTICATION & LOCKS', textMuted),
                          const SizedBox(height: 8),

                          // Biometric Lock Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: cardBorder),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.fingerprint_rounded, color: theme.colors.primary, size: 24),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Biometric App Lock', style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 14)),
                                      Text(
                                        _canCheckBiometrics
                                            ? (_biometricEnabled ? 'Active (Fingerprint / Face ID)' : 'Disabled')
                                            : 'Biometrics unavailable on this hardware',
                                        style: TextStyle(
                                          color: _biometricEnabled ? AppColors.onlineGreen : textMuted,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                CupertinoSwitch(
                                  value: _biometricEnabled,
                                  onChanged: _canCheckBiometrics ? _toggleBiometrics : null,
                                  activeTrackColor: Colors.black,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Two-Step Verification Card (Real-time Firestore)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: cardBorder),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.pin_rounded, color: theme.colors.primary, size: 24),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Two-Step Cloud PIN', style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 14)),
                                          Text(
                                            twoStepEnabled ? 'Active (6-digit PIN set)' : 'Disabled (Recommended to enable)',
                                            style: TextStyle(
                                              color: twoStepEnabled ? AppColors.onlineGreen : textMuted,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    CupertinoSwitch(
                                      value: twoStepEnabled,
                                      onChanged: (val) {
                                        if (val) {
                                          _showSetPinDialog(uid);
                                        } else {
                                          _disableTwoStep(uid);
                                        }
                                      },
                                      activeTrackColor: Colors.black,
                                    ),
                                  ],
                                ),
                                if (twoStepEnabled) ...[
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 38,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _showSetPinDialog(uid),
                                      icon: const Icon(Icons.edit_outlined, size: 16),
                                      label: const Text('Change 6-Digit PIN', style: TextStyle(fontSize: 12.5)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: theme.colors.primary,
                                        side: BorderSide(color: cardBorder),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          _sectionHeader('ACTIVE SESSIONS & DEVICES', textMuted),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: cardBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.devices_rounded, color: theme.colors.primary, size: 22),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Linked Sessions', style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 14)),
                                          Text('Current mobile device + active Web Companions', style: TextStyle(color: textMuted, fontSize: 11.5)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  height: 42,
                                  child: OutlinedButton.icon(
                                    onPressed: _isTerminatingSessions ? null : () => _terminateOtherSessions(uid),
                                    icon: _isTerminatingSessions
                                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                        : const Icon(Icons.logout_rounded, size: 16),
                                    label: const Text('Terminate All Other Sessions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.errorRed,
                                      side: const BorderSide(color: Color(0x33EF4444)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          _sectionHeader('PASSWORD & RECOVERY', textMuted),
                          const SizedBox(height: 8),
                          if (isEmailUser) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: cardBorder),
                              ),
                              child: Column(
                                children: [
                                  TextField(
                                    controller: _currentPassController,
                                    obscureText: true,
                                    style: TextStyle(color: textColor, fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: 'Current password',
                                      hintStyle: TextStyle(color: textMuted),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cardBorder)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cardBorder)),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.colors.primary)),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _newPassController,
                                    obscureText: true,
                                    style: TextStyle(color: textColor, fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: 'New password (min 6 chars)',
                                      hintStyle: TextStyle(color: textMuted),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cardBorder)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cardBorder)),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.colors.primary)),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _confirmPassController,
                                    obscureText: true,
                                    style: TextStyle(color: textColor, fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: 'Confirm new password',
                                      hintStyle: TextStyle(color: textMuted),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cardBorder)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cardBorder)),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.colors.primary)),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 44,
                                    child: ElevatedButton(
                                      onPressed: _isChangingPass ? null : _changePassword,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: theme.colors.primary,
                                        foregroundColor: isDark ? Colors.black : Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      child: _isChangingPass
                                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                                          : const Text('Update Password', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: cardBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.shield_rounded, color: theme.colors.primary, size: 22),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Federated Authentication Active',
                                          style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Your account is secured via Google or Apple Identity. To reset your cloud credentials, you can receive a direct password link.',
                                    style: TextStyle(color: textMuted, fontSize: 12, height: 1.4),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 42,
                                    child: OutlinedButton.icon(
                                      onPressed: _sendPasswordResetEmail,
                                      icon: const Icon(Icons.email_outlined, size: 16),
                                      label: const Text('Send Password Setup Email'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: theme.colors.primary,
                                        side: BorderSide(color: cardBorder),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _sectionHeader(String title, Color color) => Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: color,
        ),
      );
}
