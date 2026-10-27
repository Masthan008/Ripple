import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../services/web_companion_service.dart';

class WebPairingScreen extends ConsumerStatefulWidget {
  const WebPairingScreen({super.key});

  static const routePath = '/web-pairing';

  @override
  ConsumerState<WebPairingScreen> createState() => _WebPairingScreenState();
}

class _WebPairingScreenState extends ConsumerState<WebPairingScreen> {
  String? _sessionId;
  bool _isLoading = true;
  bool _isExpired = false;
  bool _isApproved = false;
  int _secondsLeft = 60;
  Timer? _countdownTimer;
  StreamSubscription? _sessionSubscription;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _sessionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkExistingSession() async {
    final service = ref.read(webCompanionServiceProvider);
    final session = await service.getSavedWebSession();
    if (session != null && mounted) {
      context.go('/web-main');
      return;
    }
    _initPairingSession();
  }

  Future<void> _initPairingSession() async {
    _countdownTimer?.cancel();
    _sessionSubscription?.cancel();

    setState(() {
      _isLoading = true;
      _isExpired = false;
      _isApproved = false;
      _secondsLeft = 60;
    });

    try {
      final service = ref.read(webCompanionServiceProvider);
      final sessionId = await service.createPairingSession();

      if (!mounted) return;

      setState(() {
        _sessionId = sessionId;
        _isLoading = false;
      });

      // Start 60-second countdown
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_secondsLeft > 1) {
          if (mounted) setState(() => _secondsLeft--);
        } else {
          timer.cancel();
          if (mounted) setState(() => _isExpired = true);
        }
      });

      // Listen for phone scan approval
      _sessionSubscription = service.streamPairingSession(sessionId).listen((doc) {
        if (!doc.exists) return;
        final data = doc.data();
        if (data == null) return;

        if (data['status'] == 'approved') {
          _countdownTimer?.cancel();
          setState(() => _isApproved = true);

          final uid = data['uid'] as String? ?? '';
          final name = data['displayName'] as String? ?? '';
          final photo = data['photoUrl'] as String? ?? '';

          Future.delayed(const Duration(milliseconds: 600), () async {
            await service.completeWebLogin(
              sessionId: sessionId,
              uid: uid,
              displayName: name,
              photoUrl: photo,
            );
            if (mounted) {
              context.go('/web-main');
            }
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize pairing session: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      body: Stack(
        children: [
          // Radiant Light Background Gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF8FAFC), Color(0xFFEDF4FB), Color(0xFFE2ECF8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),

          // Radiant Ambient Light Glows
          Positioned(
            top: -120,
            left: -120,
            child: Container(
              width: 440,
              height: 440,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x220EA5E9),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: Container(
              width: 460,
              height: 460,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x1806B6D4),
              ),
            ),
          ),

          // Main Centered Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Brand Header
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0284C7), Color(0xFF0EA5E9)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                                blurRadius: 18,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.shield_rounded, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Ripple Web',
                          style: AppTextStyles.display.copyWith(
                            color: const Color(0xFF0F172A),
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Link your Ripple mobile app to start messaging on your browser',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: const Color(0xFF64748B),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Pairing Card — Liquid Glass Light Aesthetics
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 840),
                          padding: EdgeInsets.all(isDesktop ? 40 : 26),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white,
                              width: 2.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0EA5E9).withValues(alpha: 0.08),
                                blurRadius: 40,
                                offset: const Offset(0, 16),
                              ),
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: isDesktop
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(child: _buildInstructions()),
                                    const SizedBox(width: 44),
                                    _buildQrBox(),
                                  ],
                                )
                              : Column(
                                  children: [
                                    _buildQrBox(),
                                    const SizedBox(height: 30),
                                    _buildInstructions(),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Security Footer
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_rounded, size: 14, color: Color(0xFF0284C7)),
                        const SizedBox(width: 6),
                        Text(
                          'End-to-end encrypted connection • Your private messages never touch the cloud unencrypted',
                          style: AppTextStyles.caption.copyWith(
                            color: const Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'To use Ripple on your computer:',
          style: AppTextStyles.headingSmall.copyWith(
            color: const Color(0xFF0F172A),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 22),
        _buildStepItem(
          step: '1',
          text: 'Open the Ripple app on your phone',
          icon: Icons.phone_android_rounded,
        ),
        const SizedBox(height: 18),
        _buildStepItem(
          step: '2',
          text: 'Go to Profile > Linked Devices',
          icon: Icons.devices_other_rounded,
        ),
        const SizedBox(height: 18),
        _buildStepItem(
          step: '3',
          text: 'Tap Link a Device and point your phone at this screen',
          icon: Icons.qr_code_scanner_rounded,
        ),
        const SizedBox(height: 26),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0284C7).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt_rounded, color: Color(0xFF0284C7), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Instant peer handshake • No password needed',
                style: TextStyle(
                  color: Color(0xFF0369A1),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepItem({
    required String step,
    required String text,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF0284C7), Color(0xFF0EA5E9)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQrBox() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: _isApproved
                    ? const Color(0xFF10B981).withValues(alpha: 0.3)
                    : const Color(0xFF0284C7).withValues(alpha: 0.15),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_isLoading)
                const CircularProgressIndicator(color: Color(0xFF0284C7))
              else if (_isApproved)
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      ),
                      child: const Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 56),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Linked Successfully!',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                )
              else if (_sessionId != null)
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: QrImageView(
                    data: 'ripple_pair:$_sessionId',
                    version: QrVersions.auto,
                    size: 232.0,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF0F172A),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),

              // Expired overlay
              if (_isExpired && !_isApproved)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.refresh_rounded, color: Color(0xFF0284C7), size: 44),
                        const SizedBox(height: 10),
                        const Text(
                          'QR code expired',
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          onPressed: _initPairingSession,
                          child: const Text(
                            'Click to reload QR',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (!_isExpired && !_isApproved && !_isLoading)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: _secondsLeft / 60.0,
                  color: const Color(0xFF0284C7),
                  backgroundColor: const Color(0xFFE2E8F0),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Auto-refreshes in ${_secondsLeft}s',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
