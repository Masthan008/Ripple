import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/firebase_service.dart';
import '../../../shared/widgets/glass_card.dart';

class NotificationsSettingsScreen extends ConsumerStatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  ConsumerState<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends ConsumerState<NotificationsSettingsScreen> {
  Map<String, bool> _settings = {
    'messages': true,
    'groupMessages': true,
    'friendRequests': true,
    'calls': true,
    'sounds': true,
    'vibration': true,
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final uid = FirebaseService.auth.currentUser?.uid;
      if (uid == null) return;
      final doc = await FirebaseService.firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data()?['notificationSettings'] != null) {
        final data = Map<String, bool>.from(doc.data()!['notificationSettings']);
        setState(() {
          _settings = {..._settings, ...data};
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSetting(String key, bool value) async {
    setState(() => _settings[key] = value);
    try {
      final uid = FirebaseService.auth.currentUser?.uid;
      if (uid == null) return;
      await FirebaseService.firestore.collection('users').doc(uid).update({
        'notificationSettings.$key': value,
      });
    } catch (e) {
      setState(() => _settings[key] = !value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong. Try again.'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      _ToggleItem('Message Notifications', 'messages', Icons.chat_bubble_outline_rounded),
      _ToggleItem('Group Messages', 'groupMessages', Icons.group_outlined),
      _ToggleItem('Friend Requests', 'friendRequests', Icons.person_add_outlined),
      _ToggleItem('Call Notifications', 'calls', Icons.call_outlined),
      _ToggleItem('In-App Sounds', 'sounds', Icons.volume_up_rounded),
      _ToggleItem('Vibration', 'vibration', Icons.vibration),
    ];

    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      appBar: AppBar(
        title: Text('Notifications', style: AppTextStyles.heading),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.aquaCore),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppColors.aquaCore)))
          : AnimationLimiter(
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: items.length,
                itemBuilder: (ctx, i) {
                  final item = items[i];
                  return AnimationConfiguration.staggeredList(
                    position: i,
                    duration: const Duration(milliseconds: 450),
                    child: SlideAnimation(
                      verticalOffset: 50,
                      curve: Curves.easeOutBack,
                      child: FadeInAnimation(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GlassCard(
                            borderRadius: 14,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Icon(item.icon, color: AppColors.aquaCore, size: 22),
                                const SizedBox(width: 14),
                                Expanded(child: Text(item.label, style: AppTextStyles.body.copyWith(fontSize: 14))),
                                CupertinoSwitch(
                                  value: _settings[item.key] ?? true,
                                  onChanged: (v) => _updateSetting(item.key, v),
                                  activeTrackColor: AppColors.aquaCore,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _ToggleItem {
  final String label;
  final String key;
  final IconData icon;
  const _ToggleItem(this.label, this.key, this.icon);
}
