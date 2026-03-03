import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/firebase_service.dart';
import '../../../shared/widgets/aqua_avatar.dart';
import '../../../shared/widgets/glass_card.dart';

/// Registration screen for new users (Google sign-in or email sign-up)
/// Pre-fills with Google data if available
class RegisterScreen extends ConsumerStatefulWidget {
  final String uid;
  final String name;
  final String email;
  final String photoUrl;
  final bool isGoogleSignIn;

  const RegisterScreen({
    super.key,
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl = '',
    this.isGoogleSignIn = false,
  });

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;
  bool _isSaving = false;
  bool _usernameAvailable = true;
  bool _checkingUsername = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
    _usernameController = TextEditingController();
    _bioController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _checkUsername(String username) async {
    if (username.trim().length < 3) {
      setState(() {
        _usernameAvailable = false;
        _checkingUsername = false;
      });
      return;
    }

    setState(() => _checkingUsername = true);
    try {
      final query = await FirebaseService.usersCollection
          .where('username', isEqualTo: username.trim().toLowerCase())
          .limit(1)
          .get();
      if (mounted) {
        setState(() {
          _usernameAvailable = query.docs.isEmpty;
          _checkingUsername = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _usernameAvailable = true;
          _checkingUsername = false;
        });
      }
    }
  }

  Future<void> _createAccount() async {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim().toLowerCase();

    if (name.isEmpty) {
      _showError('Please enter your name');
      return;
    }
    if (username.length < 3) {
      _showError('Username must be at least 3 characters');
      return;
    }
    if (!_usernameAvailable) {
      _showError('Username is already taken');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseService.usersCollection.doc(widget.uid).set({
        'uid': widget.uid,
        'name': name,
        'username': username,
        'email': widget.email,
        'photoUrl': widget.photoUrl,
        'bio': _bioController.text.trim(),
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'fcmToken': '',
        'isTypingTo': '',
        'friends': [],
        'blockedUsers': [],
        'friendRequests': {'sent': [], 'received': []},
        'notificationSettings': {
          'messages': true,
          'groupMessages': true,
          'friendRequests': true,
          'calls': true,
          'sounds': true,
          'vibration': true,
        },
        'privacySettings': {
          'showOnlineStatus': true,
          'showLastSeen': true,
          'readReceipts': true,
          'allowFriendRequests': true,
        },
        'twoFactorEnabled': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      _showError('Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.errorRed),
    );
  }

  InputDecoration _inputDecor(String hint, {Widget? suffix}) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textMuted),
        suffixIcon: suffix,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.aquaCore),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      body: SafeArea(
        child: AnimationLimiter(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: AnimationConfiguration.toStaggeredList(
                duration: const Duration(milliseconds: 450),
                childAnimationBuilder: (w) => SlideAnimation(
                  verticalOffset: 50,
                  curve: Curves.easeOutBack,
                  child: FadeInAnimation(child: w),
                ),
                children: [
                  const SizedBox(height: 20),
                  // App logo
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.aquaCore.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      backgroundColor: AppColors.glassPanel,
                      child: Icon(Icons.water_drop_rounded,
                          color: AppColors.aquaCore, size: 28),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Complete Your Profile',
                      style: AppTextStyles.heading.copyWith(fontSize: 22)),
                  const SizedBox(height: 4),
                  Text('Set up your Ripple identity',
                      style: AppTextStyles.caption),
                  const SizedBox(height: 28),

                  // Avatar
                  Center(
                    child: AquaAvatar(
                      imageUrl: widget.photoUrl.isNotEmpty
                          ? widget.photoUrl
                          : null,
                      name: widget.name,
                      size: 80,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Name field
                  GlassCard(
                    borderRadius: 14,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Display Name',
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.aquaCore,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _nameController,
                          style: AppTextStyles.body,
                          decoration: _inputDecor('Your name'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Username field
                  GlassCard(
                    borderRadius: 14,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Username',
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.aquaCore,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _usernameController,
                          style: AppTextStyles.body,
                          onChanged: (v) => _checkUsername(v),
                          decoration: _inputDecor(
                            'Choose a unique username',
                            suffix: _checkingUsername
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation(
                                                  AppColors.aquaCore)),
                                    ),
                                  )
                                : _usernameController.text.length >= 3
                                    ? Icon(
                                        _usernameAvailable
                                            ? Icons.check_circle_rounded
                                            : Icons.cancel_rounded,
                                        color: _usernameAvailable
                                            ? AppColors.onlineGreen
                                            : AppColors.errorRed,
                                        size: 20,
                                      )
                                    : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Bio field
                  GlassCard(
                    borderRadius: 14,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bio (optional)',
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.aquaCore,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _bioController,
                          style: AppTextStyles.body,
                          maxLines: 3,
                          maxLength: 150,
                          decoration: _inputDecor('Tell us about yourself...'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Create Account button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppColors.buttonGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: AppColors.aquaGlow,
                      ),
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _createAccount,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : Text('Create Account',
                                style: AppTextStyles.button),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
