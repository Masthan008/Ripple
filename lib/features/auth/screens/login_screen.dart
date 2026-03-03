import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/floating_particles.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/google_logo.dart';
import '../../../shared/widgets/water_ripple_painter.dart';
import '../providers/auth_provider.dart';

/// Login / Register Screen — PRD §6.1
/// Liquid Glass card with Google + Email auth, water ripple effects
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
    _cardAnimController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _cardAnimController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithGoogle();
      if (mounted) context.go('/home');
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
        await authService.signUpWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
          name: _nameController.text,
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Password reset email sent!'),
            backgroundColor: AppColors.aquaCore.withValues(alpha: 0.9),
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
    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      body: Stack(
        children: [
          // Floating particles
          const FloatingParticles(particleCount: 5),

          // Background glowing blobs
          Positioned(
            top: -100,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.aquaCore.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -80,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.aquaCyan.withValues(alpha: 0.08),
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
                  child: _buildContent(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
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
                color: AppColors.aquaCyan.withValues(alpha: 0.35),
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
          shaderCallback: (bounds) => AppColors.aquaGradient.createShader(
            Rect.fromLTWH(0, 0, bounds.width, bounds.height),
          ),
          child: Text(
            AppStrings.appName,
            style: AppTextStyles.display.copyWith(color: Colors.white),
          ),
        ),

        const SizedBox(height: 6),

        Text(AppStrings.appTagline, style: AppTextStyles.subtitle),

        const SizedBox(height: 32),

        // Glass Card
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
                      color: AppColors.glassPanel,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Google logo
                        const GoogleLogo(size: 22),
                        const SizedBox(width: 12),
                        Text(
                          AppStrings.continueWithGoogle,
                          style: AppTextStyles.button,
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
                        color: AppColors.glassBorderLight,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        AppStrings.or,
                        style: AppTextStyles.caption,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: AppColors.glassBorderLight,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Name field (sign up only)
                if (_isSignUp) ...[
                  _buildTextField(
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
                  controller: _passwordController,
                  hint: AppStrings.password,
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textMuted,
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
                    controller: _confirmPasswordController,
                    hint: AppStrings.confirmPassword,
                    icon: Icons.lock_outline_rounded,
                    obscure: _obscureConfirmPassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.textMuted,
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
                          color: AppColors.aquaCore,
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
                      color: AppColors.errorRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.errorRed.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.errorRed,
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
                      gradient: AppColors.buttonGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.aquaCore.withValues(alpha: 0.35),
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
                              style: AppTextStyles.button,
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
                      style: AppTextStyles.caption,
                    ),
                    GestureDetector(
                      onTap: _toggleMode,
                      child: Text(
                        _isSignUp ? AppStrings.signIn : AppStrings.signUp,
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.aquaCore,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
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
      style: AppTextStyles.body,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
