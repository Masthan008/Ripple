import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/firebase_service.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/aqua_avatar.dart';

/// Screen for joining a group via an invite code / deep link.
class JoinGroupScreen extends StatefulWidget {
  final String inviteCode;

  const JoinGroupScreen({
    super.key,
    required this.inviteCode,
  });

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  bool _isLoading = true;
  bool _isJoining = false;
  String? _error;
  Map<String, dynamic>? _groupData;
  String? _groupId;

  @override
  void initState() {
    super.initState();
    _lookupGroup();
  }

  Future<void> _lookupGroup() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('groups')
          .where('inviteCode', isEqualTo: widget.inviteCode)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = 'Invalid or expired invite link';
        });
        return;
      }

      setState(() {
        _isLoading = false;
        _groupId = snap.docs.first.id;
        _groupData = snap.docs.first.data();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to lookup group: $e';
      });
    }
  }

  Future<void> _joinGroup() async {
    if (_groupId == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isJoining = true);
    try {
      // Check if already a member
      final members = List<String>.from(_groupData?['members'] ?? []);
      if (members.contains(uid)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You are already in this group!')),
          );
          Navigator.pop(context);
        }
        return;
      }

      // Add user to group
      await FirebaseService.firestore
          .collection('groups')
          .doc(_groupId)
          .update({
        'members': FieldValue.arrayUnion([uid]),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Joined "${_groupData?['name']}"! 🎉')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isJoining = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Join Group', style: AppTextStyles.heading),
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator(color: AppColors.aquaCore)
            : _error != null
                ? _buildError()
                : _buildGroupPreview(),
      ),
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.link_off_rounded, color: Colors.white24, size: 64),
        const SizedBox(height: 16),
        Text(_error!, style: const TextStyle(color: Colors.white54, fontSize: 16)),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.glassPanel,
          ),
          child: const Text('Go Back'),
        ),
      ],
    );
  }

  Widget _buildGroupPreview() {
    final name = _groupData?['name'] ?? 'Group';
    final photoUrl = _groupData?['photoUrl'] as String?;
    final description = _groupData?['description'] as String?;
    final memberCount = (List.from(_groupData?['members'] ?? [])).length;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: GlassCard(
        borderRadius: 20,
        padding: const EdgeInsets.all(28),
        animateBlur: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AquaAvatar(imageUrl: photoUrl, name: name, size: 80),
            const SizedBox(height: 16),
            Text(name, style: AppTextStyles.heading),
            const SizedBox(height: 6),
            if (description != null && description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  description,
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                ),
              ),
            Text(
              '$memberCount member${memberCount > 1 ? "s" : ""}',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 28),

            // Join button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isJoining ? null : _joinGroup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.aquaCore,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isJoining
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                      )
                    : Text('Join Group',
                        style: AppTextStyles.button.copyWith(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
