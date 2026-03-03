import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/glass_card.dart';

class StorageUsageScreen extends StatefulWidget {
  const StorageUsageScreen({super.key});

  @override
  State<StorageUsageScreen> createState() => _StorageUsageScreenState();
}

class _StorageUsageScreenState extends State<StorageUsageScreen> {
  int _cacheSize = 0;
  bool _isLoading = true;
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    _calculateCache();
  }

  Future<void> _calculateCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      _cacheSize = await _dirSize(tempDir);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<int> _dirSize(Directory dir) async {
    int size = 0;
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          size += await entity.length();
        }
      }
    } catch (_) {}
    return size;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _clearCache() async {
    setState(() => _isClearing = true);
    try {
      final tempDir = await getTemporaryDirectory();
      final freed = _cacheSize;
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
        await tempDir.create(); // Recreate empty temp dir
      }
      if (mounted) {
        setState(() {
          _cacheSize = 0;
          _isClearing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cache cleared! ${_formatBytes(freed)} freed'),
            backgroundColor: AppColors.onlineGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isClearing = false);
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
    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      appBar: AppBar(
        title: Text('Storage Usage', style: AppTextStyles.heading),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.aquaCore),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppColors.aquaCore)))
          : AnimationLimiter(
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
                      _sectionHeader('Cache'),
                      const SizedBox(height: 8),
                      GlassCard(
                        borderRadius: 16,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.storage_rounded,
                                    color: AppColors.aquaCore, size: 28),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Cache Size',
                                          style: AppTextStyles.body),
                                      Text(_formatBytes(_cacheSize),
                                          style: AppTextStyles.heading.copyWith(
                                              color: AppColors.aquaCore, fontSize: 22)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: (_cacheSize / (100 * 1024 * 1024)).clamp(0.0, 1.0),
                                backgroundColor: AppColors.glassPanel,
                                valueColor: const AlwaysStoppedAnimation(AppColors.aquaCore),
                                minHeight: 6,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: AppColors.buttonGradient,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ElevatedButton.icon(
                                  onPressed: _isClearing ? null : _clearCache,
                                  icon: _isClearing
                                      ? const SizedBox(width: 18, height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation(Colors.white)))
                                      : const Icon(Icons.cleaning_services_rounded, size: 18),
                                  label: Text(_isClearing ? 'Clearing...' : 'Clear Cache',
                                      style: AppTextStyles.button),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      _sectionHeader('Media Storage'),
                      const SizedBox(height: 8),
                      ...[
                        _MediaCard('Images', Icons.image_rounded, AppColors.aquaCore),
                        _MediaCard('Videos', Icons.videocam_rounded, AppColors.warningAmber),
                        _MediaCard('Documents', Icons.description_rounded, AppColors.onlineGreen),
                      ].map((card) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GlassCard(
                          borderRadius: 14,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Icon(card.icon, color: card.color, size: 22),
                              const SizedBox(width: 14),
                              Expanded(child: Text(card.label, style: AppTextStyles.body.copyWith(fontSize: 14))),
                              Text('Calculating...', style: AppTextStyles.caption.copyWith(fontSize: 11)),
                            ],
                          ),
                        ),
                      )),
                    ],
                  ),
                ),
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

class _MediaCard {
  final String label;
  final IconData icon;
  final Color color;
  const _MediaCard(this.label, this.icon, this.color);
}
