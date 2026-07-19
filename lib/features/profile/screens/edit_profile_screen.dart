import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:image_picker/image_picker.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../shared/widgets/aqua_avatar.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../auth/providers/auth_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user != null) {
      _nameController.text = user.name;
      _bioController.text = user.bio;
      _photoUrl = user.photoUrl;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (picked == null) return;

      setState(() => _isUploadingPhoto = true);

      final file = File(picked.path);
      final secureUrl = await CloudinaryService.uploadImage(file);

      if (secureUrl != null) {
        final uid = FirebaseService.auth.currentUser?.uid;
        if (uid != null) {
          await FirebaseService.firestore.collection('users').doc(uid).update({
            'photoUrl': secureUrl,
          });

          setState(() {
            _photoUrl = secureUrl;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile photo updated!'),
                backgroundColor: AppColors.onlineGreen,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload photo. Please try again.'),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name cannot be empty'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final uid = FirebaseService.auth.currentUser?.uid;
      if (uid == null) return;

      await FirebaseService.firestore.collection('users').doc(uid).update({
        'name': name,
        'bio': _bioController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated!'),
            backgroundColor: AppColors.onlineGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong. Try again.'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      appBar: AppBar(
        title: Text('Edit Profile', style: AppTextStyles.heading),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.aquaCore),
      ),
      body: AnimationLimiter(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: AnimationConfiguration.toStaggeredList(
              duration: const Duration(milliseconds: 450),
              childAnimationBuilder: (widget) => SlideAnimation(
                verticalOffset: 50,
                curve: Curves.easeOutBack,
                child: FadeInAnimation(child: widget),
              ),
              children: [
                // Avatar with camera overlay
                Center(
                  child: GestureDetector(
                    onTap: _pickPhoto,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        if (_isUploadingPhoto)
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.glassPanel,
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation(AppColors.aquaCore),
                              ),
                            ),
                          )
                        else
                          AquaAvatar(
                            imageUrl: _photoUrl,
                            name: _nameController.text,
                            size: 90,
                          ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: AppColors.buttonGradient,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.abyssBackground,
                              width: 3,
                            ),
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              color: Colors.white, size: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Name field
                GlassCard(
                  borderRadius: 16,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Display Name', style: AppTextStyles.caption.copyWith(
                        color: AppColors.aquaCore, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        style: AppTextStyles.body,
                        decoration: InputDecoration(
                          hintText: 'Enter your name',
                          hintStyle: TextStyle(color: AppColors.textMuted),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.glassBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.aquaCore),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Bio field
                GlassCard(
                  borderRadius: 16,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bio', style: AppTextStyles.caption.copyWith(
                        color: AppColors.aquaCore, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _bioController,
                        style: AppTextStyles.body,
                        maxLines: 3,
                        maxLength: 150,
                        decoration: InputDecoration(
                          hintText: 'Tell us about yourself...',
                          hintStyle: TextStyle(color: AppColors.textMuted),
                          counterStyle: TextStyle(color: AppColors.textMuted),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.glassBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.aquaCore),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Save button
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
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        elevation: 0,
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
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                  ),
                ),
                const SizedBox(height: 32),

                // Danger Zone / Delete Account Section
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'DANGER ZONE',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: AppColors.errorRed.withOpacity(0.8),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                GlassCard(
                  borderRadius: 16,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AppColors.errorRed, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Permanently Delete Account',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.errorRed,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Deleting your account will permanently wipe all your messages, profile details, uploaded media, and cloud backups from Ripple. This action is real-time and cannot be undone.',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textMuted, height: 1.3),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton(
                          onPressed: _showDeleteAccountConfirmDialog,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.errorRed,
                            side: const BorderSide(color: AppColors.errorRed, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDeleteAccountConfirmDialog() async {
    final user = FirebaseService.auth.currentUser;
    if (user == null) return;
    final isEmailUser = user.providerData.any((p) => p.providerId == 'password');

    final passwordController = TextEditingController();
    bool acceptedRules = false;
    bool isDeleting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: AppColors.errorRed.withOpacity(0.3)),
              ),
              title: const Row(
                children: [
                  Icon(Icons.report_problem_rounded, color: AppColors.errorRed),
                  SizedBox(width: 10),
                  Text('Delete Ripple Account', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Account Deletion Consequences:',
                      style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    _buildConsequenceRow('Profile data, bio, and display photo will be deleted.'),
                    _buildConsequenceRow('All direct message history and chat threads will be erased.'),
                    _buildConsequenceRow('You will be permanently removed from all group chats.'),
                    _buildConsequenceRow('Cloud backups, custom sounds, and user files will be purged.'),
                    _buildConsequenceRow('This process is immediate, real-time, and irreversible.'),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: acceptedRules,
                          activeColor: AppColors.errorRed,
                          onChanged: isDeleting
                              ? null
                              : (val) {
                                  setDialogState(() {
                                    acceptedRules = val ?? false;
                                  });
                                },
                        ),
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Text(
                              'I accept all rules and confirm I want to permanently delete my account and data.',
                              style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isEmailUser) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Enter your password to confirm',
                          hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: (!acceptedRules || isDeleting)
                      ? null
                      : () async {
                          if (isEmailUser && passwordController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter your password to confirm deletion.')),
                            );
                            return;
                          }

                          setDialogState(() {
                            isDeleting = true;
                          });

                          try {
                            if (isEmailUser) {
                              final credential = EmailAuthProvider.credential(
                                email: user.email!,
                                password: passwordController.text,
                              );
                              await user.reauthenticateWithCredential(credential);
                            }

                            final uid = user.uid;
                            await ref.read(authServiceProvider).deleteUserAccount(uid);

                            if (context.mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Your Ripple account has been deleted.'),
                                  backgroundColor: AppColors.errorRed,
                                ),
                              );
                              context.go('/login');
                            }
                          } catch (e) {
                            if (context.mounted) {
                              setDialogState(() {
                                isDeleting = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to delete account: $e'),
                                  backgroundColor: AppColors.errorRed,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.errorRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text('Delete Permanently'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildConsequenceRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cancel_rounded, color: AppColors.errorRed, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
