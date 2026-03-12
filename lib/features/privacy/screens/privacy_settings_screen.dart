import 'package:flutter/material.dart';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/privacy_service.dart';

/// Full Privacy & Security settings screen.
class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  String _lastSeenVisibility = 'everyone';
  String _profilePhotoVisibility = 'everyone';
  String _bioVisibility = 'everyone';
  String _onlineStatusVisibility = 'everyone';
  bool _stealthMode = false;
  bool _readReceipts = true;
  bool _typingIndicator = true;
  bool _screenshotBlock = false;
  bool _incognitoKeyboard = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await PrivacyService.getPrivacySettings();
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;
    setState(() {
      _lastSeenVisibility =
          settings['lastSeenVisibility'] as String? ?? 'everyone';
      _profilePhotoVisibility =
          settings['profilePhotoVisibility'] as String? ?? 'everyone';
      _bioVisibility = settings['bioVisibility'] as String? ?? 'everyone';
      _onlineStatusVisibility =
          settings['onlineStatusVisibility'] as String? ?? 'everyone';
      _stealthMode = settings['stealthMode'] as bool? ?? false;
      _readReceipts = settings['readReceipts'] as bool? ?? true;
      _typingIndicator = settings['typingIndicator'] as bool? ?? true;
      _screenshotBlock = prefs.getBool('screenshot_block') ?? false;
      _incognitoKeyboard = prefs.getBool('incognito_keyboard') ?? false;
      _isLoading = false;
    });
  }

  Future<void> _updateSetting(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── HELPERS ────────────────────────────────────────────
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF0EA5E9),
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildVisibilityTile({
    required String title,
    required String subtitle,
    required String emoji,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF0EA5E9).withOpacity(0.1),
        ),
        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 18))),
      ),
      title: Text(title,
          style: const TextStyle(color: Colors.white, fontSize: 15)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: Colors.white54, fontSize: 12)),
      trailing: GestureDetector(
        onTap: () => _showVisibilityPicker(
          title: title,
          current: value,
          onSelected: onChanged,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF0EA5E9).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF0EA5E9).withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_visibilityLabel(value),
                  style: const TextStyle(
                    color: Color(0xFF0EA5E9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down,
                  color: Color(0xFF0EA5E9), size: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _visibilityLabel(String value) {
    switch (value) {
      case 'everyone':
        return 'Everyone';
      case 'friends':
        return 'Friends';
      case 'nobody':
        return 'Nobody';
      default:
        return 'Everyone';
    }
  }

  void _showVisibilityPicker({
    required String title,
    required String current,
    required ValueChanged<String> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A1628),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Who can see $title?',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...['everyone', 'friends', 'nobody'].map((option) => ListTile(
                  leading: Icon(
                    option == 'everyone'
                        ? Icons.public_rounded
                        : option == 'friends'
                            ? Icons.people_rounded
                            : Icons.lock_rounded,
                    color: current == option
                        ? const Color(0xFF0EA5E9)
                        : Colors.white54,
                  ),
                  title: Text(_visibilityLabel(option),
                      style: TextStyle(
                        color: current == option
                            ? const Color(0xFF0EA5E9)
                            : Colors.white,
                        fontWeight: current == option
                            ? FontWeight.bold
                            : FontWeight.normal,
                      )),
                  subtitle: Text(
                    option == 'everyone'
                        ? 'All Ripple users'
                        : option == 'friends'
                            ? 'Only your friends'
                            : 'No one can see this',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  trailing: current == option
                      ? const Icon(Icons.check_rounded,
                          color: Color(0xFF0EA5E9))
                      : null,
                  onTap: () {
                    onSelected(option);
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showSelfDestructPicker() {
    final options = [
      {'label': 'Off', 'seconds': 0},
      {'label': '5 seconds', 'seconds': 5},
      {'label': '10 seconds', 'seconds': 10},
      {'label': '30 seconds', 'seconds': 30},
      {'label': '1 minute', 'seconds': 60},
      {'label': '5 minutes', 'seconds': 300},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A1628),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('💣 Self-Destruct Timer',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Messages delete after recipient reads them',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 16),
            ...options.map((o) => ListTile(
                  title: Text(o['label'] as String,
                      style: const TextStyle(color: Colors.white)),
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt(
                        'default_self_destruct', o['seconds'] as int);
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(o['seconds'] == 0
                            ? '💣 Self-destruct off'
                            : '💣 Messages will delete after ${o['label']}'),
                      ));
                    }
                  },
                )),
          ],
        ),
      ),
    );
  }

  // ── BUILD ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        title: const Row(children: [
          Text('🔒', style: TextStyle(fontSize: 18)),
          SizedBox(width: 8),
          Text('Privacy & Security'),
        ]),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0EA5E9)))
          : ListView(
              children: [
                // ── WHO CAN SEE MY INFO ──────────────────
                _buildSectionHeader('👁  Who Can See My Info'),

                _buildVisibilityTile(
                  title: 'Last Seen',
                  subtitle: 'Control who sees when you were last active',
                  emoji: '🕐',
                  value: _lastSeenVisibility,
                  onChanged: (v) {
                    setState(() => _lastSeenVisibility = v);
                    _updateSetting(() => PrivacyService.updatePrivacySettings(
                        lastSeenVisibility: v));
                  },
                ),

                _buildVisibilityTile(
                  title: 'Profile Photo',
                  subtitle: 'Control who can see your profile picture',
                  emoji: '📷',
                  value: _profilePhotoVisibility,
                  onChanged: (v) {
                    setState(() => _profilePhotoVisibility = v);
                    _updateSetting(() => PrivacyService.updatePrivacySettings(
                        profilePhotoVisibility: v));
                  },
                ),

                _buildVisibilityTile(
                  title: 'Bio',
                  subtitle: 'Control who can read your bio',
                  emoji: '📝',
                  value: _bioVisibility,
                  onChanged: (v) {
                    setState(() => _bioVisibility = v);
                    _updateSetting(() => PrivacyService.updatePrivacySettings(
                        bioVisibility: v));
                  },
                ),

                _buildVisibilityTile(
                  title: 'Online Status',
                  subtitle: 'Control who sees when you are online',
                  emoji: '🟢',
                  value: _onlineStatusVisibility,
                  onChanged: (v) {
                    setState(() => _onlineStatusVisibility = v);
                    _updateSetting(() => PrivacyService.updatePrivacySettings(
                        onlineStatusVisibility: v));
                  },
                ),

                const Divider(color: Colors.white12),

                // ── STEALTH MODE ─────────────────────────
                _buildSectionHeader('👻  Stealth Mode'),

                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _stealthMode
                        ? const Color(0xFF6366F1).withOpacity(0.1)
                        : Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _stealthMode
                          ? const Color(0xFF6366F1).withOpacity(0.3)
                          : Colors.white12,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text('👻', style: TextStyle(fontSize: 32)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Stealth Mode',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              _stealthMode
                                  ? '👻 You are invisible to everyone'
                                  : 'Appear completely offline to all users. '
                                      'No last seen, no online status, no read receipts.',
                              style: TextStyle(
                                  color: _stealthMode
                                      ? const Color(0xFF6366F1)
                                      : Colors.white54,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _stealthMode,
                        onChanged: (v) {
                          setState(() => _stealthMode = v);
                          _updateSetting(() =>
                              PrivacyService.updatePrivacySettings(
                                stealthMode: v,
                                readReceipts: v ? false : _readReceipts,
                              ));
                          if (v) {
                            setState(() => _readReceipts = false);
                          }
                        },
                        activeColor: const Color(0xFF6366F1),
                      ),
                    ],
                  ),
                ),

                const Divider(color: Colors.white12),

                // ── MESSAGES ─────────────────────────────
                _buildSectionHeader('💬  Messages'),

                SwitchListTile(
                  value: _readReceipts,
                  onChanged: _stealthMode
                      ? null
                      : (v) {
                          setState(() => _readReceipts = v);
                          _updateSetting(() =>
                              PrivacyService.updatePrivacySettings(
                                  readReceipts: v));
                        },
                  title: Text('Read Receipts',
                      style: TextStyle(
                          color:
                              _stealthMode ? Colors.white38 : Colors.white)),
                  subtitle: Text(
                    _stealthMode
                        ? 'Disabled in Stealth Mode'
                        : 'Show blue ticks when you read messages',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  secondary: const Text('✓✓',
                      style: TextStyle(
                          color: Color(0xFF0EA5E9),
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  activeColor: const Color(0xFF0EA5E9),
                ),

                SwitchListTile(
                  value: _typingIndicator,
                  onChanged: _stealthMode
                      ? null
                      : (v) {
                          setState(() => _typingIndicator = v);
                          _updateSetting(() =>
                              PrivacyService.updatePrivacySettings(
                                  typingIndicator: v));
                        },
                  title: Text('Typing Indicator',
                      style: TextStyle(
                          color:
                              _stealthMode ? Colors.white38 : Colors.white)),
                  subtitle: const Text('Show when you are typing',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                  secondary:
                      const Text('⌨️', style: TextStyle(fontSize: 20)),
                  activeColor: const Color(0xFF0EA5E9),
                ),

                ListTile(
                  leading:
                      const Text('💣', style: TextStyle(fontSize: 20)),
                  title: const Text('Default Self-Destruct Timer',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text(
                      'Auto-delete messages after being read',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                  trailing: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Off',
                          style: TextStyle(color: Color(0xFF0EA5E9))),
                      Icon(Icons.chevron_right, color: Colors.white38),
                    ],
                  ),
                  onTap: _showSelfDestructPicker,
                ),

                const Divider(color: Colors.white12),

                // ── SECURITY ─────────────────────────────
                _buildSectionHeader('🔐  Security'),

                SwitchListTile(
                  value: _screenshotBlock,
                  onChanged: (v) async {
                    setState(() => _screenshotBlock = v);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('screenshot_block', v);
                    if (v) {
                      await FlutterWindowManagerPlus.addFlags(
                          FlutterWindowManagerPlus.FLAG_SECURE);
                    } else {
                      await FlutterWindowManagerPlus.clearFlags(
                          FlutterWindowManagerPlus.FLAG_SECURE);
                    }
                  },
                  title: const Text('Screenshot Block',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text(
                      'Prevent screenshots across the entire app',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                  secondary:
                      const Text('📵', style: TextStyle(fontSize: 20)),
                  activeColor: const Color(0xFF0EA5E9),
                ),

                SwitchListTile(
                  value: _incognitoKeyboard,
                  onChanged: (v) async {
                    setState(() => _incognitoKeyboard = v);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('incognito_keyboard', v);
                  },
                  title: const Text('Incognito Keyboard',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text(
                      'Prevent keyboard from learning your messages',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                  secondary:
                      const Text('⌨️', style: TextStyle(fontSize: 20)),
                  activeColor: const Color(0xFF0EA5E9),
                ),

                ListTile(
                  leading:
                      const Text('🔒', style: TextStyle(fontSize: 20)),
                  title: const Text('Chat Lock',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text(
                      'Lock specific chats with biometrics or PIN',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right,
                      color: Colors.white38),
                  onTap: () => context.push('/chat-lock-settings'),
                ),

                const Divider(color: Colors.white12),

                // ── ADVANCED ─────────────────────────────
                _buildSectionHeader('🎭  Advanced'),

                ListTile(
                  leading:
                      const Text('🎭', style: TextStyle(fontSize: 20)),
                  title: const Text('Fake Passcode',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text(
                      'Set a decoy passcode that opens a fake account',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: const Text('Advanced',
                            style: TextStyle(
                                color: Colors.orange, fontSize: 10)),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right,
                          color: Colors.white38),
                    ],
                  ),
                  onTap: () => context.push('/fake-passcode'),
                ),

                const SizedBox(height: 40),
              ],
            ),
    );
  }
}
