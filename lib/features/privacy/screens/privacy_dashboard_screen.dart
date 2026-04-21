import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/privacy_service.dart';
import '../../auth/providers/auth_provider.dart';

/// Privacy Dashboard — centralized view of permissions and security score
class PrivacyDashboardScreen extends ConsumerWidget {
  const PrivacyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final uid = currentUser.value?.uid;

    if (uid == null) {
      return const Scaffold(
        backgroundColor: AppColors.abyssBackground,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.aquaCore),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        title: Row(
          children: [
            const Icon(Icons.security, color: AppColors.aquaCore, size: 22),
            const SizedBox(width: 8),
            const Text('Privacy Dashboard',
                style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseService.usersCollection.doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.aquaCore),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final privacy = data['privacy'] as Map<String, dynamic>? ?? {};
          
          final securityScore = _calculateSecurityScore(privacy);
          final permissions = _getActivePermissions(data, privacy);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Security Score Card
              _buildSecurityScoreCard(securityScore),
              const SizedBox(height: 20),
              
              // Active Permissions
              _sectionHeader('Active Permissions'),
              ...permissions.map((perm) => _permissionTile(perm)),
              const SizedBox(height: 20),
              
              // Privacy Settings Summary
              _sectionHeader('Privacy Settings'),
              _privacySettingTile(
                'Last Seen',
                privacy['lastSeenVisibility'] as String? ?? 'everyone',
                Icons.visibility,
              ),
              _privacySettingTile(
                'Online Status',
                privacy['onlineStatusVisibility'] as String? ?? 'everyone',
                Icons.online_prediction,
              ),
              _privacySettingTile(
                'Profile Photo',
                privacy['profilePhotoVisibility'] as String? ?? 'everyone',
                Icons.account_circle,
              ),
              _privacySettingTile(
                'Bio',
                privacy['bioVisibility'] as String? ?? 'everyone',
                Icons.info,
              ),
              const SizedBox(height: 20),
              
              // Stealth Mode Status
              _sectionHeader('Stealth Mode'),
              _stealthModeTile(privacy['stealthMode'] as bool? ?? false),
              const SizedBox(height: 20),
              
              // Locked Chats
              _sectionHeader('Locked Chats'),
              _buildLockedChatsSection(privacy['lockedChats'] as List<dynamic>? ?? []),
              const SizedBox(height: 20),
              
              // Security Tips
              _sectionHeader('Security Tips'),
              _buildSecurityTips(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSecurityScoreCard(int score) {
    final scoreColor = score >= 80 ? Colors.green : score >= 50 ? Colors.amber : Colors.red;
    final scoreText = score >= 80 ? 'Excellent' : score >= 50 ? 'Good' : 'Needs Improvement';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.aquaCore.withValues(alpha: 0.1),
            AppColors.aquaCyan.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.aquaCyan.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Text(
            'Security Score',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$score',
                style: TextStyle(
                  color: scoreColor,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                '/100',
                style: TextStyle(color: Colors.white54, fontSize: 20),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            scoreText,
            style: TextStyle(
              color: scoreColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  int _calculateSecurityScore(Map<String, dynamic> privacy) {
    int score = 50; // Base score

    // Privacy visibility settings
    if (privacy['lastSeenVisibility'] == 'nobody') score += 10;
    else if (privacy['lastSeenVisibility'] == 'friends') score += 5;

    if (privacy['onlineStatusVisibility'] == 'nobody') score += 10;
    else if (privacy['onlineStatusVisibility'] == 'friends') score += 5;

    if (privacy['profilePhotoVisibility'] == 'nobody') score += 10;
    else if (privacy['profilePhotoVisibility'] == 'friends') score += 5;

    if (privacy['bioVisibility'] == 'nobody') score += 10;
    else if (privacy['bioVisibility'] == 'friends') score += 5;

    // Stealth mode
    if (privacy['stealthMode'] == true) score += 10;

    // Read receipts
    if (privacy['readReceiptsEnabled'] == false) score += 5;

    return score.clamp(0, 100);
  }

  List<String> _getActivePermissions(Map<String, dynamic> data, Map<String, dynamic> privacy) {
    final permissions = <String>[];

    // Check various app permissions
    if (data['allowNotifications'] != false) {
      permissions.add('Notifications');
    }
    if (data['allowCamera'] != false) {
      permissions.add('Camera Access');
    }
    if (data['allowMicrophone'] != false) {
      permissions.add('Microphone Access');
    }
    if (data['allowLocation'] != false) {
      permissions.add('Location Access');
    }
    if (data['allowContacts'] != false) {
      permissions.add('Contacts Access');
    }

    return permissions;
  }

  Widget _permissionTile(String permission) {
    return ListTile(
      leading: const Icon(Icons.check_circle, color: Colors.green, size: 20),
      title: Text(
        permission,
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: const Text('Active', style: TextStyle(color: Colors.white54, fontSize: 12)),
    );
  }

  Widget _privacySettingTile(String label, String visibility, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: AppColors.aquaCore, size: 20),
      title: Text(
        label,
        style: const TextStyle(color: Colors.white),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.glassPanel,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          visibility,
          style: const TextStyle(
            color: AppColors.aquaCore,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _stealthModeTile(bool isEnabled) {
    return ListTile(
      leading: Icon(
        Icons.shield,
        color: isEnabled ? Colors.green : Colors.grey,
        size: 20,
      ),
      title: const Text(
        'Stealth Mode',
        style: TextStyle(color: Colors.white),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isEnabled ? Colors.green.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          isEnabled ? 'Enabled' : 'Disabled',
          style: TextStyle(
            color: isEnabled ? Colors.green : Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityTips() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glassPanel,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb, color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              Text(
                'Security Tips',
                style: AppTextStyles.headingSmall.copyWith(fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '• Enable Stealth Mode to hide your online status\n'
            '• Set Last Seen to "nobody" for maximum privacy\n'
            '• Disable read receipts to prevent others from seeing when you read messages\n'
            '• Regularly review your active permissions',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedChatsSection(List<dynamic> lockedChats) {
    if (lockedChats.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.lock_open, color: Colors.white54, size: 20),
            SizedBox(width: 12),
            Text(
              'No locked chats',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock, color: AppColors.aquaCore, size: 20),
              const SizedBox(width: 8),
              Text(
                '${lockedChats.length} locked chat${lockedChats.length > 1 ? 's' : ''}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...lockedChats.map((chatId) {
            return Padding(
              padding: const EdgeInsets.only(left: 28, top: 4),
              child: Text(
                '• Chat ID: ${(chatId as String).substring(0, 8)}...',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
        child: Text(
          title,
          style: TextStyle(
            color: AppColors.aquaCore,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      );
}
