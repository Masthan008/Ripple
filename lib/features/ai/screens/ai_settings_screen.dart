import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';

/// AI Settings — toggle individual AI features on/off
class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  bool _smartRepliesEnabled = true;
  bool _spamDetectionEnabled = true;
  bool _autoTranslateEnabled = false;
  String _autoTranslateLang = 'English';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _smartRepliesEnabled = prefs.getBool('ai_smart_replies') ?? true;
      _spamDetectionEnabled = prefs.getBool('ai_spam_detection') ?? true;
      _autoTranslateEnabled = prefs.getBool('ai_auto_translate') ?? false;
      _autoTranslateLang = prefs.getString('ai_translate_lang') ?? 'English';
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        title: const Row(
          children: [
            Text('✨', style: TextStyle(fontSize: 18)),
            SizedBox(width: 8),
            Text('AI Features',
                style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        children: [
          _sectionHeader('Chat Assistance'),
          SwitchListTile(
            value: _smartRepliesEnabled,
            onChanged: (v) {
              setState(() => _smartRepliesEnabled = v);
              _saveSetting('ai_smart_replies', v);
            },
            title: const Text('Smart Replies',
                style: TextStyle(color: Colors.white)),
            subtitle: const Text('AI suggests replies to messages',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            secondary: const Text('✨', style: TextStyle(fontSize: 20)),
            activeColor: AppColors.aquaCore,
          ),
          SwitchListTile(
            value: _spamDetectionEnabled,
            onChanged: (v) {
              setState(() => _spamDetectionEnabled = v);
              _saveSetting('ai_spam_detection', v);
            },
            title: const Text('Spam Detection',
                style: TextStyle(color: Colors.white)),
            subtitle: const Text('Warns about suspicious messages',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            secondary: const Text('🛡️', style: TextStyle(fontSize: 20)),
            activeColor: AppColors.aquaCore,
          ),
          _sectionHeader('Translation'),
          SwitchListTile(
            value: _autoTranslateEnabled,
            onChanged: (v) {
              setState(() => _autoTranslateEnabled = v);
              _saveSetting('ai_auto_translate', v);
            },
            title: const Text('Auto Translate',
                style: TextStyle(color: Colors.white)),
            subtitle: const Text(
                'Auto-translate messages in foreign languages',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            secondary: const Text('🌍', style: TextStyle(fontSize: 20)),
            activeColor: AppColors.aquaCore,
          ),
          if (_autoTranslateEnabled)
            ListTile(
              leading: const Text('🗣️', style: TextStyle(fontSize: 20)),
              title: const Text('Target Language',
                  style: TextStyle(color: Colors.white)),
              trailing: DropdownButton<String>(
                value: _autoTranslateLang,
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
                    setState(() => _autoTranslateLang = lang);
                    _saveSetting('ai_translate_lang', lang);
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
                Text('ℹ️  About AI Features',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
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
