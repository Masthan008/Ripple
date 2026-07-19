import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../auth/providers/auth_provider.dart';

class VerificationWaitingScreen extends ConsumerStatefulWidget {
  const VerificationWaitingScreen({super.key});

  static const routePath = '/verification-waiting';

  @override
  ConsumerState<VerificationWaitingScreen> createState() => _VerificationWaitingScreenState();
}

class _VerificationWaitingScreenState extends ConsumerState<VerificationWaitingScreen> with SingleTickerProviderStateMixin {
  late VideoPlayerController _videoController;
  VideoPlayerController? _successVideoController;
  bool _isVideoInitialized = false;
  bool _isSuccessVideoInitialized = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _isSuccessTriggered = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize video controller
    _videoController = VideoPlayerController.asset(
      'assets/images/3d-casual-life-hiring-an-employee.webm',
    )..initialize().then((_) {
        setState(() {
          _isVideoInitialized = true;
        });
        _videoController.setLooping(true);
        _videoController.play();
      }).catchError((error) {
        debugPrint("Error initializing webm video player: $error");
      });

    // Fade animation for success state
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _videoController.dispose();
    _successVideoController?.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _triggerSuccessFlow() {
    if (_isSuccessTriggered) return;
    _isSuccessTriggered = true;

    // Load success video
    _successVideoController = VideoPlayerController.asset(
      'assets/images/3d-casual-life-hand-holding-phone.webm',
    )..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isSuccessVideoInitialized = true;
          });
          _successVideoController!.play();
          _videoController.pause();
        }
      }).catchError((error) {
        debugPrint("Error initializing success video: $error");
      });

    _fadeController.forward();
    
    // Wait for 5 seconds, then navigate back
    Future.delayed(const Duration(milliseconds: 5000), () {
      if (mounted) {
        // Redirect to settings or pop
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/profile'); // fallback
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    // Monitor isVerified state changes in real-time
    userAsync.whenData((user) {
      if (user != null && user.isVerified) {
        // If the admin verified them (isVerified = true), play success animation
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _triggerSuccessFlow();
        });
      }
    });

    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      body: Stack(
        children: [
          // Aquatic Glow
          Positioned(
            top: 100,
            left: 50,
            child: Container(
              width: 250,
              height: 250,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x080EA5E9),
              ),
            ),
          ),
          
          // Main content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),
                
                // Video Player Container
                Center(
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      color: AppColors.glassPanel,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.glassBorderLight,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.aquaCore.withOpacity(0.05),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _isVideoInitialized
                        ? ClipOval(
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _videoController.value.size.width,
                                height: _videoController.value.size.height,
                                child: VideoPlayer(_videoController),
                              ),
                            ),
                          )
                        : const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation(AppColors.aquaCore),
                            ),
                          ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                if (userAsync.value != null) ...[
                  Builder(builder: (context) {
                    final user = userAsync.value!;
                    final plan = user.subscriptionPlan ?? '';
                    final isVIP = plan == 'Abyss Platinum' || plan == 'Premium Trial';
                    
                    return Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isVIP
                              ? AppColors.aquaCore.withOpacity(0.15)
                              : Colors.white10,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isVIP
                                ? AppColors.aquaCore.withOpacity(0.4)
                                : Colors.white24,
                            width: 1,
                          ),
                          boxShadow: [
                            if (isVIP)
                              BoxShadow(
                                color: AppColors.aquaCore.withOpacity(0.1),
                                blurRadius: 8,
                              ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isVIP ? Icons.workspace_premium_rounded : Icons.schedule_rounded,
                              color: isVIP ? AppColors.aquaCore : Colors.white70,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isVIP ? 'VIP High-Priority Queue' : 'Standard Priority Queue',
                              style: TextStyle(
                                color: isVIP ? Colors.white : Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],
                
                // Real-time Text Status
                Text(
                  'Waiting for Approval',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.display.copyWith(
                    fontSize: 24,
                    color: Colors.white,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                Text(
                  (userAsync.value != null && (userAsync.value!.subscriptionPlan == 'Abyss Platinum' || userAsync.value!.subscriptionPlan == 'Premium Trial'))
                      ? 'Please wait while the admin verifies your profile. Your request is in the VIP High-Priority queue and is typically approved in under 2 hours.'
                      : 'Please wait while the admin verifies your profile. Verification usually takes up to 24 hours on the standard priority queue.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                
                const Spacer(),
                
                // Back Button (so they don't get completely locked out of the app while waiting)
                Padding(
                  padding: const EdgeInsets.only(bottom: 30.0),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.aquaCore,
                      side: const BorderSide(color: AppColors.glassBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/profile');
                      }
                    },
                    child: Text(
                      'Back to Settings',
                      style: AppTextStyles.label.copyWith(color: AppColors.aquaCyan),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Real-time Success Overlay
          if (_isSuccessTriggered)
            FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                color: AppColors.abyssBackground,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Circular success animation player
                      Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          color: AppColors.glassPanel,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.aquaCore.withOpacity(0.3),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.aquaCore.withOpacity(0.1),
                              blurRadius: 40,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _isSuccessVideoInitialized
                            ? ClipOval(
                                child: FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: _successVideoController!.value.size.width,
                                    height: _successVideoController!.value.size.height,
                                    child: VideoPlayer(_successVideoController!),
                                  ),
                                ),
                              )
                            : const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation(AppColors.aquaCore),
                                ),
                              ),
                      ),
                      const SizedBox(height: 36),
                      Text(
                        'Profile Verified!',
                        style: AppTextStyles.display.copyWith(
                          fontSize: 28,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40.0),
                        child: Text(
                          'Congratulations! Your Ripple Verified badge is now active.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
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
}
