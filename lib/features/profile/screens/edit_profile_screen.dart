import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/aqua_avatar.dart';
import '../../auth/providers/auth_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  String? _photoUrl;

  String _initialUsername = '';
  String? _usernameError;
  bool _isCheckingUsername = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user != null) {
      _nameController.text = user.name;
      _bioController.text = user.bio;
      _photoUrl = user.photoUrl;
    }
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final uid = FirebaseService.auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseService.firestore.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        final u = (doc.data()?['username'] as String?) ?? '';
        setState(() {
          _usernameController.text = u;
          _initialUsername = u.trim().toLowerCase();
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String val) {
    _debounceTimer?.cancel();
    final raw = val.trim().toLowerCase();

    if (raw.isEmpty) {
      setState(() {
        _usernameError = 'Username cannot be empty';
        _isCheckingUsername = false;
      });
      return;
    }

    if (raw.length < 3) {
      setState(() {
        _usernameError = 'Username must be at least 3 characters';
        _isCheckingUsername = false;
      });
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(raw)) {
      setState(() {
        _usernameError = 'Use only letters, numbers, underscores, and dots';
        _isCheckingUsername = false;
      });
      return;
    }

    if (raw == _initialUsername) {
      setState(() {
        _usernameError = null;
        _isCheckingUsername = false;
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _usernameError = null;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      try {
        final query = await FirebaseService.firestore
            .collection('users')
            .where('username', isEqualTo: raw)
            .limit(2)
            .get();
        final currentUid = FirebaseService.auth.currentUser?.uid;
        final isTaken = query.docs.any((doc) => doc.id != currentUid);

        if (mounted) {
          setState(() {
            _isCheckingUsername = false;
            if (isTaken) {
              _usernameError = 'Username @$raw is already taken. Please choose another.';
            } else {
              _usernameError = null;
            }
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isCheckingUsername = false);
        }
      }
    });
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
        const SnackBar(content: Text('Name cannot be empty'), backgroundColor: AppColors.errorRed),
      );
      return;
    }

    if (_usernameError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_usernameError!), backgroundColor: AppColors.errorRed),
      );
      return;
    }

    final newUsername = _usernameController.text.trim().toLowerCase();

    setState(() => _isSaving = true);
    try {
      final uid = FirebaseService.auth.currentUser?.uid;
      if (uid == null) return;

      // Final uniqueness check before commit
      if (newUsername.isNotEmpty && newUsername != _initialUsername) {
        final q = await FirebaseService.firestore
            .collection('users')
            .where('username', isEqualTo: newUsername)
            .limit(2)
            .get();
        if (q.docs.any((d) => d.id != uid)) {
          if (mounted) {
            setState(() {
              _usernameError = 'Username @$newUsername is already taken by another user.';
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_usernameError!), backgroundColor: AppColors.errorRed),
            );
          }
          return;
        }
      }

      await FirebaseService.firestore.collection('users').doc(uid).update({
        'name': name,
        'username': newUsername,
        'bio': _bioController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: AppColors.onlineGreen),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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

    return Scaffold(
      backgroundColor: theme.colors.background,
      appBar: AppBar(
        title: Text(L10n.s(ref, 'edit'), style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimationLimiter(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: AnimationConfiguration.toStaggeredList(
              duration: const Duration(milliseconds: 400),
              childAnimationBuilder: (widget) => SlideAnimation(
                verticalOffset: 40,
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
                            decoration: BoxDecoration(shape: BoxShape.circle, color: cardBg),
                            child: Center(
                              child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(theme.colors.primary)),
                            ),
                          )
                        else
                          AquaAvatar(imageUrl: _photoUrl, name: _nameController.text, size: 90),
                        GlassIconButton(
                          icon: Icon(Icons.edit_rounded, color: isDark ? Colors.white : Colors.black, size: 16),
                          size: 34,
                          quality: GlassQuality.standard,
                          settings: isDark ? LiquidGlassSettings.ios27Dark : LiquidGlassSettings.ios27Light,
                          onPressed: _pickPhoto,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Name field
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
                          Icon(Icons.person_rounded, size: 16, color: theme.colors.primary),
                          const SizedBox(width: 8),
                          Text('DISPLAY NAME', style: TextStyle(color: textMuted, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _nameController,
                        style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Enter your name',
                          hintStyle: TextStyle(color: textMuted),
                          filled: true,
                          fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF4F4F5),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: cardBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.colors.primary, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Unique Username Field
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _usernameError != null ? AppColors.errorRed : cardBorder,
                      width: _usernameError != null ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.alternate_email_rounded, size: 16, color: theme.colors.primary),
                          const SizedBox(width: 8),
                          Text('UNIQUE USERNAME', style: TextStyle(color: textMuted, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5)),
                          const Spacer(),
                          if (_isCheckingUsername)
                            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          else if (_usernameController.text.isNotEmpty && _usernameError == null)
                            const Icon(Icons.check_circle_rounded, color: AppColors.onlineGreen, size: 18),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _usernameController,
                        onChanged: _onUsernameChanged,
                        style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 15),
                        decoration: InputDecoration(
                          prefixText: '@',
                          prefixStyle: TextStyle(color: theme.colors.primary, fontWeight: FontWeight.bold, fontSize: 15),
                          hintText: 'username',
                          hintStyle: TextStyle(color: textMuted),
                          filled: true,
                          fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF4F4F5),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _usernameError != null ? AppColors.errorRed : cardBorder,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _usernameError != null ? AppColors.errorRed : theme.colors.primary,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                      if (_usernameError != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.errorRed, size: 14),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _usernameError!,
                                style: const TextStyle(color: AppColors.errorRed, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        const SizedBox(height: 6),
                        Text(
                          'Other users can find and message you using this unique @username.',
                          style: TextStyle(color: textMuted, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Bio field
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
                          Icon(Icons.info_outline_rounded, size: 16, color: theme.colors.primary),
                          const SizedBox(width: 8),
                          Text('BIO / STATUS', style: TextStyle(color: textMuted, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _bioController,
                        style: TextStyle(color: textColor, fontSize: 14),
                        maxLines: 3,
                        maxLength: 150,
                        decoration: InputDecoration(
                          hintText: 'Tell contacts about yourself...',
                          hintStyle: TextStyle(color: textMuted),
                          counterStyle: TextStyle(color: textMuted),
                          filled: true,
                          fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF4F4F5),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: cardBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.colors.primary, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          'Available',
                          'E2EE Verified',
                          'Deep Work',
                          'Focus Mode',
                          'Sovereign',
                        ].map((suggestion) => InkWell(
                          onTap: () => setState(() => _bioController.text = suggestion),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : const Color(0xFFF4F4F5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: cardBorder),
                            ),
                            child: Text(
                              suggestion,
                              style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        )).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: (_isSaving || _usernameError != null) ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colors.primary,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 32),

                // Danger Zone / Delete Account Section
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('DANGER ZONE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: AppColors.errorRed)),
                ),
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
                      const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: AppColors.errorRed, size: 20),
                          SizedBox(width: 8),
                          Text('Permanently Delete Account', style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Deleting your account will permanently wipe all your messages, profile details, uploaded media, and cloud backups from Ripple. This action is real-time and irreversible.',
                        style: TextStyle(color: textMuted, fontSize: 12, height: 1.3),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton(
                          onPressed: _showDeleteAccountConfirmDialog,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.errorRed,
                            side: const BorderSide(color: AppColors.errorRed, width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Delete Account Permanently', style: TextStyle(fontWeight: FontWeight.bold)),
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
                side: BorderSide(color: AppColors.errorRed.withValues(alpha: 0.3)),
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
                    const Text('Account Deletion Consequences:', style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.bold, fontSize: 13)),
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
                          onChanged: isDeleting ? null : (val) => setDialogState(() => acceptedRules = val ?? false),
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
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
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

                          setDialogState(() => isDeleting = true);

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
                              setDialogState(() => isDeleting = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to delete account: $e'), backgroundColor: AppColors.errorRed),
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
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
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
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12))),
        ],
      ),
    );
  }
}
