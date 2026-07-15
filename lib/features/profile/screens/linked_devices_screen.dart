import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../shared/widgets/glass_card.dart';

class LinkedDevicesScreen extends StatefulWidget {
  const LinkedDevicesScreen({super.key});

  @override
  State<LinkedDevicesScreen> createState() => _LinkedDevicesScreenState();
}

class _LinkedDevicesScreenState extends State<LinkedDevicesScreen> {
  void _showPairingQrDialog() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Construct a pairing session token containing uid and a temporary challenge
    final pairingToken = 'ripple_pair:$uid:${DateTime.now().millisecondsSinceEpoch}';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0A1628),
          title: const Text('Link a Device', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Scan this QR code from your companion device (Desktop client or Web browser) to link sessions.',
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: QrImageView(
                  data: pairingToken,
                  version: QrVersions.auto,
                  size: 200.0,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Token: ${uid.hashCode}',
                style: const TextStyle(color: Colors.white30, fontSize: 11),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        );
      },
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
                    'Use Ripple across your desktop, tablets, or web browsers by pairing them securely with your primary account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _showPairingQrDialog,
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

            const Text(
              'Active Linked Sessions',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),

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
                      final deviceName = data['deviceName'] as String? ?? 'Client';
                      final platform = data['platform'] as String? ?? 'unknown';
                      final lastActiveTs = data['lastActive'] as Timestamp?;
                      final lastActive = lastActiveTs != null ? lastActiveTs.toDate().toString().split('.').first : 'N/A';

                      return GlassCard(
                        borderRadius: 14,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.aquaCore.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                platform.toLowerCase() == 'android' || platform.toLowerCase() == 'ios'
                                    ? Icons.phone_android_rounded
                                    : Icons.computer_rounded,
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
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
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
