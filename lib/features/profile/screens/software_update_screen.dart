import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/update_service.dart';
import '../../../core/theme/theme_provider.dart';

/// Interactive Liquid Glass Software Update screen.
/// Provides over-the-air cloud patch checking, progress, and instant restart.
class SoftwareUpdateScreen extends ConsumerStatefulWidget {
  const SoftwareUpdateScreen({super.key});

  @override
  ConsumerState<SoftwareUpdateScreen> createState() => _SoftwareUpdateScreenState();
}

class _SoftwareUpdateScreenState extends ConsumerState<SoftwareUpdateScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  String _appVersion = '1.0.0';
  String _buildNumber = '42';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _loadPackageMetadata();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadPackageMetadata() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          if (info.version.isNotEmpty) _appVersion = info.version;
          if (info.buildNumber.isNotEmpty) _buildNumber = info.buildNumber;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final updateService = ref.watch(updateServiceProvider);
    final theme = ref.watch(rippleThemeProvider);
    final isDark = theme.isDark;

    final bgColor = isDark ? const Color(0xFF060D1A) : const Color(0xFFF5F7FA);
    final cardBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.88);
    final cardBorder = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Software Update',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),

              // ─── Pulsing Radar Animation ─────────────────────────────
              _buildRadarScanner(updateService, isDark),

              const SizedBox(height: 28),

              // ─── Status Text & Subtitle ──────────────────────────────
              _buildStatusHeader(updateService, textPrimary, textSecondary),

              const SizedBox(height: 32),

              // ─── System & Patch Specifications Card ───────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cardBorder, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildSpecRow(
                      icon: Icons.info_outline_rounded,
                      iconColor: AppColors.aquaCore,
                      label: 'Client Version',
                      value: 'v$_appVersion (Build $_buildNumber)',
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                    Divider(color: cardBorder, height: 24, thickness: 0.8),
                    _buildSpecRow(
                      icon: Icons.layers_outlined,
                      iconColor: const Color(0xFF60A5FA),
                      label: 'Active Cloud Patch',
                      value: updateService.patchVersionString,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      trailingBadge: updateService.currentPatch != null
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Applied',
                                style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : null,
                    ),
                    Divider(color: cardBorder, height: 24, thickness: 0.8),
                    _buildSpecRow(
                      icon: Icons.cloud_done_outlined,
                      iconColor: const Color(0xFF34D399),
                      label: 'Update Channel',
                      value: 'Production OTA',
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                    Divider(color: cardBorder, height: 24, thickness: 0.8),
                    _buildSpecRow(
                      icon: Icons.schedule_rounded,
                      iconColor: const Color(0xFFA78BFA),
                      label: 'Last Checked',
                      value: _formatLastChecked(updateService.lastCheckedTime),
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ─── Automatic Updates Switch Card ────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cardBorder, width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.aquaCore.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.auto_mode_rounded, color: AppColors.aquaCore, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Automatic Cloud Updates',
                            style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Download patches silently in the background',
                            style: TextStyle(color: textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: updateService.autoCheckEnabled,
                      activeThumbColor: AppColors.aquaCore,
                      onChanged: (val) => updateService.setAutoCheckEnabled(val),
                    ),
                  ],
                ),
              ),

              if (updateService.errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.errorRed, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          updateService.errorMessage!,
                          style: const TextStyle(color: AppColors.errorRed, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 36),

              // ─── Action Button Trigger ───────────────────────────────
              _buildActionButton(updateService, context),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadarScanner(UpdateService service, bool isDark) {
    Color glowColor;
    IconData centerIcon;

    switch (service.status) {
      case AppUpdateStatus.checking:
        glowColor = const Color(0xFF00E5FF);
        centerIcon = Icons.cloud_sync_rounded;
        break;
      case AppUpdateStatus.updateAvailable:
        glowColor = const Color(0xFFF59E0B);
        centerIcon = Icons.system_update_alt_rounded;
        break;
      case AppUpdateStatus.downloading:
        glowColor = const Color(0xFF3B82F6);
        centerIcon = Icons.download_rounded;
        break;
      case AppUpdateStatus.restartRequired:
        glowColor = const Color(0xFFA855F7);
        centerIcon = Icons.restart_alt_rounded;
        break;
      case AppUpdateStatus.error:
        glowColor = AppColors.errorRed;
        centerIcon = Icons.sync_problem_rounded;
        break;
      case AppUpdateStatus.idle:
      case AppUpdateStatus.upToDate:
        glowColor = const Color(0xFF10B981);
        centerIcon = Icons.verified_rounded;
        break;
    }

    return SizedBox(
      height: 160,
      width: 160,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final progress = _pulseController.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer ripple 2
              Transform.scale(
                scale: 1.0 + (progress * 0.4),
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: glowColor.withValues(alpha: math.max(0, 0.25 - (progress * 0.25))),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              // Outer ripple 1
              Transform.scale(
                scale: 1.0 + (((progress + 0.5) % 1.0) * 0.3),
                child: Container(
                  width: 105,
                  height: 105,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: glowColor.withValues(alpha: math.max(0, 0.35 - (((progress + 0.5) % 1.0) * 0.35))),
                      width: 2,
                    ),
                  ),
                ),
              ),
              // Center Orb
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      glowColor.withValues(alpha: 0.9),
                      glowColor.withValues(alpha: 0.4),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withValues(alpha: 0.45),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: service.status == AppUpdateStatus.checking
                      ? Transform.rotate(
                          angle: progress * 2 * math.pi,
                          child: Icon(centerIcon, color: Colors.white, size: 36),
                        )
                      : Icon(centerIcon, color: Colors.white, size: 36),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusHeader(UpdateService service, Color textPrimary, Color textSecondary) {
    String headline;
    String description;

    switch (service.status) {
      case AppUpdateStatus.checking:
        headline = 'Checking for Updates';
        description = 'Connecting to Ripple Cloud Network...';
        break;
      case AppUpdateStatus.updateAvailable:
        headline = 'New Update Available';
        description = 'An Over-The-Air patch is ready to download.';
        break;
      case AppUpdateStatus.downloading:
        headline = 'Downloading Update';
        description = 'Streaming delta snapshot from cloud CDN...';
        break;
      case AppUpdateStatus.restartRequired:
        headline = 'Update Staged & Ready';
        description = 'Restart Ripple to activate the newest improvements.';
        break;
      case AppUpdateStatus.error:
        headline = 'Update Check Paused';
        description = 'Network was unable to complete the query.';
        break;
      case AppUpdateStatus.idle:
      case AppUpdateStatus.upToDate:
        headline = 'Ripple is Up to Date';
        description = 'Your app has all the latest features and security protocols.';
        break;
    }

    return Column(
      children: [
        Text(
          headline,
          style: TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          textAlign: TextAlign.center,
          style: TextStyle(color: textSecondary, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildSpecRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color textPrimary,
    required Color textSecondary,
    Widget? trailingBadge,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(color: textSecondary, fontSize: 13),
        ),
        const Spacer(),
        if (trailingBadge != null) ...[
          trailingBadge,
          const SizedBox(width: 8),
        ],
        Text(
          value,
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(UpdateService service, BuildContext context) {
    if (service.status == AppUpdateStatus.restartRequired) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.restart_alt_rounded, color: Colors.white, size: 22),
          label: const Text(
            'Restart Ripple Now',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFA855F7),
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: () => service.restartApp(),
        ),
      );
    }

    if (service.status == AppUpdateStatus.updateAvailable) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.cloud_download_rounded, color: Colors.white, size: 22),
          label: const Text(
            'Download & Install Update',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7),
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: () => service.downloadAndInstallUpdate(),
        ),
      );
    }

    final isBusy = service.status == AppUpdateStatus.checking ||
        service.status == AppUpdateStatus.downloading;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.aquaCore, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: isBusy ? null : () => service.checkForUpdates(),
        child: isBusy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.aquaCore),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.refresh_rounded, color: AppColors.aquaCore, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Check for Updates',
                    style: TextStyle(
                      color: AppColors.aquaCore,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  String _formatLastChecked(DateTime? dt) {
    if (dt == null) return 'Never';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
