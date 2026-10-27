import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../web_companion/services/web_companion_service.dart';

class LinkedDevicesScreen extends ConsumerStatefulWidget {
  const LinkedDevicesScreen({super.key});

  @override
  ConsumerState<LinkedDevicesScreen> createState() => _LinkedDevicesScreenState();
}

class _LinkedDevicesScreenState extends ConsumerState<LinkedDevicesScreen> {
  bool _isProcessingScan = false;

  void _openDeviceLinkingScanner() {
    AppHaptics.mediumTap();
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait until profile data is loaded.')),
      );
      return;
    }

    _isProcessingScan = false;
    final controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF060D1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.78,
              child: Stack(
                children: [
                  // Camera Scanner Viewfinder
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: MobileScanner(
                      controller: controller,
                      onDetect: (capture) async {
                        if (_isProcessingScan) return;
                        final barcodes = capture.barcodes;
                        for (final barcode in barcodes) {
                          final code = barcode.rawValue;
                          if (code != null && code.startsWith('ripple_pair:')) {
                            _isProcessingScan = true;
                            AppHaptics.success();

                            final sessionId = code.replaceFirst('ripple_pair:', '').split(':').first;

                            try {
                              await ref.read(webCompanionServiceProvider).approvePairingSession(
                                    sessionId: sessionId,
                                    user: user,
                                    browserInfo: 'Ripple Web Companion',
                                  );

                              if (mounted && ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Companion Web device linked successfully! 🎉'),
                                    backgroundColor: AppColors.onlineGreen,
                                  ),
                                );
                              }
                            } catch (e) {
                              _isProcessingScan = false;
                              if (mounted && ctx.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Pairing failed: $e'),
                                    backgroundColor: AppColors.errorRed,
                                  ),
                                );
                              }
                            }
                            break;
                          }
                        }
                      },
                    ),
                  ),

                  // Scanning Frame Overlay
                  Center(
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.aquaCyan, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.aquaCore.withValues(alpha: 0.25),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Header Bar & Controls
                  Positioned(
                    top: 16,
                    left: 20,
                    right: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                        const Text(
                          'Scan Web QR Code',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 24),
                          onPressed: () => controller.toggleTorch(),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Instruction
                  Positioned(
                    bottom: 30,
                    left: 20,
                    right: 20,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: const Text(
                            'Point your camera at the QR code shown on Ripple Web (your browser screen) to link sessions.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showManualPairingDialog();
                          },
                          child: const Text(
                            'Enter pairing code manually',
                            style: TextStyle(color: AppColors.aquaCyan, fontSize: 13),
                          ),
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
    ).then((_) => controller.dispose());
  }

  void _showManualPairingDialog() {
    final textController = TextEditingController();
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A1628),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Enter Session Code', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: textController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Paste Session UUID or code',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.aquaCore)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.aquaCore),
            onPressed: () async {
              final code = textController.text.trim();
              if (code.isEmpty) return;
              Navigator.pop(ctx);
              try {
                final sessionId = code.replaceFirst('ripple_pair:', '');
                await ref.read(webCompanionServiceProvider).approvePairingSession(
                      sessionId: sessionId,
                      user: user,
                      browserInfo: 'Manual Web Session',
                    );
                AppHaptics.success();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Device linked successfully!'),
                      backgroundColor: AppColors.onlineGreen,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.errorRed),
                  );
                }
              }
            },
            child: const Text('Link', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Future<void> _unlinkDevice(String deviceId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    AppHaptics.mediumTap();

    try {
      await FirebaseService.firestore
          .collection('users')
          .doc(uid)
          .collection('devices')
          .doc(deviceId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device unlinked successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unlink device: $e')),
        );
      }
    }
  }

  Future<void> _terminateAllOtherSessions() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A1628),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Terminate All Other Sessions?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text(
          'Are you sure you want to log out from all other companion apps, desktop clients, and web browsers?',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.aquaCore)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Terminate All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    AppHaptics.heavyTap();

    try {
      final snap = await FirebaseService.firestore
          .collection('users')
          .doc(uid)
          .collection('devices')
          .get();

      final batch = FirebaseService.firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All other sessions terminated successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      appBar: AppBar(
        title: Text('Linked Devices', style: AppTextStyles.headingSmall),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instruction card
            GlassCard(
              borderRadius: 16,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.devices_other_rounded, color: AppColors.aquaCore, size: 40),
                  const SizedBox(height: 12),
                  const Text(
                    'Link Companion Devices',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use Ripple on your computer browser (WhatsWeb style) by scanning the QR code with your phone camera.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _openDeviceLinkingScanner,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text('Link a Device', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.aquaCore,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Active Linked Sessions',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                TextButton.icon(
                  onPressed: _terminateAllOtherSessions,
                  icon: const Icon(Icons.delete_sweep_rounded, size: 16, color: AppColors.errorRed),
                  label: const Text(
                    'Terminate All',
                    style: TextStyle(color: AppColors.errorRed, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (uid != null)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseService.firestore
                    .collection('users')
                    .doc(uid)
                    .collection('devices')
                    .orderBy('lastActive', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white54)));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.aquaCore));
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return GlassCard(
                      borderRadius: 14,
                      padding: const EdgeInsets.all(24),
                      child: const Center(
                        child: Text(
                          'No other devices linked to this account.',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final deviceId = doc.id;
                      final deviceName = data['deviceName'] as String? ?? 'Web Client';
                      final platform = data['platform'] as String? ?? 'Web';
                      final lastActiveTs = data['lastActive'] as Timestamp?;
                      final lastActive = lastActiveTs != null
                          ? lastActiveTs.toDate().toString().split('.').first
                          : 'Just now';

                      return GlassCard(
                        borderRadius: 14,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.aquaCore.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                platform.toLowerCase().contains('phone') ||
                                        platform.toLowerCase().contains('android') ||
                                        platform.toLowerCase().contains('ios')
                                    ? Icons.phone_android_rounded
                                    : Icons.laptop_chromebook_rounded,
                                color: AppColors.aquaCore,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    deviceName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Active: $lastActive',
                                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Disconnect device',
                              icon: const Icon(Icons.link_off_rounded, color: Colors.redAccent),
                              onPressed: () => _unlinkDevice(deviceId),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
