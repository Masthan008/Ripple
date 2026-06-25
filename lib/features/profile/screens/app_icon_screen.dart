import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/app_icon_service.dart';
import '../../../shared/widgets/glass_card.dart';

class AppIconScreen extends StatefulWidget {
  const AppIconScreen({super.key});

  @override
  State<AppIconScreen> createState() => _AppIconScreenState();
}

class _AppIconScreenState extends State<AppIconScreen> {
  String _currentIcon = 'Default';
  bool _isLoading = true;

  final List<Map<String, dynamic>> _iconOptions = [
    {
      'id': 'Default',
      'name': 'Aquatic Core (Default)',
      'desc': 'Classic glowing cyan/aqua fluid drop.',
      'gradient': const LinearGradient(
        colors: [Color(0xFF0D9488), Color(0xFF0EA5E9)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'glow': const Color(0xFF0EA5E9),
    },
    {
      'id': 'Abyss',
      'name': 'Midnight Abyss',
      'desc': 'Deep dark purple and indigo swirls.',
      'gradient': const LinearGradient(
        colors: [Color(0xFF581C87), Color(0xFF6366F1)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'glow': const Color(0xFF6366F1),
    },
    {
      'id': 'Gold',
      'name': 'Liquid Gold',
      'desc': 'Metallic liquid gold chrome finish.',
      'gradient': const LinearGradient(
        colors: [Color(0xFFD97706), Color(0xFFFBBF24)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'glow': const Color(0xFFFBBF24),
    },
    {
      'id': 'Glitch',
      'name': 'Neon Glitch',
      'desc': 'Cyberpunk hot pink and neon cyan glitch.',
      'gradient': const LinearGradient(
        colors: [Color(0xFFEC4899), Color(0xFF06B6D4)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'glow': const Color(0xFFEC4899),
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentIcon();
  }

  Future<void> _loadCurrentIcon() async {
    final active = await AppIconService.getCurrentIcon();
    if (mounted) {
      setState(() {
        _currentIcon = active;
        _isLoading = false;
      });
    }
  }

  Future<void> _changeIcon(String id) async {
    if (id == _currentIcon) return;
    setState(() => _isLoading = true);

    final success = await AppIconService.changeIcon(id);
    
    if (mounted) {
      setState(() {
        if (success) {
          _currentIcon = id;
        }
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success 
              ? 'App icon changed successfully! Your launcher will update in a moment.' 
              : 'Failed to change app icon. Ensure permissions are set.',
          ),
          backgroundColor: success ? AppColors.onlineGreen : AppColors.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      appBar: AppBar(
        title: Text('Custom App Icon', style: AppTextStyles.heading),
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
          : AnimationLimiter(
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _iconOptions.length,
                itemBuilder: (context, index) {
                  final opt = _iconOptions[index];
                  final isCurrent = opt['id'].toString().toLowerCase() == _currentIcon.toLowerCase();

                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 450),
                    child: SlideAnimation(
                      verticalOffset: 50,
                      curve: Curves.easeOutBack,
                      child: FadeInAnimation(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: GestureDetector(
                            onTap: () => _changeIcon(opt['id']),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: isCurrent
                                    ? [
                                        BoxShadow(
                                          color: (opt['glow'] as Color).withOpacity(0.2),
                                          blurRadius: 15,
                                          spreadRadius: 2,
                                        )
                                      ]
                                    : [],
                              ),
                              child: GlassCard(
                                borderRadius: 16,
                                padding: const EdgeInsets.all(18),
                                child: Row(
                                  children: [
                                    // Visual orb representing icon gradient
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: opt['gradient'] as Gradient,
                                        border: Border.all(
                                          color: isCurrent ? Colors.white : Colors.white24,
                                          width: isCurrent ? 2 : 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: (opt['glow'] as Color).withOpacity(0.4),
                                            blurRadius: 10,
                                            spreadRadius: 1,
                                          )
                                        ],
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.blur_on_rounded,
                                          color: Colors.white70,
                                          size: 32,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 18),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            opt['name'] as String,
                                            style: AppTextStyles.body.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: isCurrent ? AppColors.aquaCore : Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            opt['desc'] as String,
                                            style: AppTextStyles.caption.copyWith(
                                              fontSize: 11,
                                              color: Colors.white60,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isCurrent)
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: AppColors.aquaCore,
                                        size: 28,
                                      )
                                    else
                                      const Icon(
                                        Icons.circle_outlined,
                                        color: Colors.white24,
                                        size: 24,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
