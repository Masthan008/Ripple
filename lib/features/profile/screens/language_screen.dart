import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/glass_card.dart';
import '../providers/settings_provider.dart';

class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  static const List<Map<String, String>> languages = [
    {'name': 'English', 'native': 'English'},
    {'name': 'Hindi', 'native': 'हिन्दी'},
    {'name': 'Spanish', 'native': 'Español'},
    {'name': 'French', 'native': 'Français'},
    {'name': 'German', 'native': 'Deutsch'},
    {'name': 'Arabic', 'native': 'العربية'},
    {'name': 'Russian', 'native': 'Русский'},
    {'name': 'Japanese', 'native': '日本語'},
    {'name': 'Chinese', 'native': '中文'},
    {'name': 'Portuguese', 'native': 'Português'},
    {'name': 'Italian', 'native': 'Italiano'},
    {'name': 'Korean', 'native': '한국어'},
    {'name': 'Turkish', 'native': 'Türkçe'},
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(L10n.s(ref, 'language'), style: AppTextStyles.headingSmall),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        itemCount: languages.length,
        itemBuilder: (context, index) {
          final lang = languages[index];
          final isSelected = currentLang == lang['name'];

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () {
                ref.read(languageProvider.notifier).setLanguage(lang['name']!);
                HapticFeedback.lightImpact();
              },
              child: GlassCard(
                borderRadius: 16,
                padding: const EdgeInsets.all(16),
                borderColor:
                    isSelected ? AppColors.aquaCore : AppColors.glassBorder,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang['name']!,
                            style: AppTextStyles.body.copyWith(
                              fontWeight:
                                  isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                              color:
                                  isSelected
                                      ? AppColors.aquaCore
                                      : Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(lang['native']!, style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.aquaCore,
                        size: 24,
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
