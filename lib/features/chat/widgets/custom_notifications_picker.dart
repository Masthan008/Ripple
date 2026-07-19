import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/firebase_service.dart';
import '../../profile/services/custom_sound_service.dart';

class CustomNotificationsPicker extends StatefulWidget {
  final String chatId;
  final String partnerName;

  const CustomNotificationsPicker({
    super.key,
    required this.chatId,
    required this.partnerName,
  });

  @override
  State<CustomNotificationsPicker> createState() => _CustomNotificationsPickerState();
}

class _CustomNotificationsPickerState extends State<CustomNotificationsPicker> {
  final CustomSoundService _soundService = CustomSoundService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isLoading = true;
  bool _customEnabled = false;
  String _soundName = 'Aqua Chime';
  String _soundUrl = '';

  @override
  void initState() {
    super.initState();
    _loadOverrideSettings();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadOverrideSettings() async {
    try {
      final uid = FirebaseService.auth.currentUser?.uid;
      if (uid == null) return;
      final data = await _soundService.loadChatSoundOverride(uid, widget.chatId);
      if (data != null) {
        setState(() {
          _customEnabled = data['enabled'] ?? false;
          _soundName = data['soundName'] ?? 'Aqua Chime';
          _soundUrl = data['soundUrl'] ?? '';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    final uid = FirebaseService.auth.currentUser?.uid;
    if (uid == null) return;

    await _soundService.saveChatSoundOverride(
      uid: uid,
      chatId: widget.chatId,
      enabled: _customEnabled,
      soundName: _soundName,
      soundUrl: _soundUrl.isNotEmpty ? _soundUrl : null,
    );
  }

  Future<void> _playPreview(String name, String url) async {
    try {
      await _audioPlayer.stop();
      if (url.isNotEmpty) {
        await _audioPlayer.setUrl(url);
      } else {
        final path = CustomSoundService.getSoundAssetPath(name);
        await _audioPlayer.setAsset(path);
      }
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Error playing preview: $e');
    }
  }

  Future<void> _pickAndUploadSound() async {
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
            _soundName = fileName;
            _soundUrl = downloadUrl;
          });
          await _saveSettings();
        }
      }
    } catch (e) {
      debugPrint('Error uploading custom file: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF07111F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: _isLoading
          ? const SizedBox(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppColors.aquaCore),
                ),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Custom Notifications: ${widget.partnerName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  activeColor: AppColors.aquaCore,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Use Custom Notifications', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Override global sound settings for this chat', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  value: _customEnabled,
                  onChanged: (v) async {
                    setState(() => _customEnabled = v);
                    await _saveSettings();
                  },
                ),
                const Divider(color: Colors.white10),
                if (_customEnabled) ...[
                  const Text('Select Alert Tone', style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: [
                        ...CustomSoundService.prebuiltSounds.map((name) {
                          final isSelected = _soundName == name && _soundUrl.isEmpty;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: isSelected ? AppColors.aquaCore : Colors.white30,
                            ),
                            title: Text(name, style: const TextStyle(color: Colors.white)),
                            trailing: IconButton(
                              icon: const Icon(Icons.play_arrow, color: AppColors.aquaCore),
                              onPressed: () => _playPreview(name, ''),
                            ),
                            onTap: () async {
                              setState(() {
                                _soundName = name;
                                _soundUrl = '';
                              });
                              await _saveSettings();
                            },
                          );
                        }),
                        const Divider(color: Colors.white10),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            _soundUrl.isNotEmpty ? Icons.radio_button_checked : Icons.audiotrack,
                            color: _soundUrl.isNotEmpty ? AppColors.aquaCore : Colors.white30,
                          ),
                          title: Text(
                            _soundUrl.isNotEmpty ? _soundName : 'Upload Custom Audio...',
                            style: TextStyle(
                              color: _soundUrl.isNotEmpty ? Colors.white : AppColors.aquaCore,
                            ),
                          ),
                          subtitle: _soundUrl.isNotEmpty
                              ? const Text('Custom Uploaded Tone', style: TextStyle(color: Colors.white38, fontSize: 11))
                              : null,
                          trailing: _soundUrl.isNotEmpty
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.play_arrow_rounded, color: AppColors.aquaCore),
                                      onPressed: () => _playPreview(_soundName, _soundUrl),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.upload_file_rounded, color: Colors.white54),
                                      onPressed: _pickAndUploadSound,
                                    ),
                                  ],
                                )
                              : null,
                          onTap: () async {
                            if (_soundUrl.isEmpty) {
                              _pickAndUploadSound();
                            } else {
                              setState(() {
                                _soundName = _soundName;
                                _soundUrl = _soundUrl;
                              });
                              await _saveSettings();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ] else
                  const SizedBox(height: 150, child: Center(child: Text('Global sound defaults will apply to this chat.', style: TextStyle(color: Colors.white38)))),
              ],
            ),
    );
  }
}
