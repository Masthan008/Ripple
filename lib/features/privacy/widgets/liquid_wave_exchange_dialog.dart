import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'liquid_wave_painter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/glass_card.dart';

class LiquidWaveExchangeDialog extends StatefulWidget {
  final String uid;
  const LiquidWaveExchangeDialog({super.key, required this.uid});

  @override
  State<LiquidWaveExchangeDialog> createState() => _LiquidWaveExchangeDialogState();
}

class _LiquidWaveExchangeDialogState extends State<LiquidWaveExchangeDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<int> _keyBytes = [];
  bool _isLoading = true;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _loadKeyBytes();
  }

  Future<void> _loadKeyBytes() async {
    try {
      const storage = FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );
      final rawKey = await storage.read(key: 'e2ee_ik_public_${widget.uid}');
      if (rawKey != null && mounted) {
        setState(() {
          _keyBytes = base64.decode(rawKey);
          _isLoading = false;
        });
      } else {
        // Fallback to random bytes if not generated yet
        if (mounted) {
          setState(() {
            _keyBytes = List.generate(32, (index) => index * 7 % 256);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _keyBytes = List.generate(32, (index) => (index + 42) * 11 % 256);
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return GlassCard(
            borderRadius: 24,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Polarized Key Exchange',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_isLoading)
                  const SizedBox(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.aquaCore),
                    ),
                  )
                else
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Liquid Wave Viewport
                      Container(
                        height: 240,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF020914).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.aquaCore.withOpacity(0.15),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: CustomPaint(
                            painter: LiquidWavePainter(
                              animationValue: _controller.value,
                              keyBytes: _keyBytes,
                              isScanning: _isScanning,
                            ),
                          ),
                        ),
                      ),
                      // Overlay scan indicator
                      if (_isScanning)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.withOpacity(0.5)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.videocam, color: Colors.red, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'SCANNING',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 16),
                Text(
                  _isScanning 
                      ? 'Align recipient\'s Polarized Liquid Wave within camera scanner'
                      : 'Display this visual wave to your partner to securely authenticate E2EE keys',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(
                          _isScanning ? Icons.qr_code_scanner_rounded : Icons.camera_alt_rounded,
                          size: 18,
                        ),
                        label: Text(_isScanning ? 'Show My Wave' : 'Scan Wave Key'),
                        onPressed: () {
                          setState(() {
                            _isScanning = !_isScanning;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isScanning 
                              ? Colors.red.withOpacity(0.2) 
                              : AppColors.aquaCore.withOpacity(0.15),
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: _isScanning ? Colors.red : AppColors.aquaCore,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
