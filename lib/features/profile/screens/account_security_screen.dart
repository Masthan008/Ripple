import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/firebase_service.dart';
import '../../../shared/widgets/glass_card.dart';

class AccountSecurityScreen extends ConsumerStatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  ConsumerState<AccountSecurityScreen> createState() =>
      _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends ConsumerState<AccountSecurityScreen> {
  final _currentPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _isChangingPass = false;
  bool _twoFactorEnabled = false;
  bool _isEmailUser = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseService.auth.currentUser;
    _isEmailUser = user?.providerData.any((p) => p.providerId == 'password') ?? false;
    _loadTwoFactor();
  }

  Future<void> _loadTwoFactor() async {
    final uid = FirebaseService.auth.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseService.firestore.collection('users').doc(uid).get();
    if (doc.exists && mounted) {
      setState(() {
        _twoFactorEnabled = doc.data()?['twoFactorEnabled'] ?? false;
      });
    }
  }

  @override
  void dispose() {
    _currentPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final current = _currentPassController.text;
    final newPass = _newPassController.text;
    final confirm = _confirmPassController.text;

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      _showError('All fields are required');
      return;
    }
    if (newPass.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }
    if (newPass != confirm) {
      _showError('Passwords do not match');
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
          const SnackBar(
            content: Text('Password updated successfully!'),
            backgroundColor: AppColors.onlineGreen,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Failed to update password');
    } catch (e) {
      _showError('Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _isChangingPass = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.errorRed),
    );
  }

  Future<void> _toggleTwoFactor(bool value) async {
    setState(() => _twoFactorEnabled = value);
    try {
      final uid = FirebaseService.auth.currentUser?.uid;
      if (uid == null) return;
      await FirebaseService.firestore.collection('users').doc(uid).update({
        'twoFactorEnabled': value,
      });
      if (value && mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF0D1B2A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('2FA Enabled', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
            content: Text(
              'Two-factor authentication via email OTP will be sent on each login for added security.',
              style: AppTextStyles.caption,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Got it', style: TextStyle(color: AppColors.aquaCore)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _twoFactorEnabled = !value);
      _showError('Something went wrong. Try again.');
    }
  }

  InputDecoration _inputDecor(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: AppColors.textMuted),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.glassBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.aquaCore),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      appBar: AppBar(
        title: Text('Account Security', style: AppTextStyles.heading),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.aquaCore),
      ),
      body: AnimationLimiter(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: AnimationConfiguration.toStaggeredList(
              duration: const Duration(milliseconds: 450),
              childAnimationBuilder: (widget) => SlideAnimation(
                verticalOffset: 50,
                curve: Curves.easeOutBack,
                child: FadeInAnimation(child: widget),
              ),
              children: [
                // Change Password section
                if (_isEmailUser) ...[
                  _sectionHeader('Change Password'),
                  const SizedBox(height: 8),
                  GlassCard(
                    borderRadius: 16,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _currentPassController,
                          style: AppTextStyles.body,
                          obscureText: true,
                          decoration: _inputDecor('Current password'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _newPassController,
                          style: AppTextStyles.body,
                          obscureText: true,
                          decoration: _inputDecor('New password (min 6 chars)'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _confirmPassController,
                          style: AppTextStyles.body,
                          obscureText: true,
                          decoration: _inputDecor('Confirm new password'),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: AppColors.buttonGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ElevatedButton(
                              onPressed: _isChangingPass ? null : _changePassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isChangingPass
                                  ? const SizedBox(width: 20, height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(Colors.white)))
                                  : Text('Update Password', style: AppTextStyles.button),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // 2FA section
                _sectionHeader('Two-Factor Authentication'),
                const SizedBox(height: 8),
                GlassCard(
                  borderRadius: 16,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.shield_outlined,
                              color: AppColors.aquaCore, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Enable 2FA', style: AppTextStyles.body),
                                Text(
                                  _twoFactorEnabled ? 'Active' : 'Inactive',
                                  style: AppTextStyles.caption.copyWith(
                                    color: _twoFactorEnabled
                                        ? AppColors.onlineGreen
                                        : AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: _twoFactorEnabled,
                            onChanged: _toggleTwoFactor,
                            activeThumbColor: AppColors.aquaCore,
                            activeTrackColor: const Color(0x550EA5E9),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.aquaCore.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                color: AppColors.aquaCore, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '2FA adds extra security to your account by requiring email verification on each login.',
                                style: AppTextStyles.caption.copyWith(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) => Text(
    title.toUpperCase(),
    style: AppTextStyles.caption.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.2,
      color: AppColors.aquaCore.withValues(alpha: 0.7),
    ),
  );
}
