import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/glass_card.dart';

class DataUsageScreen extends StatefulWidget {
  const DataUsageScreen({super.key});

  @override
  State<DataUsageScreen> createState() => _DataUsageScreenState();
}

class _DataUsageScreenState extends State<DataUsageScreen> {
  bool _autoImages = true;
  bool _autoVideos = false;
  bool _autoFiles = false;
  String _uploadQuality = 'high';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoImages = prefs.getBool('auto_download_images') ?? true;
      _autoVideos = prefs.getBool('auto_download_videos') ?? false;
      _autoFiles = prefs.getBool('auto_download_files') ?? false;
      _uploadQuality = prefs.getString('upload_quality') ?? 'high';
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveQuality(String value) async {
    setState(() => _uploadQuality = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('upload_quality', value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      appBar: AppBar(
        title: Text('Data Usage', style: AppTextStyles.heading),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.aquaCore),
      ),
      body: AnimationLimiter(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: AnimationConfiguration.toStaggeredList(
              duration: const Duration(milliseconds: 450),
              childAnimationBuilder: (w) => SlideAnimation(
                verticalOffset: 50, curve: Curves.easeOutBack,
                child: FadeInAnimation(child: w),
              ),
              children: [
                _sectionHeader('Auto-Download'),
                const SizedBox(height: 8),
                _toggle('Images', Icons.image_rounded, _autoImages, (v) {
                  setState(() => _autoImages = v);
                  _saveBool('auto_download_images', v);
                }),
                _toggle('Videos', Icons.videocam_rounded, _autoVideos, (v) {
                  setState(() => _autoVideos = v);
                  _saveBool('auto_download_videos', v);
                }),
                _toggle('Files', Icons.description_rounded, _autoFiles, (v) {
                  setState(() => _autoFiles = v);
                  _saveBool('auto_download_files', v);
                }),
                const SizedBox(height: 24),

                _sectionHeader('Upload Quality'),
                const SizedBox(height: 8),
                GlassCard(
                  borderRadius: 16,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ...['original', 'high', 'medium'].map((q) {
                        final label = q[0].toUpperCase() + q.substring(1);
                        final subtitle = q == 'original'
                            ? 'Best quality, larger files'
                            : q == 'high'
                                ? 'Balanced quality and size'
                                : 'Smaller files, saves data';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: () => _saveQuality(q),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: _uploadQuality == q
                                    ? AppColors.aquaCore.withValues(alpha: 0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _uploadQuality == q
                                      ? AppColors.aquaCore
                                      : AppColors.glassBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(label, style: AppTextStyles.body.copyWith(fontSize: 14)),
                                        Text(subtitle, style: AppTextStyles.caption.copyWith(fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  if (_uploadQuality == q)
                                    Icon(Icons.check_circle_rounded,
                                        color: AppColors.aquaCore, size: 20),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _toggle(String label, IconData icon, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        borderRadius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.aquaCore, size: 22),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: AppTextStyles.body.copyWith(fontSize: 14))),
            CupertinoSwitch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: AppColors.aquaCore,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) => Text(
    title.toUpperCase(),
    style: AppTextStyles.caption.copyWith(
      fontSize: 11, fontWeight: FontWeight.w600,
      letterSpacing: 1.2, color: AppColors.aquaCore.withValues(alpha: 0.7),
    ),
  );
}
