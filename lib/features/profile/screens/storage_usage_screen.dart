import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

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
  int _imagesSize = 0;
  int _videosSize = 0;
  int _docsSize = 0;
  bool _isLoading = true;
  bool _isClearing = false;
  Timer? _periodicTimer;

  @override
  void initState() {
    super.initState();
    _calculateCache();
    _periodicTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
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

      _cacheSize = await _dirSize(tempDir);

      int imagesSize = 0;
      int videosSize = 0;
      int docsSize = 0;

      void scanFile(File file) {
        final path = file.path.toLowerCase();
        final ext = path.split('.').last;
        try {
          final len = file.lengthSync();
          if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
            imagesSize += len;
          } else if (['mp4', 'mov', 'avi', 'mkv', '3gp'].contains(ext)) {
            videosSize += len;
          } else if (['pdf', 'txt', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'zip', 'rar'].contains(ext)) {
            docsSize += len;
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

      if (mounted) {
        setState(() {
          _imagesSize = imagesSize;
          _videosSize = videosSize;
          _docsSize = docsSize;
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
      
      // Reset variables and recalculate
      await _calculateCache();

      if (mounted) {
        setState(() => _isClearing = false);
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
    final totalMedia = _imagesSize + _videosSize + _docsSize;
    final imagesFraction = totalMedia > 0 ? _imagesSize / totalMedia : 0.0;
    final videosFraction = totalMedia > 0 ? _videosSize / totalMedia : 0.0;
    final docsFraction = totalMedia > 0 ? _docsSize / totalMedia : 0.0;

    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      appBar: AppBar(
        title: Text('Storage Usage', style: AppTextStyles.heading),
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: AnimationConfiguration.toStaggeredList(
                    duration: const Duration(milliseconds: 450),
                    childAnimationBuilder: (w) => SlideAnimation(
                      verticalOffset: 50,
                      curve: Curves.easeOutBack,
                      child: FadeInAnimation(child: w),
                    ),
                    children: [
                      // Storage distribution visual card
                      GlassCard(
                        borderRadius: 16,
                        padding: const EdgeInsets.all(20),
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
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _formatBytes(totalMedia),
                                        style: AppTextStyles.heading.copyWith(
                                          fontSize: 14,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Used',
                                        style: AppTextStyles.caption.copyWith(
                                          fontSize: 10,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            // Details legend
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _legendItem('Images', _imagesSize, AppColors.aquaCore),
                                  const SizedBox(height: 6),
                                  _legendItem('Videos', _videosSize, AppColors.warningAmber),
                                  const SizedBox(height: 6),
                                  _legendItem('Documents', _docsSize, AppColors.onlineGreen),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      _sectionHeader('Cache Management'),
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
                                      Text('Temporary Cache',
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
                                  label: Text(_isClearing ? 'Clearing...' : 'Clear All Temporary Cache',
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

                      _sectionHeader('Individual Storage Breakdown'),
                      const SizedBox(height: 8),
                      _categoryCard('Images', _imagesSize, Icons.image_rounded, AppColors.aquaCore,
                          ['jpg', 'jpeg', 'png', 'gif', 'webp']),
                      _categoryCard('Videos', _videosSize, Icons.videocam_rounded, AppColors.warningAmber,
                          ['mp4', 'mov', 'avi', 'mkv', '3gp']),
                      _categoryCard('Documents & Archives', _docsSize, Icons.description_rounded, AppColors.onlineGreen,
                          ['pdf', 'txt', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'zip', 'rar']),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _legendItem(String label, int size, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: Colors.white70, fontSize: 12),
        ),
        const Spacer(),
        Text(
          _formatBytes(size),
          style: AppTextStyles.body.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _categoryCard(String label, int size, IconData icon, Color color, List<String> extensions) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        borderRadius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.body.copyWith(fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(_formatBytes(size), style: AppTextStyles.caption.copyWith(fontSize: 11)),
                ],
              ),
            ),
            if (size > 0)
              TextButton(
                onPressed: _isClearing ? null : () => _clearCategory(label, extensions),
                child: Text(
                  'Clear',
                  style: TextStyle(
                    color: AppColors.errorRed.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              Text(
                'Empty',
                style: AppTextStyles.caption.copyWith(fontSize: 11, color: AppColors.textMuted),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) => Text(
        title.toUpperCase(),
        style: AppTextStyles.caption.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: AppColors.aquaCore.withValues(alpha: 0.7),
        ),
      );
}

class _StorageRingPainter extends CustomPainter {
  final double imagesFraction;
  final double videosFraction;
  final double docsFraction;

  _StorageRingPainter({
    required this.imagesFraction,
    required this.videosFraction,
    required this.docsFraction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    const strokeWidth = 10.0;

    final basePaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, basePaint);

    final totalFraction = imagesFraction + videosFraction + docsFraction;
    if (totalFraction <= 0) return;

    double startAngle = -math.pi / 2;

    void drawSegment(double fraction, Color color) {
      if (fraction <= 0) return;
      final sweepAngle = fraction * 2 * math.pi;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle - 0.08, // Subtle spacing gap between segments
        false,
        paint,
      );
      startAngle += sweepAngle;
    }

    drawSegment(imagesFraction, AppColors.aquaCore);
    drawSegment(videosFraction, AppColors.warningAmber);
    drawSegment(docsFraction, AppColors.onlineGreen);
  }

  @override
  bool shouldRepaint(covariant _StorageRingPainter oldDelegate) {
    return oldDelegate.imagesFraction != imagesFraction ||
        oldDelegate.videosFraction != videosFraction ||
        oldDelegate.docsFraction != docsFraction;
  }
}
