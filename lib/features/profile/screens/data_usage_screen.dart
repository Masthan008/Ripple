import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/l10n.dart';
import '../providers/settings_provider.dart';

class DataUsageScreen extends ConsumerStatefulWidget {
  const DataUsageScreen({super.key});

  @override
  ConsumerState<DataUsageScreen> createState() => _DataUsageScreenState();
}

class _DataUsageScreenState extends ConsumerState<DataUsageScreen> {
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

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<void> _resetStats() async {
    await ref.read(dataUsageProvider.notifier).resetStats();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Statistics reset successfully!'),
          backgroundColor: AppColors.onlineGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(rippleThemeProvider);
    final isDark = theme.isDark;
    final textColor = isDark ? Colors.white : const Color(0xFF09090B);
    final textMuted = isDark ? Colors.white60 : const Color(0xFF71717A);
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    final cardBorder = isDark ? Colors.white12 : const Color(0xFFE4E4E7);

    final dataUsage = ref.watch(dataUsageProvider);
    final cellularSent = dataUsage.cellularSent;
    final cellularReceived = dataUsage.cellularReceived;
    final wifiSent = dataUsage.wifiSent;
    final wifiReceived = dataUsage.wifiReceived;

    return Scaffold(
      backgroundColor: theme.colors.background,
      appBar: AppBar(
        title: Text(L10n.s(ref, 'dataUsage'), style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimationLimiter(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: AnimationConfiguration.toStaggeredList(
              duration: const Duration(milliseconds: 400),
              childAnimationBuilder: (w) => SlideAnimation(
                verticalOffset: 40,
                curve: Curves.easeOutBack,
                child: FadeInAnimation(child: w),
              ),
              children: [
                _sectionHeader('AUTO-DOWNLOAD', textMuted),
                const SizedBox(height: 8),
                _toggle('Images', Icons.image_rounded, _autoImages, (v) {
                  setState(() => _autoImages = v);
                  _saveBool('auto_download_images', v);
                }, cardBg, cardBorder, textColor),
                _toggle('Videos', Icons.videocam_rounded, _autoVideos, (v) {
                  setState(() => _autoVideos = v);
                  _saveBool('auto_download_videos', v);
                }, cardBg, cardBorder, textColor),
                _toggle('Files & Documents', Icons.description_rounded, _autoFiles, (v) {
                  setState(() => _autoFiles = v);
                  _saveBool('auto_download_files', v);
                }, cardBg, cardBorder, textColor),
                const SizedBox(height: 24),

                _sectionHeader('UPLOAD QUALITY', textMuted),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Column(
                    children: [
                      ...['original', 'high', 'medium'].map((q) {
                        final label = q[0].toUpperCase() + q.substring(1);
                        final subtitle = q == 'original'
                            ? 'Best visual quality, larger upload size'
                            : q == 'high'
                                ? 'Optimal balance of sharpness and compression'
                                : 'Fast uploads, saves data bandwidth';
                        final isSelected = _uploadQuality == q;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: () => _saveQuality(q),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colors.primary.withValues(alpha: isDark ? 0.2 : 0.08)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? theme.colors.primary : cardBorder,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 14)),
                                        Text(subtitle, style: TextStyle(color: textMuted, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(Icons.check_circle_rounded, color: theme.colors.primary, size: 20),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                _sectionHeader('LIVE NETWORK STATISTICS', textMuted),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Column(
                    children: [
                      _statRow('Cellular Sent', cellularSent, Icons.upload_rounded, const Color(0xFFF59E0B), textColor, textMuted),
                      Divider(color: cardBorder),
                      _statRow('Cellular Received', cellularReceived, Icons.download_rounded, const Color(0xFFF59E0B), textColor, textMuted),
                      Divider(color: cardBorder),
                      _statRow('Wi-Fi Sent', wifiSent, Icons.upload_rounded, theme.colors.primary, textColor, textMuted),
                      Divider(color: cardBorder),
                      _statRow('Wi-Fi Received', wifiReceived, Icons.download_rounded, theme.colors.primary, textColor, textMuted),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Network Traffic',
                            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            _formatBytes(cellularSent + cellularReceived + wifiSent + wifiReceived),
                            style: TextStyle(color: theme.colors.primary, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: OutlinedButton.icon(
                          onPressed: _resetStats,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Reset Network Counters'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.errorRed,
                            side: const BorderSide(color: Color(0x33EF4444)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
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

  Widget _statRow(String label, int value, IconData icon, Color color, Color textColor, Color textMuted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: textMuted, fontSize: 12)),
          const Spacer(),
          Text(_formatBytes(value), style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _toggle(String label, IconData icon, bool value, Function(bool) onChanged, Color cardBg, Color cardBorder, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cardBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: textColor, size: 20),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: TextStyle(color: textColor, fontSize: 13.5, fontWeight: FontWeight.w500))),
            CupertinoSwitch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: Colors.black,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, Color color) => Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: color,
        ),
      );
}
