import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/l10n.dart';

class StorageUsageScreen extends ConsumerStatefulWidget {
  const StorageUsageScreen({super.key});

  @override
  ConsumerState<StorageUsageScreen> createState() => _StorageUsageScreenState();
}

class _StorageUsageScreenState extends ConsumerState<StorageUsageScreen> {
  int _cacheSize = 0;
  int _imagesSize = 0;
  int _videosSize = 0;
  int _audioSize = 0;
  int _docsSize = 0;
  int _dbSize = 0;
  bool _isLoading = true;
  bool _isClearing = false;
  Timer? _periodicTimer;

  @override
  void initState() {
    super.initState();
    _calculateCache();
    _periodicTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted && !_isClearing) {
        _calculateCache();
      }
    });
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    super.dispose();
  }

  Future<void> _calculateCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final appDir = await getApplicationDocumentsDirectory();
      final supportDir = await getApplicationSupportDirectory();

      _cacheSize = await _dirSize(tempDir);

      int imagesSize = 0;
      int videosSize = 0;
      int audioSize = 0;
      int docsSize = 0;
      int dbSize = 0;

      void scanFile(File file) {
        final path = file.path.toLowerCase();
        final ext = path.split('.').last;
        try {
          final len = file.lengthSync();
          if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext)) {
            imagesSize += len;
          } else if (['mp4', 'mov', 'avi', 'mkv', '3gp', 'webm'].contains(ext)) {
            videosSize += len;
          } else if (['m4a', 'aac', 'mp3', 'wav', 'ogg', 'opus'].contains(ext)) {
            audioSize += len;
          } else if (['pdf', 'txt', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'zip', 'rar'].contains(ext)) {
            docsSize += len;
          } else if (['db', 'sqlite', 'sqlite3', 'rpbk', 'dat'].contains(ext)) {
            dbSize += len;
          }
        } catch (_) {}
      }

      Future<void> scanDirectory(Directory dir) async {
        if (!dir.existsSync()) return;
        try {
          await for (final entity in dir.list(recursive: true, followLinks: false)) {
            if (entity is File) {
              scanFile(entity);
            }
          }
        } catch (_) {}
      }

      await scanDirectory(tempDir);
      await scanDirectory(appDir);
      await scanDirectory(supportDir);

      if (mounted) {
        setState(() {
          _imagesSize = imagesSize;
          _videosSize = videosSize;
          _audioSize = audioSize;
          _docsSize = docsSize;
          _dbSize = dbSize;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
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
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<void> _clearCache() async {
    setState(() => _isClearing = true);
    try {
      final tempDir = await getTemporaryDirectory();
      final freed = _cacheSize;
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
        await tempDir.create();
      }

      await _calculateCache();

      if (mounted) {
        setState(() => _isClearing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Temporary cache cleared! ${_formatBytes(freed)} freed'),
            backgroundColor: AppColors.onlineGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isClearing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not clear all cache items'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _clearCategory(String category, List<String> extensions) async {
    setState(() => _isClearing = true);
    try {
      final tempDir = await getTemporaryDirectory();
      final appDir = await getApplicationDocumentsDirectory();
      int freedBytes = 0;

      Future<void> clearFiles(Directory dir) async {
        if (!dir.existsSync()) return;
        try {
          await for (final entity in dir.list(recursive: true, followLinks: false)) {
            if (entity is File) {
              final ext = entity.path.toLowerCase().split('.').last;
              if (extensions.contains(ext)) {
                final len = await entity.length();
                await entity.delete();
                freedBytes += len;
              }
            }
          }
        } catch (_) {}
      }

      await clearFiles(tempDir);
      await clearFiles(appDir);
      await _calculateCache();

      if (mounted) {
        setState(() => _isClearing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$category cleared! ${_formatBytes(freedBytes)} freed'),
            backgroundColor: AppColors.onlineGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isClearing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear $category: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
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

    final totalMedia = _imagesSize + _videosSize + _audioSize + _docsSize + _dbSize;
    final imagesFraction = totalMedia > 0 ? _imagesSize / totalMedia : 0.0;
    final videosFraction = totalMedia > 0 ? _videosSize / totalMedia : 0.0;
    final docsFraction = totalMedia > 0 ? (_docsSize + _audioSize + _dbSize) / totalMedia : 0.0;

    return Scaffold(
      backgroundColor: theme.colors.background,
      appBar: AppBar(
        title: Text(L10n.s(ref, 'storageUsage'), style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(theme.colors.primary),
              ),
            )
          : AnimationLimiter(
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
                      // Storage distribution visual card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Row(
                          children: [
                            // Circular custom ring
                            SizedBox(
                              width: 100,
                              height: 100,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CustomPaint(
                                    size: const Size(100, 100),
                                    painter: _StorageRingPainter(
                                      imagesFraction: imagesFraction,
                                      videosFraction: videosFraction,
                                      docsFraction: docsFraction,
                                      primaryColor: theme.colors.primary,
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _formatBytes(totalMedia),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: textColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Used',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            // Details legend
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _legendItem('Images', _imagesSize, const Color(0xFF0EA5E9), textColor),
                                  const SizedBox(height: 6),
                                  _legendItem('Videos', _videosSize, const Color(0xFFF59E0B), textColor),
                                  const SizedBox(height: 6),
                                  _legendItem('Voice & Audio', _audioSize, const Color(0xFF8B5CF6), textColor),
                                  const SizedBox(height: 6),
                                  _legendItem('Docs & Data', _docsSize + _dbSize, const Color(0xFF10B981), textColor),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text('CACHE MANAGEMENT', style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.storage_rounded, color: theme.colors.primary, size: 28),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Temporary Cache', style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600)),
                                      Text(_formatBytes(_cacheSize),
                                          style: TextStyle(color: theme.colors.primary, fontSize: 20, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: (_cacheSize / (150 * 1024 * 1024)).clamp(0.0, 1.0),
                                backgroundColor: isDark ? Colors.white10 : const Color(0xFFE4E4E7),
                                valueColor: AlwaysStoppedAnimation(theme.colors.primary),
                                minHeight: 6,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: ElevatedButton.icon(
                                onPressed: _isClearing ? null : _clearCache,
                                icon: _isClearing
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                                    : const Icon(Icons.cleaning_services_rounded, size: 18),
                                label: Text(_isClearing ? 'Clearing Cache...' : 'Clear Temporary Cache', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colors.primary,
                                  foregroundColor: isDark ? Colors.black : Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text('INDIVIDUAL STORAGE BREAKDOWN', style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      const SizedBox(height: 8),
                      _categoryCard('Images', _imagesSize, Icons.image_rounded, const Color(0xFF0EA5E9), ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'], cardBg, cardBorder, textColor, textMuted),
                      _categoryCard('Videos', _videosSize, Icons.videocam_rounded, const Color(0xFFF59E0B), ['mp4', 'mov', 'avi', 'mkv', '3gp', 'webm'], cardBg, cardBorder, textColor, textMuted),
                      _categoryCard('Voice Messages & Audio', _audioSize, Icons.mic_rounded, const Color(0xFF8B5CF6), ['m4a', 'aac', 'mp3', 'wav', 'ogg', 'opus'], cardBg, cardBorder, textColor, textMuted),
                      _categoryCard('Documents & Archives', _docsSize, Icons.description_rounded, const Color(0xFF10B981), ['pdf', 'txt', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'zip', 'rar'], cardBg, cardBorder, textColor, textMuted),
                      _categoryCard('Encrypted Local Backups', _dbSize, Icons.lock_clock_rounded, const Color(0xFF64748B), ['rpbk', 'db', 'sqlite'], cardBg, cardBorder, textColor, textMuted),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _legendItem(String label, int size, Color color, Color textColor) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: textColor, fontSize: 12)),
        const Spacer(),
        Text(_formatBytes(size), style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _categoryCard(String label, int size, IconData icon, Color color, List<String> extensions, Color cardBg, Color cardBorder, Color textColor, Color textMuted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cardBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: textColor, fontSize: 13.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(_formatBytes(size), style: TextStyle(color: textMuted, fontSize: 11)),
                ],
              ),
            ),
            if (size > 0)
              TextButton(
                onPressed: _isClearing ? null : () => _clearCategory(label, extensions),
                child: const Text('Clear', style: TextStyle(color: AppColors.errorRed, fontSize: 12, fontWeight: FontWeight.bold)),
              )
            else
              Text('Clean', style: TextStyle(fontSize: 11, color: textMuted)),
          ],
        ),
      ),
    );
  }
}

class _StorageRingPainter extends CustomPainter {
  final double imagesFraction;
  final double videosFraction;
  final double docsFraction;
  final Color primaryColor;

  _StorageRingPainter({
    required this.imagesFraction,
    required this.videosFraction,
    required this.docsFraction,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const strokeWidth = 8.0;

    final bgPaint = Paint()
      ..color = const Color(0x1F71717A)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, bgPaint);

    if (imagesFraction == 0 && videosFraction == 0 && docsFraction == 0) return;

    double startAngle = -math.pi / 2;

    void drawSegment(double fraction, Color color) {
      if (fraction <= 0) return;
      final sweep = fraction * 2 * math.pi;
      final paint = Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += sweep;
    }

    drawSegment(imagesFraction, const Color(0xFF0EA5E9));
    drawSegment(videosFraction, const Color(0xFFF59E0B));
    drawSegment(docsFraction, const Color(0xFF10B981));
  }

  @override
  bool shouldRepaint(covariant _StorageRingPainter oldDelegate) => true;
}
