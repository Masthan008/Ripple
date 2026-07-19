import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/privacy_service.dart';
import '../../chat/providers/gaze_privacy_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/app_colors.dart';

/// Full Privacy & Security settings screen.
class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  String _lastSeenVisibility = 'everyone';
  String _profilePhotoVisibility = 'everyone';
  String _bioVisibility = 'everyone';
  String _onlineStatusVisibility = 'everyone';
  bool _stealthMode = false;
  bool _readReceipts = true;
  bool _typingIndicator = true;
  bool _screenshotBlock = false;
  bool _incognitoKeyboard = false;
  bool _sonicWhispersEnabled = true;
  double _sonicDecibelThreshold = 60.0;
  bool _silenceUnknownCallers = false;
  bool _ipProtection = false;
  String _groupAddVisibility = 'everyone';
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
      _sonicWhispersEnabled = prefs.getBool('sonic_whispers_enabled') ?? true;
      _sonicDecibelThreshold = prefs.getDouble('sonic_decibel_threshold') ?? 60.0;
      _silenceUnknownCallers = settings['silenceUnknownCallers'] as bool? ?? false;
      _ipProtection = settings['ipProtection'] as bool? ?? false;
      _groupAddVisibility = settings['groupAddVisibility'] as String? ?? 'everyone';
      _isLoading = false;
    });
  }

  Future<void> _updateSetting(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: $e'),
            backgroundColor: Colors.red,
          ),
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
    required IconData icon,
    required String value,
    required ValueChanged<String>? onChanged,
  }) {
    final isDisabled = onChanged == null;

    return ListTile(
      enabled: !isDisabled,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              isDisabled
                  ? Colors.white10
                  : const Color(0xFF0EA5E9).withOpacity(0.1),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 20,
            color: isDisabled ? Colors.white24 : const Color(0xFF0EA5E9),
          ),
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDisabled ? Colors.white38 : Colors.white,
          fontSize: 15,
          fontWeight: isDisabled ? FontWeight.normal : FontWeight.w600,
        ),
      ),
      subtitle: Text(
        isDisabled ? 'Disabled in Stealth Mode' : subtitle,
        style: const TextStyle(color: Colors.white38, fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isDisabled ? 'Nobody' : _visibilityLabel(value),
            style: TextStyle(
              color: isDisabled ? Colors.white24 : const Color(0xFF0EA5E9),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right,
            color: isDisabled ? Colors.white10 : Colors.white38,
            size: 18,
          ),
        ],
      ),
      onTap:
          isDisabled
              ? null
              : () => _showVisibilityPicker(
                title: title,
                current: value,
                onSelected: onChanged,
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
    required ValueChanged<String>? onSelected,
  }) {
    if (onSelected == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A1628),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (_) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Who can see $title?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...['everyone', 'friends', 'nobody'].map(
                  (option) => ListTile(
                    leading: Icon(
                      option == 'everyone'
                          ? Icons.public_rounded
                          : option == 'friends'
                          ? Icons.people_rounded
                          : Icons.lock_rounded,
                      color:
                          current == option
                              ? const Color(0xFF0EA5E9)
                              : Colors.white54,
                    ),
                    title: Text(
                      _visibilityLabel(option),
                      style: TextStyle(
                        color:
                            current == option
                                ? const Color(0xFF0EA5E9)
                                : Colors.white,
                        fontWeight:
                            current == option
                                ? FontWeight.bold
                                : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      option == 'everyone'
                          ? 'All Ripple users'
                          : option == 'friends'
                          ? 'Only your friends'
                          : 'No one can see this',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                    trailing:
                        current == option
                            ? const Icon(
                              Icons.check_rounded,
                              color: Color(0xFF0EA5E9),
                            )
                            : null,
                    onTap: () {
                      onSelected(option);
                      Navigator.pop(context);
                    },
                  ),
                ),
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
      builder:
          (_) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.timer_off_rounded, color: Color(0xFF0EA5E9), size: 20),
                    SizedBox(width: 8),
                    Text('Self-Destruct Timer',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Messages delete after recipient reads them',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ...options.map(
                  (o) => ListTile(
                    title: Text(
                      o['label'] as String,
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setInt(
                        'default_self_destruct',
                        o['seconds'] as int,
                      );
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              o['seconds'] == 0
                                  ? 'Self-destruct off'
                                  : 'Messages will delete after ${o['label']}',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }

  void _showUpgradeRequiredDialog(BuildContext context, {required String title, required String message}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.glassBorder),
        ),
        title: Row(
          children: [
            const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFBBF24)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.aquaCore,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              context.push('/plans');
            },
            child: const Text('Upgrade Now', style: TextStyle(color: Colors.white)),
          ),
        ],
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
        title: const Row(
          children: [
            Icon(Icons.security_rounded, color: Color(0xFF0EA5E9), size: 22),
            SizedBox(width: 8),
            Text('Privacy & Security'),
          ],
        ),
        foregroundColor: Colors.white,
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF0EA5E9)),
              )
              : ListView(
                children: [
                  // ── WHO CAN SEE MY INFO ──────────────────
                  _buildSectionHeader('Who Can See My Info'),

                  _buildVisibilityTile(
                    title: 'Last Seen',
                    subtitle: 'Control who sees when you were last active',
                    icon: Icons.schedule_rounded,
                    value: _lastSeenVisibility,
                    onChanged:
                        _stealthMode
                            ? null
                            : (v) {
                              setState(() => _lastSeenVisibility = v);
                              _updateSetting(
                                () => PrivacyService.updatePrivacySettings(
                                  lastSeenVisibility: v,
                                ),
                              );
                            },
                  ),

                  _buildVisibilityTile(
                    title: 'Profile Photo',
                    subtitle: 'Control who can see your profile picture',
                    icon: Icons.photo_camera_rounded,
                    value: _profilePhotoVisibility,
                    onChanged:
                        _stealthMode
                            ? null
                            : (v) {
                              setState(() => _profilePhotoVisibility = v);
                              _updateSetting(
                                () => PrivacyService.updatePrivacySettings(
                                  profilePhotoVisibility: v,
                                ),
                              );
                            },
                  ),

                  _buildVisibilityTile(
                    title: 'Bio',
                    subtitle: 'Control who can read your bio',
                    icon: Icons.edit_note_rounded,
                    value: _bioVisibility,
                    onChanged:
                        _stealthMode
                            ? null
                            : (v) {
                              setState(() => _bioVisibility = v);
                              _updateSetting(
                                () => PrivacyService.updatePrivacySettings(
                                  bioVisibility: v,
                                ),
                              );
                            },
                  ),

                  _buildVisibilityTile(
                    title: 'Online Status',
                    subtitle: 'Control who sees when you are online',
                    icon: Icons.circle_rounded,
                    value: _onlineStatusVisibility,
                    onChanged:
                        _stealthMode
                            ? null
                            : (v) {
                              setState(() => _onlineStatusVisibility = v);
                              _updateSetting(
                                () => PrivacyService.updatePrivacySettings(
                                  onlineStatusVisibility: v,
                                ),
                              );
                            },
                  ),

                  const Divider(color: Colors.white12),

                  // ── STEALTH MODE ─────────────────────────
                  _buildSectionHeader('Stealth Mode'),

                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:
                          _stealthMode
                              ? const Color(0xFF6366F1).withOpacity(0.1)
                              : Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            _stealthMode
                                ? const Color(0xFF6366F1).withOpacity(0.3)
                                : Colors.white12,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.visibility_off_rounded, color: Color(0xFF6366F1), size: 32),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Stealth Mode',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _stealthMode
                                    ? 'You are invisible to everyone'
                                    : 'Appear completely offline to all users. '
                                        'No last seen, no online status, no read receipts.',
                                style: TextStyle(
                                  color:
                                      _stealthMode
                                          ? const Color(0xFF6366F1)
                                          : Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _stealthMode,
                          onChanged: (v) {
                            setState(() => _stealthMode = v);
                            _updateSetting(
                              () => PrivacyService.updatePrivacySettings(
                                stealthMode: v,
                                readReceipts: v ? false : _readReceipts,
                              ),
                            );
                            if (v) {
                              setState(() => _readReceipts = false);
                            }
                          },
                          activeThumbColor: const Color(0xFF6366F1),
                        ),
                      ],
                    ),
                  ),

                  const Divider(color: Colors.white12),

                  // ── MESSAGES ─────────────────────────────
                  _buildSectionHeader('Messages'),

                  SwitchListTile(
                    value: _readReceipts,
                    onChanged:
                        _stealthMode
                            ? null
                            : (v) {
                              setState(() => _readReceipts = v);
                              _updateSetting(
                                () => PrivacyService.updatePrivacySettings(
                                  readReceipts: v,
                                ),
                              );
                            },
                    title: Text(
                      'Read Receipts',
                      style: TextStyle(
                        color: _stealthMode ? Colors.white38 : Colors.white,
                      ),
                    ),
                    subtitle: Text(
                      _stealthMode
                          ? 'Disabled in Stealth Mode'
                          : 'Show blue ticks when you read messages',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                    secondary: const Icon(
                      Icons.done_all_rounded,
                      color: Color(0xFF0EA5E9),
                      size: 24,
                    ),
                    activeThumbColor: const Color(0xFF0EA5E9),
                  ),

                  SwitchListTile(
                    value: _typingIndicator,
                    onChanged:
                        _stealthMode
                            ? null
                            : (v) {
                              setState(() => _typingIndicator = v);
                              _updateSetting(
                                () => PrivacyService.updatePrivacySettings(
                                  typingIndicator: v,
                                ),
                              );
                            },
                    title: Text(
                      'Typing Indicator',
                      style: TextStyle(
                        color: _stealthMode ? Colors.white38 : Colors.white,
                      ),
                    ),
                    subtitle: const Text(
                      'Show when you are typing',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    secondary: const Icon(Icons.keyboard_rounded, color: Color(0xFF0EA5E9), size: 24),
                    activeThumbColor: const Color(0xFF0EA5E9),
                  ),

                  ListTile(
                    leading: const Icon(Icons.timer_off_rounded, color: Color(0xFF0EA5E9), size: 24),
                    title: const Text(
                      'Default Self-Destruct Timer',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'Auto-delete messages after being read',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    trailing: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Off', style: TextStyle(color: Color(0xFF0EA5E9))),
                        Icon(Icons.chevron_right, color: Colors.white38),
                      ],
                    ),
                    onTap: _showSelfDestructPicker,
                  ),

                  const Divider(color: Colors.white12),

                  // ── SECURITY ─────────────────────────────
                  _buildSectionHeader('Security'),

                  ListTile(
                    leading: const Icon(Icons.dashboard_rounded, color: Color(0xFF0EA5E9), size: 24),
                    title: const Text(
                      'Privacy Dashboard',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'View security score and locked chats',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                    onTap: () => context.push('/privacy-dashboard'),
                  ),

                  SwitchListTile(
                    value: _screenshotBlock,
                    onChanged: (v) async {
                      setState(() => _screenshotBlock = v);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('screenshot_block', v);
                      if (v) {
                        await FlutterWindowManagerPlus.addFlags(
                          FlutterWindowManagerPlus.FLAG_SECURE,
                        );
                      } else {
                        await FlutterWindowManagerPlus.clearFlags(
                          FlutterWindowManagerPlus.FLAG_SECURE,
                        );
                      }
                    },
                    title: const Text(
                      'Screenshot Block',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'Prevent screenshots across the entire app',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    secondary: const Icon(Icons.screenshot_monitor_outlined, color: Color(0xFF0EA5E9), size: 24),
                    activeThumbColor: const Color(0xFF0EA5E9),
                  ),

                  SwitchListTile(
                    value: _incognitoKeyboard,
                    onChanged: (v) async {
                      setState(() => _incognitoKeyboard = v);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('incognito_keyboard', v);
                    },
                    title: const Text(
                      'Incognito Keyboard',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'Prevent keyboard from learning your messages',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    secondary: const Icon(Icons.keyboard_hide_rounded, color: Color(0xFF0EA5E9), size: 24),
                    activeThumbColor: const Color(0xFF0EA5E9),
                  ),

                  ListTile(
                    leading: const Icon(Icons.lock_rounded, color: Color(0xFF0EA5E9), size: 24),
                    title: const Text(
                      'Chat Lock',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'Lock specific chats with biometrics or PIN',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.white38,
                    ),
                    onTap: () => context.push('/chat-lock-settings'),
                  ),

                  const Divider(color: Colors.white12),

                  // ── RIPPLE TELEPATHY™ ─────────────────
                  _buildSectionHeader('Ripple Telepathy™'),

                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF0EA5E9).withOpacity(
                            ref.watch(telepathyEnabledProvider) ? 0.15 : 0.03,
                          ),
                          const Color(0xFF6366F1).withOpacity(
                            ref.watch(telepathyEnabledProvider) ? 0.1 : 0.02,
                          ),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: ref.watch(telepathyEnabledProvider)
                            ? const Color(0xFF0EA5E9).withOpacity(0.4)
                            : Colors.white12,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF0EA5E9).withOpacity(0.3),
                                const Color(0xFF6366F1).withOpacity(0.3),
                              ],
                            ),
                          ),
                          child: const Icon(
                            Icons.remove_red_eye_rounded,
                            color: Color(0xFF0EA5E9),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Gaze Lock',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0EA5E9).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'NEW',
                                      style: TextStyle(
                                        color: Color(0xFF0EA5E9),
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                ref.watch(telepathyEnabledProvider)
                                    ? 'Messages blur until you look at them.'
                                    : 'Messages auto-blur unless you\'re looking at the screen.',
                                style: TextStyle(
                                  color: ref.watch(telepathyEnabledProvider)
                                      ? const Color(0xFF0EA5E9)
                                      : Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: ref.watch(telepathyEnabledProvider),
                          onChanged: (_) {
                            final currentUser = ref.read(currentUserProvider).value;
                            final plan = currentUser?.subscriptionPlan ?? '';
                            if (plan != 'Premium Trial' && plan != 'Abyss Platinum') {
                              _showUpgradeRequiredDialog(
                                context,
                                title: 'Abyss Platinum Required',
                                message: 'Ripple Telepathy eye-tracking, gaze privacy, and auto-blur features are exclusive Abyss Platinum benefits. Upgrade to Abyss Platinum or activate the Free Trial to unlock this revolutionary privacy shield!',
                              );
                              return;
                            }
                            ref.read(telepathyEnabledProvider.notifier).toggle();
                          },
                          activeThumbColor: const Color(0xFF0EA5E9),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Anti-Shoulder Surfing — separate toggle
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFEF4444).withOpacity(
                            ref.watch(antiShoulderSurfingEnabledProvider) ? 0.15 : 0.03,
                          ),
                          const Color(0xFF6366F1).withOpacity(
                            ref.watch(antiShoulderSurfingEnabledProvider) ? 0.1 : 0.02,
                          ),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: ref.watch(antiShoulderSurfingEnabledProvider)
                            ? const Color(0xFFEF4444).withOpacity(0.4)
                            : Colors.white12,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFEF4444).withOpacity(0.3),
                                const Color(0xFF6366F1).withOpacity(0.3),
                              ],
                            ),
                          ),
                          child: const Icon(
                            Icons.shield_rounded,
                            color: Color(0xFFEF4444),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Anti-Shoulder Surfing',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'NEW',
                                      style: TextStyle(
                                        color: Color(0xFFEF4444),
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                ref.watch(antiShoulderSurfingEnabledProvider)
                                    ? 'Screen blurs instantly when someone looks over your shoulder.'
                                    : 'Detects if someone else is looking at your screen and hides messages.',
                                style: TextStyle(
                                  color: ref.watch(antiShoulderSurfingEnabledProvider)
                                      ? const Color(0xFFEF4444)
                                      : Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: ref.watch(antiShoulderSurfingEnabledProvider),
                          onChanged: (_) {
                            final currentUser = ref.read(currentUserProvider).value;
                            final plan = currentUser?.subscriptionPlan ?? '';
                            if (plan != 'Premium Trial' && plan != 'Abyss Platinum') {
                              _showUpgradeRequiredDialog(
                                context,
                                title: 'Abyss Platinum Required',
                                message: 'Anti-Shoulder Surfing screen protection is an exclusive Abyss Platinum benefit. Upgrade to Abyss Platinum or activate the Free Trial to unlock this revolutionary privacy shield!',
                              );
                              return;
                            }
                            ref.read(antiShoulderSurfingEnabledProvider.notifier).toggle();
                          },
                          activeThumbColor: const Color(0xFFEF4444),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Divider(color: Colors.white12),

                  // ── SONIC WHISPERS™ ───────────────────
                  _buildSectionHeader('Sonic Whispers™'),

                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF10B981).withOpacity(
                            _sonicWhispersEnabled ? 0.12 : 0.03,
                          ),
                          const Color(0xFF0EA5E9).withOpacity(
                            _sonicWhispersEnabled ? 0.08 : 0.02,
                          ),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _sonicWhispersEnabled
                            ? const Color(0xFF10B981).withOpacity(0.4)
                            : Colors.white12,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF10B981).withOpacity(0.3),
                                    const Color(0xFF0EA5E9).withOpacity(0.3),
                                  ],
                                ),
                              ),
                              child: const Icon(
                                Icons.hearing_rounded,
                                color: Color(0xFF10B981),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'Ambient Voice Notes',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'NEW',
                                          style: TextStyle(
                                            color: Color(0xFF10B981),
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _sonicWhispersEnabled
                                        ? 'Auto-transcribes voice notes in noisy environments. '
                                          'Shows large text when it\'s loud around you.'
                                        : 'Detect ambient noise levels and auto-transcribe '
                                          'voice messages when your environment is loud.',
                                    style: TextStyle(
                                      color: _sonicWhispersEnabled
                                          ? const Color(0xFF10B981)
                                          : Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _sonicWhispersEnabled,
                              onChanged: (v) async {
                                setState(() => _sonicWhispersEnabled = v);
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.setBool('sonic_whispers_enabled', v);
                              },
                              activeThumbColor: const Color(0xFF10B981),
                            ),
                          ],
                        ),
                        // Decibel threshold slider
                        if (_sonicWhispersEnabled) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(
                                Icons.volume_down_rounded,
                                color: Color(0xFF10B981),
                                size: 18,
                              ),
                              Expanded(
                                child: Slider(
                                  value: _sonicDecibelThreshold,
                                  min: 40,
                                  max: 80,
                                  divisions: 8,
                                  label: '${_sonicDecibelThreshold.round()} dB',
                                  activeColor: const Color(0xFF10B981),
                                  inactiveColor: Colors.white12,
                                  onChanged: (v) {
                                    setState(() => _sonicDecibelThreshold = v);
                                  },
                                  onChangeEnd: (v) async {
                                    final prefs = await SharedPreferences.getInstance();
                                    await prefs.setDouble('sonic_decibel_threshold', v);
                                  },
                                ),
                              ),
                              const Icon(
                                Icons.volume_up_rounded,
                                color: Color(0xFF10B981),
                                size: 18,
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Noise threshold: ${_sonicDecibelThreshold.round()} dB — '
                              '${_sonicDecibelThreshold <= 50 ? 'Very Sensitive (library)' : _sonicDecibelThreshold <= 60 ? 'Normal (office)' : _sonicDecibelThreshold <= 70 ? 'Moderate (street)' : 'Low Sensitivity (concert)'}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Divider(color: Colors.white12),

                  // ── ADVANCED ─────────────────────────────
                  _buildSectionHeader('Advanced'),

                  ListTile(
                    leading: const Icon(Icons.theater_comedy_rounded, color: Colors.orange, size: 24),
                    title: const Text(
                      'Fake Passcode',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'Set a decoy passcode that opens a fake account',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.3),
                            ),
                          ),
                          child: const Text(
                            'Advanced',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, color: Colors.white38),
                      ],
                    ),
                    onTap: () => context.push('/fake-passcode'),
                  ),

                  const Divider(color: Colors.white12),

                  // ── GROUPS ─────────────────────────────
                  _buildSectionHeader('Groups'),

                  _buildVisibilityTile(
                    title: 'Who Can Add Me to Groups',
                    subtitle: 'Control who can add you to group chats',
                    icon: Icons.group_add_rounded,
                    value: _groupAddVisibility,
                    onChanged: (v) {
                      setState(() => _groupAddVisibility = v);
                      _updateSetting(
                        () => PrivacyService.updatePrivacySettings(
                          groupAddVisibility: v,
                        ),
                      );
                    },
                  ),

                  const Divider(color: Colors.white12),

                  // ── CALLS ──────────────────────────────
                  _buildSectionHeader('Calls'),

                  SwitchListTile(
                    value: _silenceUnknownCallers,
                    onChanged: (v) {
                      setState(() => _silenceUnknownCallers = v);
                      _updateSetting(
                        () => PrivacyService.updatePrivacySettings(
                          silenceUnknownCallers: v,
                        ),
                      );
                    },
                    title: const Text(
                      'Silence Unknown Callers',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'Calls from people not in your contacts will be silenced',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    secondary: const Icon(
                      Icons.phone_disabled_rounded,
                      color: Color(0xFF0EA5E9),
                      size: 24,
                    ),
                    activeThumbColor: const Color(0xFF0EA5E9),
                  ),

                  SwitchListTile(
                    value: _ipProtection,
                    onChanged: (v) {
                      setState(() => _ipProtection = v);
                      _updateSetting(
                        () => PrivacyService.updatePrivacySettings(
                          ipProtection: v,
                        ),
                      );
                    },
                    title: const Text(
                      'Protect IP Address in Calls',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'Relay calls through Ripple servers to hide your IP address',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    secondary: const Icon(
                      Icons.vpn_lock_rounded,
                      color: Color(0xFF0EA5E9),
                      size: 24,
                    ),
                    activeThumbColor: const Color(0xFF0EA5E9),
                  ),

                  const Divider(color: Colors.white12),

                  // ── BLOCKED CONTACTS & APP LOCK ─────────
                  _buildSectionHeader('Account'),

                  ListTile(
                    leading: const Icon(Icons.block_rounded, color: Colors.redAccent, size: 24),
                    title: const Text(
                      'Blocked Contacts',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'View and manage blocked users',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                    onTap: () => context.push('/blocked-contacts'),
                  ),

                  ListTile(
                    leading: const Icon(Icons.fingerprint_rounded, color: Color(0xFF0EA5E9), size: 24),
                    title: const Text(
                      'App Lock',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'Require fingerprint or PIN to open Ripple',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                    onTap: () => context.push('/app-lock-settings'),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
    );
  }
}
