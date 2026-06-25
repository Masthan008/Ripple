import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/glass_card.dart';

class SystemStatusScreen extends StatefulWidget {
  const SystemStatusScreen({super.key});

  @override
  State<SystemStatusScreen> createState() => _SystemStatusScreenState();
}

class _SystemStatusScreenState extends State<SystemStatusScreen> {
  bool _isLoading = true;
  String _firebaseStatus = 'Checking...';
  int _latencyMs = 0;
  String _platformInfo = '';
  String _connectionType = 'Checking...';

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() => _isLoading = true);
    
    // 1. Determine platform info
    if (kIsWeb) {
      _platformInfo = 'Web Browser';
    } else {
      _platformInfo = '${Platform.operatingSystem.toUpperCase()} ${Platform.operatingSystemVersion}';
    }

    // 2. Measure Firestore latency ping
    final stopwatch = Stopwatch()..start();
    try {
      // Fetch a dummy document to measure connection and latency
      await FirebaseFirestore.instance
          .collection('status')
          .doc('ping')
          .get()
          .timeout(const Duration(seconds: 5));
      
      stopwatch.stop();
      _latencyMs = stopwatch.elapsedMilliseconds;
      _firebaseStatus = 'Connected';
      _connectionType = 'Online (Firebase Operational)';
    } catch (e) {
      stopwatch.stop();
      _firebaseStatus = 'Disconnected / Timeout';
      _latencyMs = -1;
      _connectionType = 'Offline or firewall blocking connection';
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _firebaseStatus == 'Connected' ? AppColors.onlineGreen : AppColors.errorRed;

    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      appBar: AppBar(
        title: Text('System Diagnostics', style: AppTextStyles.heading),
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Real-Time Status',
                    style: AppTextStyles.heading.copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Check live diagnostics of your connection to RIPPLE services.',
                    style: AppTextStyles.caption.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 24),

                  // Status overall card
                  GlassCard(
                    borderRadius: 16,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: statusColor,
                                boxShadow: [
                                  BoxShadow(
                                    color: statusColor.withOpacity(0.4),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Server Status: $_firebaseStatus',
                                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _connectionType,
                                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_latencyMs >= 0) ...[
                          const SizedBox(height: 20),
                          const Divider(color: Colors.white10),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Server Latency (RTT)', style: AppTextStyles.body),
                              Text(
                                '${_latencyMs}ms',
                                style: AppTextStyles.heading.copyWith(
                                  color: _latencyMs < 150
                                      ? AppColors.onlineGreen
                                      : _latencyMs < 300
                                          ? AppColors.warningAmber
                                          : AppColors.errorRed,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: (_latencyMs / 500).clamp(0.0, 1.0),
                              backgroundColor: AppColors.glassPanel,
                              valueColor: AlwaysStoppedAnimation(
                                _latencyMs < 150
                                    ? AppColors.onlineGreen
                                    : _latencyMs < 300
                                        ? AppColors.warningAmber
                                        : AppColors.errorRed,
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Device & Environment',
                    style: AppTextStyles.heading.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 8),

                  // Environment details card
                  GlassCard(
                    borderRadius: 16,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _infoRow('Host OS', _platformInfo),
                        const Divider(color: Colors.white10),
                        _infoRow('Database Engine', 'Cloud Firestore Cache'),
                        const Divider(color: Colors.white10),
                        _infoRow('Transport Protocol', 'gRPC-Web / HTTP/2'),
                        const Divider(color: Colors.white10),
                        _infoRow('App Architecture', 'Flutter Framework (Release)'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Diagnostics refresh button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _runDiagnostics,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Refresh Diagnostics'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.aquaCore,
                        side: BorderSide(color: AppColors.aquaCore.withOpacity(0.3)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.caption.copyWith(color: Colors.white70, fontSize: 12)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
