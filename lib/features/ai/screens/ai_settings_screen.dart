import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/firebase_service.dart';
import '../../auth/providers/auth_provider.dart';

/// AI Settings — toggle individual AI features on/off
class AiSettingsScreen extends ConsumerWidget {
  const AiSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final uid = currentUser.value?.uid;

    if (uid == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF060D1A),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.aquaCore),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF060D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.amber, size: 22),
            const SizedBox(width: 8),
            const Text('AI Features',
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
          final aiSettings = data['aiSettings'] as Map<String, dynamic>? ?? {};
          final smartRepliesEnabled = aiSettings['smartRepliesEnabled'] as bool? ?? true;
          final spamDetectionEnabled = aiSettings['spamDetectionEnabled'] as bool? ?? true;
          final autoTranslateEnabled = aiSettings['autoTranslateEnabled'] as bool? ?? false;
          final autoTranslateLang = aiSettings['autoTranslateLang'] as String? ?? 'English';

          return ListView(
            children: [
              _sectionHeader('Chat Assistance'),
              SwitchListTile(
                value: smartRepliesEnabled,
                onChanged: (v) {
                  FirebaseService.usersCollection.doc(uid).update({
                    'aiSettings.smartRepliesEnabled': v,
                  });
                },
                title: const Text('Smart Replies',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text('AI suggests replies to messages',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                secondary: const Icon(Icons.auto_awesome, color: Colors.amber, size: 24),
                activeThumbColor: AppColors.aquaCore,
              ),
              SwitchListTile(
                value: spamDetectionEnabled,
                onChanged: (v) {
                  FirebaseService.usersCollection.doc(uid).update({
                    'aiSettings.spamDetectionEnabled': v,
                  });
                },
                title: const Text('Spam Detection',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text('Warns about suspicious messages',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                secondary: const Icon(Icons.shield, color: Colors.green, size: 24),
                activeThumbColor: AppColors.aquaCore,
              ),
              _sectionHeader('Translation'),
              SwitchListTile(
                value: autoTranslateEnabled,
                onChanged: (v) {
                  FirebaseService.usersCollection.doc(uid).update({
                    'aiSettings.autoTranslateEnabled': v,
                  });
                },
                title: const Text('Auto Translate',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text(
                    'Auto-translate messages in foreign languages',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                secondary: const Icon(Icons.translate, color: Colors.blue, size: 24),
                activeThumbColor: AppColors.aquaCore,
              ),
              if (autoTranslateEnabled)
                ListTile(
                  leading: const Icon(Icons.language, color: Colors.purple, size: 24),
                  title: const Text('Target Language',
                      style: TextStyle(color: Colors.white)),
                  trailing: DropdownButton<String>(
                    value: autoTranslateLang,
                    dropdownColor: const Color(0xFF0A1628),
                    style: TextStyle(color: AppColors.aquaCore),
                    underline: const SizedBox(),
                    items: [
                      'English', 'Hindi', 'Telugu', 'Tamil', 'Spanish',
                      'French', 'German', 'Japanese', 'Korean', 'Arabic',
                    ]
                        .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                        .toList(),
                    onChanged: (lang) {
                      if (lang != null) {
                        FirebaseService.usersCollection.doc(uid).update({
                          'aiSettings.autoTranslateLang': lang,
                        });
                      }
                    },
                  ),
                ),
              const SizedBox(height: 24),
              // API usage note
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.aquaCore, size: 18),
                        SizedBox(width: 8),
                        Text('About AI Features',
                            style: TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'AI features are powered by Claude AI. Each action uses '
                      'a small amount of API quota. Smart replies and spam '
                      'detection use the fastest model (Haiku) to minimise cost.',
                      style: TextStyle(
                          color: Colors.white54, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(title,
            style: TextStyle(
                color: AppColors.aquaCore,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8)),
      );
}
