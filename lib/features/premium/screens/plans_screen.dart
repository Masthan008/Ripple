import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/env.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/models/user_model.dart';
import '../services/subscription_service.dart';
import 'verification_waiting_screen.dart';

class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key});

  static const routePath = '/plans';

  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen> {
  late Razorpay _razorpay;
  UserModel? _currentUser;
  String _selectedPlan = '';
  double _selectedPrice = 0.0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final subService = ref.read(subscriptionServiceProvider);
      if (_currentUser != null) {
        await subService.purchasePremiumPlan(
          uid: _currentUser!.uid,
          planName: _selectedPlan,
          price: _selectedPrice,
          paymentId: response.paymentId ?? '',
          orderId: response.orderId ?? '',
          signature: response.signature ?? '',
        );

        AppHaptics.success();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment Successful! Initializing verification...'),
              backgroundColor: AppColors.onlineGreen,
            ),
          );
          context.pushReplacement(VerificationWaitingScreen.routePath);
        }
      }
    } catch (e) {
      AppHaptics.heavyTap();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update subscription in database: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    AppHaptics.heavyTap();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment Failed: ${response.message} (Code: ${response.code})'),
        backgroundColor: AppColors.errorRed,
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('External Wallet Selected: ${response.walletName}'),
        backgroundColor: AppColors.warningAmber,
      ),
    );
  }

  void _initiateRazorpayPayment(String planName, double price) {
    AppHaptics.mediumTap();
    _selectedPlan = planName;
    _selectedPrice = price;

    if (_currentUser == null) return;

    final keyId = Env.razorpayKeyId.trim();
    
    // Check if key is unconfigured or a placeholder
    if (keyId.isEmpty || keyId.startsWith('rzp_live_XX') || keyId.startsWith('rzp_test_XX') || keyId.contains('XXXX')) {
      _showDemoSimulatorDialog(planName, price);
      return;
    }

    var options = {
      'key': keyId,
      'amount': (price * 100).toInt(), // Amount in paise
      'name': 'Ripple Premium',
      'description': 'Subscription to $planName',
      'prefill': {
        'contact': '',
        'email': _currentUser!.email,
      },
      'theme': {
        'color': '#0EA5E9',
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open Razorpay checkout: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Future<void> _activateFreeTrial() async {
    if (_currentUser == null) return;
    AppHaptics.mediumTap();
    
    setState(() {
      _isLoading = true;
    });

    try {
      final subService = ref.read(subscriptionServiceProvider);
      await subService.startTrial(_currentUser!.uid);

      AppHaptics.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Free Trial Activated! Redirecting...'),
            backgroundColor: AppColors.onlineGreen,
          ),
        );
        context.pushReplacement(VerificationWaitingScreen.routePath);
      }
    } catch (e) {
      AppHaptics.heavyTap();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to activate trial: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showDemoSimulatorDialog(String planName, double price) {
    final theme = ref.read(rippleThemeProvider);
    final isDark = theme.isDark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? AppColors.glassBorder : Colors.black12,
          ),
        ),
        title: Row(
          children: [
            const Icon(Icons.payment_rounded, color: AppColors.aquaCore),
            const SizedBox(width: 10),
            Text(
              'Razorpay Simulator',
              style: AppTextStyles.heading.copyWith(
                color: isDark ? Colors.white : const Color(0xFF0D1117),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No valid Razorpay Key ID detected in your .env file.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.errorRed),
            ),
            const SizedBox(height: 12),
            Text(
              'Configure RAZORPAY_KEY_ID inside your local `.env` file to process actual live or test checkout transactions on mobile devices.',
              style: AppTextStyles.body.copyWith(
                color: isDark ? AppColors.textSecondary : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppColors.glassBorderLight : Colors.black12,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Plan: $planName', style: AppTextStyles.label.copyWith(color: AppColors.aquaCyan)),
                  const SizedBox(height: 4),
                  Text(
                    'Amount: ₹${price.toStringAsFixed(2)}',
                    style: AppTextStyles.body.copyWith(
                      color: isDark ? Colors.white : const Color(0xFF0D1117),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black54,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.onlineGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _handlePaymentSuccess(
                PaymentSuccessResponse(
                  'pay_mock_${DateTime.now().millisecondsSinceEpoch}',
                  'order_mock_${DateTime.now().millisecondsSinceEpoch}',
                  'sig_mock_${DateTime.now().millisecondsSinceEpoch}',
                  const {},
                ),
              );
            },
            child: const Text('Simulate Success', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(rippleThemeProvider);
    final isDark = theme.isDark;
    final userAsync = ref.watch(currentUserProvider);

    final bgGrad = isDark
        ? const LinearGradient(
            colors: [Color(0xFF060D1A), Color(0xFF0A192F), Color(0xFF040914)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          )
        : const LinearGradient(
            colors: [Color(0xFFF8FAFC), Color(0xFFEEF2F6), Color(0xFFE2E8F0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          );

    final textColor = isDark ? Colors.white : const Color(0xFF0D1117);
    final textMuted = isDark ? AppColors.textSecondary : const Color(0xFF64748B);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return Scaffold(
            backgroundColor: theme.colors.background,
            body: Center(
              child: Text(
                'User details not found.',
                style: TextStyle(color: textColor),
              ),
            ),
          );
        }
        _currentUser = user;

        // Redirect to waiting screen if user already paid and verification is pending
        if (user.verificationStatus == 'pending') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.pushReplacement(VerificationWaitingScreen.routePath);
            }
          });
        }

        return Scaffold(
          backgroundColor: theme.colors.background,
          appBar: AppBar(
            title: Text(
              'Ripple Premium & Verified',
              style: AppTextStyles.heading.copyWith(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(
              color: isDark ? AppColors.aquaCore : const Color(0xFF0D1117),
            ),
          ),
          body: Stack(
            children: [
              // Dynamic Background Gradient
              Positioned.fill(
                child: Container(decoration: BoxDecoration(gradient: bgGrad)),
              ),

              // Ambient Liquid Glows
              Positioned(
                top: -80,
                right: -80,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (isDark ? const Color(0xFF0EA5E9) : const Color(0xFF38BDF8))
                        .withValues(alpha: isDark ? 0.09 : 0.14),
                  ),
                ),
              ),
              Positioned(
                bottom: -80,
                left: -80,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (isDark ? const Color(0xFF22D3EE) : const Color(0xFF0284C7))
                        .withValues(alpha: isDark ? 0.08 : 0.12),
                  ),
                ),
              ),

              // Main Content Scroll
              _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(AppColors.aquaCore),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: AnimationLimiter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: AnimationConfiguration.toStaggeredList(
                            duration: const Duration(milliseconds: 400),
                            childAnimationBuilder: (widget) => SlideAnimation(
                              verticalOffset: 40.0,
                              child: FadeInAnimation(child: widget),
                            ),
                            children: [
                              // Hero Verified Badge Animation
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: (isDark ? const Color(0xFF0EA5E9) : const Color(0xFF1A8CFF))
                                        .withValues(alpha: 0.12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0EA5E9).withValues(alpha: 0.25),
                                        blurRadius: 24,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Image.asset(
                                    'assets/images/icons8-verified-badge-96.gif',
                                    width: 72,
                                    height: 72,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Unlock Ripple Premium',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.display.copyWith(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: textColor,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'Elevate your presence with verified trust, up to 10 GB cloud storage, custom dynamic launcher icons, multi-device web pairing, and VIP speed.',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.body.copyWith(
                                    color: textMuted,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Plan 1: 1-Month Free Trial Card
                              _buildTrialCard(user, isDark),
                              const SizedBox(height: 18),

                              // Plan 2: Gold Monthly Card
                              _buildPremiumCard(
                                title: 'Gold Monthly',
                                price: 199.00,
                                billingCycle: '/month',
                                icon: Icons.star_rounded,
                                badgeText: 'POPULAR',
                                color: const Color(0xFFF59E0B),
                                isDark: isDark,
                                features: [
                                  'Official Verified Gold Badge (✓) across all chats & search',
                                  '4 GB High-Speed Cloud File & Media Uploads (8x Free)',
                                  'Up to 20 Pinned Conversations & 500 Group memberships',
                                  '6 Custom Dynamic App Launcher Icons',
                                  'Ripple Web Multi-Device Companion Linking',
                                  'Exclusive Liquid Glass UI themes & accent styling',
                                ],
                              ),
                              const SizedBox(height: 18),

                              // Plan 3: Abyss Platinum Card
                              _buildPremiumCard(
                                title: 'Abyss Platinum',
                                price: 499.00,
                                billingCycle: '/month',
                                icon: Icons.workspace_premium_rounded,
                                badgeText: 'ULTIMATE',
                                color: const Color(0xFF0EA5E9),
                                isDark: isDark,
                                features: [
                                  'All Gold Monthly features included',
                                  'Exclusive Abyss Platinum Crown Badge (👑) on profile & chats',
                                  '10 GB Maximum File & Video Upload limit',
                                  'High-Speed Media Download priority CDN acceleration',
                                  'Unlimited Pinned Conversations & Unlimited Groups',
                                  'Custom Notification Sounds & Granular Stealth Privacy Locks',
                                  'Instant VIP Verification Review Queue',
                                  'Direct 24/7 Priority Ripple Concierge Support',
                                ],
                              ),
                              const SizedBox(height: 36),
                            ],
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        );
      },
      loading: () => Scaffold(
        backgroundColor: theme.colors.background,
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.aquaCore),
          ),
        ),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: theme.colors.background,
        body: Center(
          child: Text(
            'Error loading user profile: $err',
            style: TextStyle(color: textColor),
          ),
        ),
      ),
    );
  }

  Widget _buildTrialCard(UserModel user, bool isDark) {
    final bool hasUsed = user.hasUsedTrial;

    final cardBg = isDark
        ? const Color(0xFF0E1928).withValues(alpha: 0.72)
        : Colors.white.withValues(alpha: 0.85);
    final borderColor = hasUsed
        ? (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black12)
        : (isDark
            ? AppColors.aquaCore.withValues(alpha: 0.5)
            : const Color(0xFF1A8CFF).withValues(alpha: 0.4));
    final textColor = isDark ? Colors.white : const Color(0xFF0D1117);
    final textMuted = isDark ? AppColors.textSecondary : const Color(0xFF64748B);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
              if (!hasUsed)
                BoxShadow(
                  color: AppColors.aquaCore.withValues(alpha: isDark ? 0.12 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (hasUsed ? Colors.grey : AppColors.aquaCore)
                              .withValues(alpha: 0.15),
                        ),
                        child: Icon(
                          Icons.card_giftcard_rounded,
                          color: hasUsed ? Colors.grey : AppColors.aquaCore,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '1-Month Free Trial',
                        style: AppTextStyles.headingSmall.copyWith(
                          color: hasUsed ? textMuted : textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: hasUsed
                          ? (isDark ? Colors.white10 : Colors.black12)
                          : AppColors.aquaCore.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      hasUsed ? 'Redeemed' : '30 Days Free',
                      style: AppTextStyles.caption.copyWith(
                        color: hasUsed ? textMuted : AppColors.aquaCore,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Experience full verified status and premium cloud features with zero upfront commitment. Valid for 30 full days.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: textMuted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Divider(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black12,
                height: 1,
              ),
              const SizedBox(height: 12),
              ...[
                '30-Day Full Access to Gold Verified Badge (✓)',
                '4 GB High-Speed Cloud File & Media Uploads',
                '6 Custom Dynamic App Launcher Icons',
                'Up to 20 Pinned Chats & 500 Group memberships',
                'Full access to all Liquid Glass themes & Web pairing',
              ].map((feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: hasUsed ? textMuted : AppColors.onlineGreen,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            feature,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: hasUsed ? textMuted : textColor,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasUsed
                        ? (isDark ? Colors.white12 : Colors.black12)
                        : AppColors.aquaCore,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: hasUsed ? 0 : 2,
                  ),
                  onPressed: hasUsed ? null : _activateFreeTrial,
                  child: Text(
                    hasUsed ? 'Trial Already Redeemed' : 'Claim Free 30-Day Trial',
                    style: AppTextStyles.label.copyWith(
                      color: hasUsed ? textMuted : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumCard({
    required String title,
    required double price,
    required String billingCycle,
    required IconData icon,
    required String badgeText,
    required Color color,
    required bool isDark,
    required List<String> features,
  }) {
    final cardBg = isDark
        ? const Color(0xFF0E1928).withValues(alpha: 0.76)
        : Colors.white.withValues(alpha: 0.88);
    final borderColor = isDark
        ? color.withValues(alpha: 0.35)
        : color.withValues(alpha: 0.4);
    final textColor = isDark ? Colors.white : const Color(0xFF0D1117);
    final textMuted = isDark ? AppColors.textSecondary : const Color(0xFF64748B);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: color.withValues(alpha: isDark ? 0.1 : 0.06),
                blurRadius: 18,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withValues(alpha: 0.18),
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        title,
                        style: AppTextStyles.headingSmall.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withValues(alpha: 0.9), color],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badgeText,
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '₹${price.toStringAsFixed(0)}',
                    style: AppTextStyles.display.copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    billingCycle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black12,
                height: 1,
              ),
              const SizedBox(height: 12),
              ...features.map((feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.onlineGreen,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            feature,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: textColor,
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.85), color],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _initiateRazorpayPayment(title, price),
                    child: Text(
                      'Upgrade to $title',
                      style: AppTextStyles.label.copyWith(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
