import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/ephemeral_peer.dart';
import '../services/offline_mesh_service.dart';
import 'ephemeral_chat_screen.dart';

class OfflineRadarScreen extends ConsumerStatefulWidget {
  const OfflineRadarScreen({super.key});

  static const routePath = '/offline-radar';

  @override
  ConsumerState<OfflineRadarScreen> createState() => _OfflineRadarScreenState();
}

class _OfflineRadarScreenState extends ConsumerState<OfflineRadarScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _radarAnim;

  @override
  void initState() {
    super.initState();
    _radarAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Start local mesh discovery
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(currentUserProvider).valueOrNull;
      ref.read(offlineMeshServiceProvider).startMesh(customAlias: user?.name);
    });
  }

  @override
  void dispose() {
    _radarAnim.dispose();
    super.dispose();
  }

  void _openChatWithPeer({EphemeralPeer? peer}) {
    AppHaptics.mediumTap();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EphemeralChatScreen(targetPeer: peer),
      ),
    );
  }

  void _editAliasDialog() {
    final mesh = ref.read(offlineMeshServiceProvider);
    final controller = TextEditingController(text: mesh.myAlias);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Colors.white12),
        ),
        title: const Text('Edit Stealth Alias', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter mesh alias',
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
            onPressed: () {
              mesh.setAlias(controller.text);
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Save', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mesh = ref.watch(offlineMeshServiceProvider);
    final peers = ref.watch(discoveredPeersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF060D1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Ripple Mesh', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.onlineGreen.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.onlineGreen.withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    'P2P OFFLINE',
                    style: TextStyle(color: AppColors.onlineGreen, fontSize: 9.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: _editAliasDialog,
              child: Row(
                children: [
                  Text(
                    'Alias: ${mesh.myAlias}',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit, color: AppColors.aquaCore, size: 12),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Enter Broadcast Room',
            icon: const Icon(Icons.forum_rounded, color: AppColors.aquaCore),
            onPressed: () => _openChatWithPeer(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner Notice
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: const [
                Icon(Icons.wifi_off_rounded, color: AppColors.aquaCyan, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'BitChat mode active • Zero internet required • Zero disk persistence • Auto-burns on exit',
                    style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.3),
                  ),
                ),
              ],
            ),
          ),

          // Sonar Radar Canvas
          Expanded(
            flex: 5,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _radarAnim,
                  builder: (context, _) {
                    return CustomPaint(
                      size: const Size(320, 320),
                      painter: _StealthRadarPainter(progress: _radarAnim.value),
                    );
                  },
                ),

                // Center Node (Me)
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.aquaGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.aquaCore.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.radar_rounded, color: Colors.white, size: 28),
                ),

                // Orbiting Discovered Peers
                ...List.generate(peers.length, (index) {
                  final peer = peers[index];
                  final angle = (index * (2 * math.pi / peers.length)) + 0.5;
                  const radius = 115.0;
                  final dx = radius * math.cos(angle);
                  final dy = radius * math.sin(angle);

                  return Transform.translate(
                    offset: Offset(dx, dy),
                    child: GestureDetector(
                      onTap: () => _openChatWithPeer(peer: peer),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF0F172A),
                              border: Border.all(color: AppColors.onlineGreen, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.onlineGreen.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              peer.alias.isNotEmpty ? peer.alias[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              peer.alias,
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          // Discovered Peers List
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF091220),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Nearby Peers (${peers.length})',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.broadcast_on_personal_rounded, size: 16, color: AppColors.aquaCore),
                        label: const Text('Broadcast Chat', style: TextStyle(color: AppColors.aquaCore, fontSize: 12)),
                        onPressed: () => _openChatWithPeer(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: peers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.aquaCore),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Scanning local Wi-Fi / Hotspot for Ripple peers...',
                                  style: TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: peers.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final peer = peers[index];
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.onlineGreen,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            peer.alias,
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          Text(
                                            'IP: ${peer.ipAddress.address} • P2P Direct',
                                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.aquaCore,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      ),
                                      onPressed: () => _openChatWithPeer(peer: peer),
                                      child: const Text('Connect', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StealthRadarPainter extends CustomPainter {
  final double progress;
  _StealthRadarPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    final ringPaint = Paint()
      ..color = const Color(0xFF0EA5E9).withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Draw static concentric distance rings
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, maxRadius * (i / 4), ringPaint);
    }

    // Draw animated stealth radar expanding scan rings
    for (int i = 0; i < 3; i++) {
      final ringProgress = (progress + (i / 3.0)) % 1.0;
      final ringRadius = maxRadius * ringProgress;
      final ringAlpha = (1.0 - ringProgress) * 0.35;

      final scanPaint = Paint()
        ..color = const Color(0xFF22D3EE).withValues(alpha: ringAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, ringRadius, scanPaint);
    }

    // Draw sweeping radar beam line
    final sweepAngle = progress * 2 * math.pi;
    final sweepEnd = Offset(
      center.dx + maxRadius * math.cos(sweepAngle),
      center.dy + maxRadius * math.sin(sweepAngle),
    );

    final linePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF22D3EE).withValues(alpha: 0.6),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius))
      ..strokeWidth = 2.0;

    canvas.drawLine(center, sweepEnd, linePaint);
  }

  @override
  bool shouldRepaint(covariant _StealthRadarPainter oldDelegate) => true;
}
