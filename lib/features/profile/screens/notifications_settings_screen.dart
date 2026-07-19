import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/firebase_service.dart';
import '../../../shared/widgets/glass_card.dart';
import '../services/custom_sound_service.dart';

class NotificationsSettingsScreen extends ConsumerStatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  ConsumerState<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends ConsumerState<NotificationsSettingsScreen> {
  final CustomSoundService _soundService = CustomSoundService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  Map<String, bool> _settings = {
    'messages': true,
    'groupMessages': true,
    'friendRequests': true,
    'calls': true,
    'sounds': true,
    'vibration': true,
    'previews': true,
  };

  Map<String, Map<String, String>> _soundSettings = {
    'messages': {'name': 'Aqua Chime', 'url': ''},
    'groups': {'name': 'Liquid Drip', 'url': ''},
    'calls': {'name': 'Sonar Pulse', 'url': ''},
    'statuses': {'name': 'Bubbles', 'url': ''},
  };

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final uid = FirebaseService.auth.currentUser?.uid;
      if (uid == null) return;
      final doc = await FirebaseService.firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        if (doc.data()?['notificationSettings'] != null) {
          final data = Map<String, bool>.from(doc.data()!['notificationSettings']);
          setState(() {
            _settings = {..._settings, ...data};
          });
        }
        if (doc.data()?['notificationSounds'] != null) {
          final rawSounds = doc.data()?['notificationSounds'] as Map;
          setState(() {
            rawSounds.forEach((category, info) {
              if (info is Map) {
                _soundSettings[category.toString()] = {
                  'name': info['name']?.toString() ?? 'Default',
                  'url': info['url']?.toString() ?? '',
                };
              }
            });
          });
        }
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

  Future<void> _playPreview(String soundName, String? soundUrl) async {
    try {
      await _audioPlayer.stop();
      if (soundUrl != null && soundUrl.isNotEmpty) {
        await _audioPlayer.setUrl(soundUrl);
      } else {
        final assetPath = CustomSoundService.getSoundAssetPath(soundName);
        await _audioPlayer.setAsset(assetPath);
      }
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Error playing preview: $e');
    }
  }

  Future<void> _pickAndUploadCustomSound(String category) async {
    final uid = FirebaseService.auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() => _isLoading = true);
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;

        final downloadUrl = await _soundService.uploadCustomSound(file, fileName);
        if (downloadUrl != null) {
          setState(() {
            _soundSettings[category] = {'name': fileName, 'url': downloadUrl};
          });
          await _soundService.saveGlobalSoundSetting(
            uid: uid,
            category: category,
            soundName: fileName,
            soundUrl: downloadUrl,
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking custom sound: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showSoundPicker(String category, String label) async {
    final uid = FirebaseService.auth.currentUser?.uid;
    if (uid == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF07111F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select $label Tone',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      children: [
                        ...CustomSoundService.prebuiltSounds.map((soundName) {
                          final isSelected = _soundSettings[category]?['name'] == soundName &&
                              (_soundSettings[category]?['url'] ?? '').isEmpty;
                          return ListTile(
                            leading: Icon(
                              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: isSelected ? AppColors.aquaCore : Colors.white30,
                            ),
                            title: Text(soundName, style: const TextStyle(color: Colors.white)),
                            trailing: IconButton(
                              icon: const Icon(Icons.play_arrow, color: AppColors.aquaCore),
                              onPressed: () => _playPreview(soundName, null),
                            ),
                            onTap: () async {
                              setModalState(() {
                                _soundSettings[category] = {'name': soundName, 'url': ''};
                              });
                              setState(() {
                                _soundSettings[category] = {'name': soundName, 'url': ''};
                              });
                              await _soundService.saveGlobalSoundSetting(
                                uid: uid,
                                category: category,
                                soundName: soundName,
                                soundUrl: null,
                              );
                            },
                          );
                        }),
                        const Divider(color: Colors.white10),
                        ListTile(
                          leading: const Icon(Icons.audiotrack, color: AppColors.aquaCore),
                          title: const Text('Upload Custom Audio...', style: TextStyle(color: AppColors.aquaCore)),
                          subtitle: (_soundSettings[category]?['url'] ?? '').isNotEmpty
                              ? Text(
                                  _soundSettings[category]!['name']!,
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                )
                              : null,
                          onTap: () async {
                            Navigator.pop(ctx);
                            await _pickAndUploadCustomSound(category);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final toggleItems = [
      _ToggleItem('Message Notifications', 'messages', Icons.chat_bubble_outline_rounded),
      _ToggleItem('Group Messages', 'groupMessages', Icons.group_outlined),
      _ToggleItem('Friend Requests', 'friendRequests', Icons.person_add_outlined),
      _ToggleItem('Call Notifications', 'calls', Icons.call_outlined),
      _ToggleItem('In-App Sounds', 'sounds', Icons.volume_up_rounded),
      _ToggleItem('Vibration', 'vibration', Icons.vibration),
      _ToggleItem('Show Message Previews', 'previews', Icons.visibility_outlined),
    ];

    final soundCategories = [
      {'key': 'messages', 'label': 'Message Tone', 'icon': Icons.music_note_outlined},
      {'key': 'groups', 'label': 'Group Tone', 'icon': Icons.group_work_outlined},
      {'key': 'calls', 'label': 'Call Ringtone', 'icon': Icons.ring_volume_outlined},
      {'key': 'statuses', 'label': 'Status Alert Tone', 'icon': Icons.star_outline_rounded},
    ];

    final List<Widget> listWidgets = [];

    // Header 1
    listWidgets.add(
      const Padding(
        padding: EdgeInsets.only(bottom: 12, left: 4),
        child: Text(
          'PREFERENCES',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );

    // Toggles
    for (int i = 0; i < toggleItems.length; i++) {
      final item = toggleItems[i];
      listWidgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassCard(
            borderRadius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(item.icon, color: AppColors.aquaCore, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.label,
                    style: AppTextStyles.body.copyWith(fontSize: 14),
                  ),
                ),
                CupertinoSwitch(
                  value: _settings[item.key] ?? true,
                  onChanged: (v) => _updateSetting(item.key, v),
                  activeTrackColor: AppColors.aquaCore,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Header 2
    listWidgets.add(
      const Padding(
        padding: EdgeInsets.only(top: 20, bottom: 12, left: 4),
        child: Text(
          'NOTIFICATION SOUNDS',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );

    // Sound items
    for (var cat in soundCategories) {
      final key = cat['key'] as String;
      final label = cat['label'] as String;
      final icon = cat['icon'] as IconData;
      final selectedSoundName = _soundSettings[key]?['name'] ?? 'Default';

      listWidgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () => _showSoundPicker(key, label),
            borderRadius: BorderRadius.circular(14),
            child: GlassCard(
              borderRadius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(icon, color: AppColors.aquaCore, size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: AppTextStyles.body.copyWith(fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          selectedSoundName,
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 14),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      appBar: AppBar(
        title: Text('Notifications', style: AppTextStyles.heading),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.aquaCore),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppColors.aquaCore),
              ),
            )
          : AnimationLimiter(
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: listWidgets.length,
                itemBuilder: (ctx, i) {
                  return AnimationConfiguration.staggeredList(
                    position: i,
                    duration: const Duration(milliseconds: 450),
                    child: SlideAnimation(
                      verticalOffset: 50,
                      curve: Curves.easeOutBack,
                      child: FadeInAnimation(
                        child: listWidgets[i],
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
