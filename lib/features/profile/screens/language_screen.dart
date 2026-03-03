import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/glass_card.dart';
import '../providers/settings_provider.dart';

class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  static const _languages = [
    {'name': 'English', 'native': 'English', 'icon': '🇺🇸'},
    {'name': 'Hindi', 'native': 'हिंदी', 'icon': '🇮🇳'},
    {'name': 'Spanish', 'native': 'Español', 'icon': '🇪🇸'},
    {'name': 'French', 'native': 'Français', 'icon': '🇫🇷'},
    {'name': 'Arabic', 'native': 'العربية', 'icon': '🇸🇦'},
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      appBar: AppBar(
        title: Text('Language', style: AppTextStyles.heading),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.aquaCore),
      ),
      body: AnimationLimiter(
        child: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: _languages.length,
          itemBuilder: (ctx, i) {
            final lang = _languages[i];
            final isSelected = currentLang == lang['name'];

            return AnimationConfiguration.staggeredList(
              position: i,
              duration: const Duration(milliseconds: 450),
              child: SlideAnimation(
                verticalOffset: 50,
                curve: Curves.easeOutBack,
                child: FadeInAnimation(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: () {
                        ref.read(languageProvider.notifier).setLanguage(lang['name']!);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Restart the app to apply language changes'),
                            backgroundColor: AppColors.aquaCore,
                          ),
                        );
                      },
                      child: GlassCard(
                        borderRadius: 14,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        child: Row(
                          children: [
                            Text(lang['icon']!, style: const TextStyle(fontSize: 24)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(lang['name']!,
                                      style: AppTextStyles.body.copyWith(fontSize: 14)),
                                  Text(lang['native']!,
                                      style: AppTextStyles.caption.copyWith(fontSize: 12)),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(Icons.check_circle_rounded,
                                  color: AppColors.aquaCore, size: 22),
                          ],
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
