import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/env.dart';
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

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment Successful! Initializing verification...'),
              backgroundColor: AppColors.onlineGreen,
            ),
          );
          // Navigate to waiting screen
          context.pushReplacement(VerificationWaitingScreen.routePath);
        }
      }
    } catch (e) {
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
    
    setState(() {
      _isLoading = true;
    });

    try {
      final subService = ref.read(subscriptionServiceProvider);
      await subService.startTrial(_currentUser!.uid);

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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.glassBorder),
        ),
        title: Row(
          children: [
            const Icon(Icons.payment_rounded, color: AppColors.aquaCore),
            const SizedBox(width: 10),
            Text(
              'Razorpay Simulator',
              style: AppTextStyles.heading.copyWith(color: Colors.white),
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
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.glassBorderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Plan: $planName', style: AppTextStyles.label.copyWith(color: AppColors.aquaCyan)),
                  const SizedBox(height: 4),
                  Text('Amount: ₹${price.toStringAsFixed(2)}', style: AppTextStyles.body.copyWith(color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.6))),
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
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(
            backgroundColor: AppColors.abyssBackground,
            body: Center(child: Text('User details not found.', style: TextStyle(color: Colors.white))),
          );
        }
        _currentUser = user;

        // Redirect to waiting screen if user already paid and verification is pending
        if (user.verificationStatus == 'pending') {
          Future.microtask(() {
            if (mounted) {
              context.pushReplacement(VerificationWaitingScreen.routePath);
            }
          });
        }

        return Scaffold(
          backgroundColor: AppColors.abyssBackground,
          appBar: AppBar(
            title: Text('Ripple Verified', style: AppTextStyles.heading),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: AppColors.aquaCore),
          ),
          body: Stack(
            children: [
              // Aquatic glow elements
              Positioned(
                top: -100,
                right: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x0C0EA5E9),
                  ),
                ),
              ),
              Positioned(
                bottom: -80,
                left: -80,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x0C22D3EE),
                  ),
                ),
              ),
              
              // Content
              _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(AppColors.aquaCore),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: AnimationLimiter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: AnimationConfiguration.toStaggeredList(
                            duration: const Duration(milliseconds: 500),
                            childAnimationBuilder: (widget) => SlideAnimation(
                              verticalOffset: 50.0,
                              child: FadeInAnimation(child: widget),
                            ),
                            children: [
                              // Screen Header Icon + Title
                              const SizedBox(height: 10),
                              Center(
                                child: Image.asset(
                                  'assets/images/icons8-verified-badge-96.gif',
                                  width: 80,
                                  height: 80,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Get Verified on Ripple',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.display.copyWith(
                                  fontSize: 28,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Build trust, unlock premium styling, and show off your verified status across chats.',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 30),

                              // Plan 1: Free Trial Card
                              _buildTrialCard(user),
                              const SizedBox(height: 20),

                              // Plan 2: Gold Monthly
                              _buildPremiumCard(
                                title: 'Gold Monthly',
                                price: 299.00,
                                billingCycle: '/month',
                                icon: Icons.star_border_rounded,
                                color: const Color(0xFFFBBF24),
                                features: [
                                  'Verified Badge across all chats & screens',
                                  'Premium Liquid Glass theme selection',
                                  'Custom chat bubbles and colors',
                                  'Ad-free clean AI Sentience Currents',
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Plan 3: Abyss Platinum
                              _buildPremiumCard(
                                title: 'Abyss Platinum',
                                price: 999.00,
                                billingCycle: '/month',
                                icon: Icons.workspace_premium_rounded,
                                color: AppColors.aquaCyan,
                                features: [
                                  'VIP High-Priority Verification (under 2 hours)',
                                  'Exclusive Abyss Telepathy glow animation effects',
                                  'Direct premium support channels',
                                  'Early access to revolutionary AI features',
                                ],
                              ),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        backgroundColor: AppColors.abyssBackground,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.aquaCore),
          ),
        ),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: AppColors.abyssBackground,
        body: Center(
          child: Text('Error loading user profile: $err', style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildTrialCard(UserModel user) {
    final bool hasUsed = user.hasUsedTrial;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.glassPanel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasUsed ? AppColors.glassBorderLight : AppColors.aquaCore.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          if (!hasUsed)
            BoxShadow(
              color: AppColors.aquaCore.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
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
              Text(
                '1-Month Free Trial',
                style: AppTextStyles.headingSmall.copyWith(
                  color: hasUsed ? AppColors.textMuted : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: hasUsed ? Colors.white10 : AppColors.aquaCore.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  hasUsed ? 'Used' : 'Available',
                  style: AppTextStyles.caption.copyWith(
                    color: hasUsed ? AppColors.textMuted : AppColors.biolume,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Try the verified badge completely free for 30 days. Perfect for experimenting with Ripple\'s verified identity systems.',
            style: AppTextStyles.bodySmall.copyWith(
              color: hasUsed ? AppColors.textMuted : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: hasUsed ? Colors.white10 : AppColors.aquaCore,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: hasUsed ? null : _activateFreeTrial,
              child: Text(
                hasUsed ? 'Trial Already Redeemed' : 'Claim Free Trial',
                style: AppTextStyles.label.copyWith(
                  color: hasUsed ? AppColors.textMuted : Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumCard({
    required String title,
    required double price,
    required String billingCycle,
    required IconData icon,
    required Color color,
    required List<String> features,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.glassPanel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.glassBorder,
          width: 1.0,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 10),
              Text(
                title,
                style: AppTextStyles.headingSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
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
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                billingCycle,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.glassBorderLight),
          const SizedBox(height: 10),
          ...features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppColors.onlineGreen,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.8), color],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
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
                  'Subscribe Now',
                  style: AppTextStyles.label.copyWith(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
