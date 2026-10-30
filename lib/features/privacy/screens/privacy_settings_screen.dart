import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/privacy_service.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/haptic_feedback.dart';

/// Full Privacy & Security settings screen — Modern, Theme-Aware & Unified.
class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  String _lastSeenVisibility = 'everyone';
  String _profilePhotoVisibility = 'everyone';
  String _bioVisibility = 'everyone';
  bool _readReceipts = true;
  bool _typingIndicator = true;
  bool _screenshotBlock = false;
  bool _incognitoKeyboard = false;
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
      _lastSeenVisibility = settings['lastSeenVisibility'] as String? ?? 'everyone';
      _profilePhotoVisibility = settings['profilePhotoVisibility'] as String? ?? 'everyone';
      _bioVisibility = settings['bioVisibility'] as String? ?? 'everyone';
      _readReceipts = settings['readReceipts'] as bool? ?? true;
      _typingIndicator = settings['typingIndicator'] as bool? ?? true;
      _screenshotBlock = prefs.getBool('screenshot_block') ?? false;
      _incognitoKeyboard = prefs.getBool('incognito_keyboard') ?? false;
      _silenceUnknownCallers = settings['silenceUnknownCallers'] as bool? ?? false;
      _ipProtection = settings['ipProtection'] as bool? ?? false;
      _groupAddVisibility = settings['groupAddVisibility'] as String? ?? 'everyone';
      _isLoading = false;
    });
  }

  Future<void> _updateSetting(Future<void> Function() action) async {
    try {
      await action();
      AppHaptics.lightTap();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: $e'),
            backgroundColor: const Color(0xFFE5484D),
          ),
        );
      }
    }
  }

  String _visibilityLabel(String value) {
    switch (value) {
      case 'everyone':
        return 'Everyone';
      case 'friends':
        return 'Contacts Only';
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
    required Color cardBg,
    required Color cardBorder,
    required Color textPrimary,
    required Color textMuted,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...['everyone', 'friends', 'nobody'].map((opt) {
                final isSelected = opt == current;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _visibilityLabel(opt),
                    style: TextStyle(
                      color: isSelected ? textPrimary : textMuted,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle_rounded, color: textPrimary)
                      : null,
                  onTap: () {
                    onSelected(opt);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(rippleThemeProvider);
    final isDark = theme.isDark;

    final bgColor = theme.colors.background;
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardBorder = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE4E4E7);
    final textPrimary = isDark ? Colors.white : const Color(0xFF09090B);
    final textMuted = isDark ? Colors.white60 : const Color(0xFF71717A);
    final accent = isDark ? Colors.white : const Color(0xFF09090B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Privacy & Security',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accent))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                // ── WHO CAN SEE MY INFO ──────────────────────────────
                _sectionHeader('WHO CAN SEE MY INFO', textMuted),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder, width: 1),
                  ),
                  child: Column(
                    children: [
                      _buildVisibilityRow(
                        title: 'Last Seen & Online',
                        subtitle: 'Controls when active timestamp is shown',
                        icon: Icons.schedule_rounded,
                        value: _lastSeenVisibility,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                        cardBorder: cardBorder,
                        onTap: () => _showVisibilityPicker(
                          title: 'Last Seen Visibility',
                          current: _lastSeenVisibility,
                          onSelected: (v) {
                            setState(() => _lastSeenVisibility = v);
                            _updateSetting(() => PrivacyService.updatePrivacySettings(lastSeenVisibility: v));
                          },
                          cardBg: cardBg,
                          cardBorder: cardBorder,
                          textPrimary: textPrimary,
                          textMuted: textMuted,
                        ),
                      ),
                      Divider(color: cardBorder, height: 1, indent: 56),
                      _buildVisibilityRow(
                        title: 'Profile Photo',
                        subtitle: 'Who can inspect your high-res avatar',
                        icon: Icons.photo_camera_rounded,
                        value: _profilePhotoVisibility,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                        cardBorder: cardBorder,
                        onTap: () => _showVisibilityPicker(
                          title: 'Profile Photo Visibility',
                          current: _profilePhotoVisibility,
                          onSelected: (v) {
                            setState(() => _profilePhotoVisibility = v);
                            _updateSetting(() => PrivacyService.updatePrivacySettings(profilePhotoVisibility: v));
                          },
                          cardBg: cardBg,
                          cardBorder: cardBorder,
                          textPrimary: textPrimary,
                          textMuted: textMuted,
                        ),
                      ),
                      Divider(color: cardBorder, height: 1, indent: 56),
                      _buildVisibilityRow(
                        title: 'Bio & About',
                        subtitle: 'Who can read your personal bio',
                        icon: Icons.edit_note_rounded,
                        value: _bioVisibility,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                        cardBorder: cardBorder,
                        onTap: () => _showVisibilityPicker(
                          title: 'Bio Visibility',
                          current: _bioVisibility,
                          onSelected: (v) {
                            setState(() => _bioVisibility = v);
                            _updateSetting(() => PrivacyService.updatePrivacySettings(bioVisibility: v));
                          },
                          cardBg: cardBg,
                          cardBorder: cardBorder,
                          textPrimary: textPrimary,
                          textMuted: textMuted,
                        ),
                      ),
                      Divider(color: cardBorder, height: 1, indent: 56),
                      _buildVisibilityRow(
                        title: 'Group Invitations',
                        subtitle: 'Who can add you to group chats',
                        icon: Icons.group_add_rounded,
                        value: _groupAddVisibility,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                        cardBorder: cardBorder,
                        onTap: () => _showVisibilityPicker(
                          title: 'Group Invitations',
                          current: _groupAddVisibility,
                          onSelected: (v) {
                            setState(() => _groupAddVisibility = v);
                            _updateSetting(() => PrivacyService.updatePrivacySettings(groupAddVisibility: v));
                          },
                          cardBg: cardBg,
                          cardBorder: cardBorder,
                          textPrimary: textPrimary,
                          textMuted: textMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── CONVERSATION PRIVACY ─────────────────────────────
                _sectionHeader('CONVERSATION PRIVACY', textMuted),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder, width: 1),
                  ),
                  child: Column(
                    children: [
                      _buildToggleRow(
                        title: 'Read Receipts',
                        subtitle: 'Show blue checks when messages are read',
                        icon: Icons.done_all_rounded,
                        value: _readReceipts,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                        onChanged: (v) {
                          setState(() => _readReceipts = v);
                          _updateSetting(() => PrivacyService.updatePrivacySettings(readReceipts: v));
                        },
                      ),
                      Divider(color: cardBorder, height: 1, indent: 56),
                      _buildToggleRow(
                        title: 'Typing Indicator',
                        subtitle: 'Display active typing bubbles in chat',
                        icon: Icons.text_snippet_outlined,
                        value: _typingIndicator,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                        onChanged: (v) {
                          setState(() => _typingIndicator = v);
                          _updateSetting(() => PrivacyService.updatePrivacySettings(typingIndicator: v));
                        },
                      ),
                      Divider(color: cardBorder, height: 1, indent: 56),
                      _buildToggleRow(
                        title: 'Block OS Screenshots',
                        subtitle: 'Prevent screenshots & task switcher caching',
                        icon: Icons.screenshot_rounded,
                        value: _screenshotBlock,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                        onChanged: (v) async {
                          setState(() => _screenshotBlock = v);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('screenshot_block', v);
                          if (v) {
                            await FlutterWindowManagerPlus.addFlags(FlutterWindowManagerPlus.FLAG_SECURE);
                          } else {
                            await FlutterWindowManagerPlus.clearFlags(FlutterWindowManagerPlus.FLAG_SECURE);
                          }
                          AppHaptics.lightTap();
                        },
                      ),
                      Divider(color: cardBorder, height: 1, indent: 56),
                      _buildToggleRow(
                        title: 'Incognito Keyboard',
                        subtitle: 'Request keyboard not to save dictionary typing',
                        icon: Icons.keyboard_hide_outlined,
                        value: _incognitoKeyboard,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                        onChanged: (v) async {
                          setState(() => _incognitoKeyboard = v);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('incognito_keyboard', v);
                          AppHaptics.lightTap();
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── ADVANCED ENCRYPTION & SECURITY ────────────────────
                _sectionHeader('NETWORK & RELAY PRIVACY', textMuted),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder, width: 1),
                  ),
                  child: Column(
                    children: [
                      _buildToggleRow(
                        title: 'Silence Unknown Callers',
                        subtitle: 'Calls from non-contacts will be silenced',
                        icon: Icons.phone_disabled_outlined,
                        value: _silenceUnknownCallers,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                        onChanged: (v) {
                          setState(() => _silenceUnknownCallers = v);
                          _updateSetting(() => PrivacyService.updatePrivacySettings(silenceUnknownCallers: v));
                        },
                      ),
                      Divider(color: cardBorder, height: 1, indent: 56),
                      _buildToggleRow(
                        title: 'Relay Calls (IP Protection)',
                        subtitle: 'Relay WebRTC calls through server to hide IP address',
                        icon: Icons.shield_outlined,
                        value: _ipProtection,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                        onChanged: (v) {
                          setState(() => _ipProtection = v);
                          _updateSetting(() => PrivacyService.updatePrivacySettings(ipProtection: v));
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── VAULTS & SECURITY HUBS ───────────────────────────
                _sectionHeader('SECURITY HUBS', textMuted),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder, width: 1),
                  ),
                  child: Column(
                    children: [
                      _buildNavTile(
                        icon: Icons.lock_outline_rounded,
                        title: 'Chat Lock Hub',
                        subtitle: 'Manage locked conversation list & passcodes',
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                        onTap: () => context.push('/chat-lock-settings'),
                      ),
                      Divider(color: cardBorder, height: 1, indent: 56),
                      _buildNavTile(
                        icon: Icons.fingerprint_rounded,
                        title: 'App Lock Settings',
                        subtitle: 'Biometric challenge & auto-lock timeout',
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                        onTap: () => context.push('/app-lock-settings'),
                      ),
                      Divider(color: cardBorder, height: 1, indent: 56),
                      _buildNavTile(
                        icon: Icons.block_flipped,
                        title: 'Blocked Contacts',
                        subtitle: 'View and unblock restricted contacts',
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                        onTap: () => context.push('/blocked-contacts'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),
              ],
            ),
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildVisibilityRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
    required Color textPrimary,
    required Color textMuted,
    required Color cardBorder,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: textPrimary.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: textPrimary, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _visibilityLabel(value),
              style: TextStyle(color: textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: textMuted, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required Color textPrimary,
    required Color textMuted,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: textPrimary.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: textPrimary, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: textPrimary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildNavTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color textPrimary,
    required Color textMuted,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: textPrimary.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: textPrimary, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}
