import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../shared/widgets/theme_glass_card.dart';
import '../../auth/providers/auth_provider.dart';

/// Upgraded AI Settings & Interactive Control Center
class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  final _testPromptController = TextEditingController();
  bool _isTesting = false;
  String? _testResult;

  @override
  void dispose() {
    _testPromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.4),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(
                Icons.psychology_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'AI Neural Center',
              style: TextStyle(
                color: theme.colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
              ),
            ),
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
          final toneFixerEnabled = aiSettings['toneFixerEnabled'] as bool? ?? true;
          final aiComposerEnabled = aiSettings['aiComposerEnabled'] as bool? ?? true;
          final messageExplainerEnabled = aiSettings['messageExplainerEnabled'] as bool? ?? true;
          final statusCaptionEnabled = aiSettings['statusCaptionEnabled'] as bool? ?? true;
          final voiceTranscriberEnabled = aiSettings['voiceTranscriberEnabled'] as bool? ?? true;

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              _sectionHeader('CHAT INTELLIGENCE', const Color(0xFF0EA5E9)),
              
              _buildFeatureTile(
                theme: theme,
                icon: Icons.psychology_rounded,
                iconColor: const Color(0xFF0EA5E9),
                title: 'Smart Replies',
                subtitle: 'AI generates instant, natural reply suggestions in chats',
                value: smartRepliesEnabled,
                onChanged: (v) => _updateSetting(uid, 'smartRepliesEnabled', v),
                onTest: () => _openSmartRepliesDemo(context),
              ),

              _buildFeatureTile(
                theme: theme,
                icon: Icons.verified_user_rounded,
                iconColor: const Color(0xFF10B981),
                title: 'Spam & Phishing Guard',
                subtitle: 'Real-time AI scanning for suspicious links and scams',
                value: spamDetectionEnabled,
                onChanged: (v) => _updateSetting(uid, 'spamDetectionEnabled', v),
                onTest: () => _openSpamGuardDemo(context),
              ),

              _buildFeatureTile(
                theme: theme,
                icon: Icons.draw_rounded,
                iconColor: const Color(0xFFF59E0B),
                title: 'Tone Reformatter',
                subtitle: 'Rewrite draft messages into Formal, Friendly, or Funny tones',
                value: toneFixerEnabled,
                onChanged: (v) => _updateSetting(uid, 'toneFixerEnabled', v),
                onTest: () => _openToneFixerDemo(context),
              ),

              _buildFeatureTile(
                theme: theme,
                icon: Icons.auto_fix_high_rounded,
                iconColor: const Color(0xFFEC4899),
                title: 'AI Message Composer',
                subtitle: 'Compose full messages automatically from quick prompts',
                value: aiComposerEnabled,
                onChanged: (v) => _updateSetting(uid, 'aiComposerEnabled', v),
                onTest: () => _openComposerDemo(context),
              ),

              _buildFeatureTile(
                theme: theme,
                icon: Icons.lightbulb_rounded,
                iconColor: const Color(0xFF14B8A6),
                title: 'Message Explainer',
                subtitle: 'Decode slang, hidden meanings, and implied emotional tone',
                value: messageExplainerEnabled,
                onChanged: (v) => _updateSetting(uid, 'messageExplainerEnabled', v),
                onTest: () => _openExplainerDemo(context),
              ),

              const SizedBox(height: 16),
              _sectionHeader('REAL-TIME TRANSLATION', const Color(0xFF8B5CF6)),

              _buildFeatureTile(
                theme: theme,
                icon: Icons.g_translate_rounded,
                iconColor: const Color(0xFF8B5CF6),
                title: 'Auto Translate',
                subtitle: 'Automatically translate incoming foreign messages',
                value: autoTranslateEnabled,
                onChanged: (v) => _updateSetting(uid, 'autoTranslateEnabled', v),
                onTest: () => _openTranslationDemo(context, autoTranslateLang),
              ),

              if (autoTranslateEnabled) ...[
                const SizedBox(height: 8),
                ThemeGlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.language_rounded, color: Color(0xFF06B6D4), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Target Language',
                              style: TextStyle(color: theme.colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            Text(
                              'Incoming messages will be translated into this language',
                              style: TextStyle(color: theme.colors.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      DropdownButton<String>(
                        value: autoTranslateLang,
                        dropdownColor: const Color(0xFF0F172A),
                        style: const TextStyle(color: Color(0xFF0EA5E9), fontWeight: FontWeight.bold),
                        underline: const SizedBox(),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF0EA5E9)),
                        items: [
                          'English', 'Hindi', 'Telugu', 'Tamil', 'Spanish',
                          'French', 'German', 'Japanese', 'Korean', 'Arabic',
                        ].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                        onChanged: (lang) {
                          if (lang != null) {
                            _updateSetting(uid, 'autoTranslateLang', lang);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              _sectionHeader('MEDIA & CREATIVE INTELLIGENCE', const Color(0xFF3B82F6)),

              _buildFeatureTile(
                theme: theme,
                icon: Icons.subtitles_rounded,
                iconColor: const Color(0xFFF97316),
                title: 'Status Caption Generator',
                subtitle: 'Generate viral, engaging captions for your media status updates',
                value: statusCaptionEnabled,
                onChanged: (v) => _updateSetting(uid, 'statusCaptionEnabled', v),
                onTest: () => _openCaptionDemo(context),
              ),

              _buildFeatureTile(
                theme: theme,
                icon: Icons.graphic_eq_rounded,
                iconColor: const Color(0xFF3B82F6),
                title: 'Voice Transcriber (Whisper AI)',
                subtitle: 'Transcribe incoming audio voice messages to text automatically',
                value: voiceTranscriberEnabled,
                onChanged: (v) => _updateSetting(uid, 'voiceTranscriberEnabled', v),
              ),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  void _updateSetting(String uid, String key, dynamic value) {
    FirebaseService.usersCollection.doc(uid).update({
      'aiSettings.$key': value,
    });
  }

  Widget _sectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildFeatureTile({
    required dynamic theme,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    VoidCallback? onTest,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ThemeGlassCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: iconColor.withValues(alpha: 0.3), width: 1.2),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: theme.colors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: theme.colors.textMuted,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch.adaptive(
                  value: value,
                  onChanged: onChanged,
                  activeColor: AppColors.aquaCore,
                  activeTrackColor: const Color(0x550EA5E9),
                ),
              ],
            ),
            if (value && onTest != null) ...[
              const SizedBox(height: 8),
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onTest,
                  icon: const Icon(Icons.play_arrow_rounded, size: 16, color: AppColors.aquaCore),
                  label: const Text(
                    'Try Live',
                    style: TextStyle(color: AppColors.aquaCore, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // LIVE DEMO MODALS FOR REAL-TIME TESTING
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  void _openSmartRepliesDemo(BuildContext context) {
    _showTestModal(
      context: context,
      title: 'Smart Replies Test',
      icon: Icons.psychology_rounded,
      iconColor: const Color(0xFF0EA5E9),
      defaultPrompt: 'Hey! Are we still meeting for lunch today at 1 PM?',
      actionLabel: 'Generate Smart Replies',
      onRun: (input) async {
        return await AiService.smartReplies(
          chatHistory: [
            {'role': 'other', 'text': input},
          ],
          myName: 'User',
          otherName: 'Friend',
        ).then((list) => list.map((e) => '• $e').join('\n'));
      },
    );
  }

  void _openSpamGuardDemo(BuildContext context) {
    _showTestModal(
      context: context,
      title: 'Spam & Phishing Guard Test',
      icon: Icons.verified_user_rounded,
      iconColor: const Color(0xFF10B981),
      defaultPrompt: 'CONGRATS! You won \$50,000! Click http://bit.ly/scam123 to claim instantly!',
      actionLabel: 'Scan for Spam',
      onRun: (input) async {
        final res = await AiService.detectSpam(
          messageText: input,
          isFromFriend: false,
          senderName: 'Unknown Sender',
        );
        return 'Is Spam: ${res.isSpam ? "YES 🚨" : "NO ✅"}\nConfidence: ${res.confidence}%\nReason: ${res.reason}';
      },
    );
  }

  void _openToneFixerDemo(BuildContext context) {
    _showTestModal(
      context: context,
      title: 'Tone Reformatter Test',
      icon: Icons.draw_rounded,
      iconColor: const Color(0xFFF59E0B),
      defaultPrompt: 'I cant make it to work today im feeling sick',
      actionLabel: 'Reformat to Formal',
      onRun: (input) async {
        return await AiService.fixTone(text: input, tone: 'formal');
      },
    );
  }

  void _openComposerDemo(BuildContext context) {
    _showTestModal(
      context: context,
      title: 'AI Message Composer Test',
      icon: Icons.auto_fix_high_rounded,
      iconColor: const Color(0xFFEC4899),
      defaultPrompt: 'Politely decline weekend party because of exams',
      actionLabel: 'Compose Message',
      onRun: (input) async {
        return await AiService.composeReply(
          instruction: input,
          chatHistory: [],
          myName: 'User',
          otherName: 'Friend',
        );
      },
    );
  }

  void _openExplainerDemo(BuildContext context) {
    _showTestModal(
      context: context,
      title: 'Message Explainer Test',
      icon: Icons.lightbulb_rounded,
      iconColor: const Color(0xFF14B8A6),
      defaultPrompt: 'That feature is fire no cap 💀 fr fr',
      actionLabel: 'Explain Message',
      onRun: (input) async {
        return await AiService.explainMessage(text: input, senderName: 'Alex');
      },
    );
  }

  void _openTranslationDemo(BuildContext context, String targetLang) {
    _showTestModal(
      context: context,
      title: 'Auto Translation Test ($targetLang)',
      icon: Icons.g_translate_rounded,
      iconColor: const Color(0xFF8B5CF6),
      defaultPrompt: 'Hello friend, welcome to Ripple instant messaging app!',
      actionLabel: 'Translate to $targetLang',
      onRun: (input) async {
        return await AiService.translateMessage(text: input, targetLanguage: targetLang);
      },
    );
  }

  void _openCaptionDemo(BuildContext context) {
    _showTestModal(
      context: context,
      title: 'Status Caption Generator Test',
      icon: Icons.subtitles_rounded,
      iconColor: const Color(0xFFF97316),
      defaultPrompt: 'Sunset at the beach with coffee',
      actionLabel: 'Generate Caption',
      onRun: (input) async {
        return await AiService.generateCaption(context: input, mood: 'relaxing');
      },
    );
  }

  void _showTestModal({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required String defaultPrompt,
    required String actionLabel,
    required Future<String> Function(String input) onRun,
  }) {
    _testPromptController.text = defaultPrompt;
    _testResult = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.15), shape: BoxShape.circle),
                        child: Icon(icon, color: iconColor, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Test Input:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _testPromptController,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: _isTesting
                          ? null
                          : () async {
                              setModalState(() => _isTesting = true);
                              try {
                                final result = await onRun(_testPromptController.text);
                                setModalState(() {
                                  _testResult = result;
                                  _isTesting = false;
                                });
                              } catch (e) {
                                setModalState(() {
                                  _testResult = 'Error: $e';
                                  _isTesting = false;
                                });
                              }
                            },
                      icon: _isTesting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.black)))
                          : const Icon(Icons.flash_on_rounded, size: 18),
                      label: Text(_isTesting ? 'Processing...' : actionLabel),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.aquaCore,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  if (_testResult != null) ...[
                    const SizedBox(height: 16),
                    const Text('Live AI Output:', style: TextStyle(color: AppColors.aquaCore, fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.aquaCore.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.aquaCore.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _testResult!,
                        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
