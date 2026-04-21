import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../shared/widgets/floating_particles.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/google_logo.dart';
import '../../../shared/widgets/water_ripple_painter.dart';
import '../providers/auth_provider.dart';

/// Login / Register Screen — PRD §6.1
/// Liquid Glass card with Google + Email auth, water ripple effects
/// Fully theme-aware — adapts to light and dark modes
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  late AnimationController _cardAnimController;
  late Animation<double> _cardSlideAnim;
  late Animation<double> _cardOpacityAnim;

  // Shimmer sweep animation for glass card
  late AnimationController _shimmerController;
  late Animation<double> _shimmerPosition;

  @override
  void initState() {
    super.initState();
    _cardAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _cardSlideAnim = Tween<double>(begin: 60, end: 0).animate(
      CurvedAnimation(parent: _cardAnimController, curve: Curves.easeOutBack),
    );
    _cardOpacityAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _cardAnimController,
        curve: const Interval(0, 0.6, curve: Curves.easeIn),
      ),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _shimmerPosition = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOutCubic),
    );

    _cardAnimController.forward();
    // Start shimmer after card settles
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _shimmerController.forward();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _cardAnimController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.signInWithGoogle();
      if (result == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      if (mounted) {
        if (result.isNewUser) {
          final user = result.credential.user!;
          context.go(
            '/register?uid=${user.uid}'
            '&name=${Uri.encodeComponent(user.displayName ?? '')}'
            '&email=${Uri.encodeComponent(user.email ?? '')}'
            '&photoUrl=${Uri.encodeComponent(user.photoURL ?? '')}'
            '&isGoogleSignIn=true',
          );
        } else {
          context.go('/home');
        }
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);

      if (_isSignUp) {
        final result = await authService.signUpWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
          name: _nameController.text,
        );
        if (mounted) {
          context.go(
            '/register?uid=${result.credential.user!.uid}'
            '&name=${Uri.encodeComponent(_nameController.text.trim())}'
            '&email=${Uri.encodeComponent(_emailController.text.trim())}',
          );
          return;
        }
      } else {
        await authService.signInWithEmail(
          _emailController.text,
          _passwordController.text,
        );
      }
      if (mounted) context.go('/home');
    } catch (e) {
      String message = e.toString();
      if (message.contains('user-not-found')) {
        message = 'No account found with this email.';
      } else if (message.contains('wrong-password')) {
        message = 'Incorrect password.';
      } else if (message.contains('email-already-in-use')) {
        message = 'An account already exists with this email.';
      } else if (message.contains('weak-password')) {
        message = AppStrings.errorWeakPassword;
      }
      setState(() => _errorMessage = message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Enter your email above to reset.');
      return;
    }
    try {
      final authService = ref.read(authServiceProvider);
      await authService.resetPassword(email);
      if (mounted) {
        final theme = ref.read(rippleThemeProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Password reset email sent!'),
            backgroundColor: theme.colors.primary.withOpacity(0.9),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  void _toggleMode() {
    setState(() {
      _isSignUp = !_isSignUp;
      _errorMessage = null;
    });
    _cardAnimController.forward(from: 0.3);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(rippleThemeProvider);

    return Scaffold(
      backgroundColor: theme.colors.background,
      body: Stack(
        children: [
          // Floating particles
          const FloatingParticles(particleCount: 5),

          // Background glowing blobs
          Positioned(
            top: -100,
            right: -60,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    theme.colors.secondary.withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    theme.colors.primary.withOpacity(0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AnimatedBuilder(
                  animation: _cardAnimController,
                  builder: (_, child) => Opacity(
                    opacity: _cardOpacityAnim.value,
                    child: Transform.translate(
                      offset: Offset(0, _cardSlideAnim.value),
                      child: child,
                    ),
                  ),
                  child: _buildContent(theme),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(dynamic theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: theme.colors.primary.withOpacity(0.35),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/ripple_logo.png',
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Title
        ShaderMask(
          shaderCallback: (bounds) => theme.gradients.primary.createShader(
            Rect.fromLTWH(0, 0, bounds.width, bounds.height),
          ),
          child: Text(
            AppStrings.appName,
            style: AppTextStyles.display.copyWith(color: Colors.white),
          ),
        ),

        const SizedBox(height: 6),

        Text(
          AppStrings.appTagline,
          style: AppTextStyles.subtitle.copyWith(
            color: theme.colors.textSecondary,
          ),
        ),

        const SizedBox(height: 32),

        // Glass Card with shimmer sweep
        Stack(
          children: [
            GlassCard(
              borderRadius: 28,
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Google Sign-In Button
                    WaterRippleEffect(
                      onTap: _isLoading ? null : _signInWithGoogle,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: theme.colors.glassSurface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: theme.colors.glassBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const GoogleLogo(size: 22),
                            const SizedBox(width: 12),
                            Text(
                              AppStrings.continueWithGoogle,
                              style: AppTextStyles.button.copyWith(
                                color: theme.colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Divider
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: theme.colors.glassBorder.withOpacity(0.5),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            AppStrings.or,
                            style: AppTextStyles.caption.copyWith(
                              color: theme.colors.textMuted,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: theme.colors.glassBorder.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Name field (sign up only)
                    if (_isSignUp) ...[
                      _buildTextField(
                        theme: theme,
                        controller: _nameController,
                        hint: AppStrings.fullName,
                        icon: Icons.person_outline_rounded,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return AppStrings.errorNameRequired;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Email field
                    _buildTextField(
                      theme: theme,
                      controller: _emailController,
                      hint: AppStrings.email,
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || !v.contains('@')) {
                          return AppStrings.errorInvalidEmail;
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    // Password field
                    _buildTextField(
                      theme: theme,
                      controller: _passwordController,
                      hint: AppStrings.password,
                      icon: Icons.lock_outline_rounded,
                      obscure: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: theme.colors.textMuted,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      validator: (v) {
                        if (v == null || v.length < 6) {
                          return AppStrings.errorWeakPassword;
                        }
                        return null;
                      },
                    ),

                    // Confirm password (sign up only)
                    if (_isSignUp) ...[
                      const SizedBox(height: 14),
                      _buildTextField(
                        theme: theme,
                        controller: _confirmPasswordController,
                        hint: AppStrings.confirmPassword,
                        icon: Icons.lock_outline_rounded,
                        obscure: _obscureConfirmPassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: theme.colors.textMuted,
                            size: 20,
                          ),
                          onPressed: () => setState(() =>
                              _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                        validator: (v) {
                          if (v != _passwordController.text) {
                            return AppStrings.errorPasswordMismatch;
                          }
                          return null;
                        },
                      ),
                    ],

                    // Forgot password link
                    if (!_isSignUp) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: _resetPassword,
                          child: Text(
                            AppStrings.forgotPassword,
                            style: AppTextStyles.caption.copyWith(
                              color: theme.colors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Error message
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colors.error.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: theme.colors.error.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: AppTextStyles.caption.copyWith(
                            color: theme.colors.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Submit button
                    WaterRippleEffect(
                      onTap: _isLoading ? null : _submitEmail,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: theme.gradients.primary,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colors.primary.withOpacity(0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : Text(
                                  _isSignUp
                                      ? AppStrings.signUp
                                      : AppStrings.signIn,
                                  style: AppTextStyles.button.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Toggle sign in / sign up
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isSignUp
                              ? AppStrings.alreadyHaveAccount
                              : AppStrings.dontHaveAccount,
                          style: AppTextStyles.caption.copyWith(
                            color: theme.colors.textSecondary,
                          ),
                        ),
                        GestureDetector(
                          onTap: _toggleMode,
                          child: Text(
                            _isSignUp ? AppStrings.signIn : AppStrings.signUp,
                            style: AppTextStyles.label.copyWith(
                              color: theme.colors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Shimmer sweep overlay on the glass card
            AnimatedBuilder(
              animation: _shimmerController,
              builder: (_, __) {
                if (_shimmerPosition.value < -0.5 || _shimmerPosition.value > 1.5) {
                  return const SizedBox.shrink();
                }
                return Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(
                              _shimmerPosition.value - 0.5, -0.5,
                            ),
                            end: Alignment(
                              _shimmerPosition.value + 0.5, 0.5,
                            ),
                            colors: [
                              Colors.transparent,
                              theme.colors.primary.withOpacity(0.06),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({
    required dynamic theme,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: AppTextStyles.body.copyWith(color: theme.colors.textPrimary),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.caption.copyWith(color: theme.colors.textMuted),
        prefixIcon: Icon(icon, color: theme.colors.textMuted, size: 20),
        suffixIcon: suffixIcon,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colors.glassBorder.withOpacity(0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colors.primary.withOpacity(0.6),
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colors.error.withOpacity(0.5),
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colors.error.withOpacity(0.7),
          ),
        ),
        filled: true,
        fillColor: theme.colors.glassSurface.withOpacity(theme.isDark ? 0.06 : 0.4),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
