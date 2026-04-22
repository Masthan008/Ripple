import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_provider.dart';
import '../../../core/services/firebase_service.dart';
import '../../auth/providers/auth_provider.dart';

/// AI Settings — toggle individual AI features on/off
class AiSettingsScreen extends ConsumerWidget {
  const AiSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(rippleThemeProvider);
    final currentUser = ref.watch(currentUserProvider);
    final uid = currentUser.value?.uid;

    if (uid == null) {
      return Scaffold(
        backgroundColor: theme.colors.background,
        body: Center(
          child: CircularProgressIndicator(color: theme.colors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.colors.background,
      appBar: AppBar(
        backgroundColor: theme.colors.surface,
        title: Row(
          children: [
            Icon(Icons.auto_awesome, color: theme.colors.warning, size: 22),
            const SizedBox(width: 8),
            Text('AI Features',
                style: TextStyle(color: theme.colors.textPrimary, fontSize: 18)),
          ],
        ),
        iconTheme: IconThemeData(color: theme.colors.textPrimary),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseService.usersCollection.doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(color: theme.colors.primary),
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
              _sectionHeader('Chat Assistance', theme.colors.primary),
              SwitchListTile(
                value: smartRepliesEnabled,
                onChanged: (v) {
                  FirebaseService.usersCollection.doc(uid).update({
                    'aiSettings.smartRepliesEnabled': v,
                  });
                },
                title: Text('Smart Replies',
                    style: TextStyle(color: theme.colors.textPrimary)),
                subtitle: Text('AI suggests replies to messages',
                    style: TextStyle(color: theme.colors.textMuted, fontSize: 12)),
                secondary: Icon(Icons.auto_awesome, color: theme.colors.warning, size: 24),
                activeColor: theme.colors.primary,
              ),
              SwitchListTile(
                value: spamDetectionEnabled,
                onChanged: (v) {
                  FirebaseService.usersCollection.doc(uid).update({
                    'aiSettings.spamDetectionEnabled': v,
                  });
                },
                title: Text('Spam Detection',
                    style: TextStyle(color: theme.colors.textPrimary)),
                subtitle: Text('Warns about suspicious messages',
                    style: TextStyle(color: theme.colors.textMuted, fontSize: 12)),
                secondary: Icon(Icons.shield, color: theme.colors.success, size: 24),
                activeColor: theme.colors.primary,
              ),
              _sectionHeader('Translation', theme.colors.primary),
              SwitchListTile(
                value: autoTranslateEnabled,
                onChanged: (v) {
                  FirebaseService.usersCollection.doc(uid).update({
                    'aiSettings.autoTranslateEnabled': v,
                  });
                },
                title: Text('Auto Translate',
                    style: TextStyle(color: theme.colors.textPrimary)),
                subtitle: Text(
                    'Auto-translate messages in foreign languages',
                    style: TextStyle(color: theme.colors.textMuted, fontSize: 12)),
                secondary: Icon(Icons.translate, color: theme.colors.secondary, size: 24),
                activeColor: theme.colors.primary,
              ),
              if (autoTranslateEnabled)
                ListTile(
                  leading: Icon(Icons.language, color: theme.colors.accent, size: 24),
                  title: Text('Target Language',
                      style: TextStyle(color: theme.colors.textPrimary)),
                  trailing: DropdownButton<String>(
                    value: autoTranslateLang,
                    dropdownColor: theme.colors.surface,
                    style: TextStyle(color: theme.colors.primary),
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
                  color: theme.colors.glassSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colors.glassBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: theme.colors.primary, size: 18),
                        const SizedBox(width: 8),
                        Text('About AI Features',
                            style: TextStyle(
                                color: theme.colors.textPrimary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'AI features are powered by Claude AI. Each action uses '
                      'a small amount of API quota. Smart replies and spam '
                      'detection use the fastest model (Haiku) to minimise cost.',
                      style: TextStyle(
                          color: theme.colors.textMuted, fontSize: 13, height: 1.4),
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

  Widget _sectionHeader(String title, Color color) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(title,
            style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8)),
      );
}
