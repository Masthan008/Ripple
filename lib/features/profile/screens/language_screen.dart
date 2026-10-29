import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' hide GlassTheme, GlassCard;

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/l10n.dart';
import '../providers/settings_provider.dart';

class LanguageScreen extends ConsumerStatefulWidget {
  const LanguageScreen({super.key});

  @override
  ConsumerState<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends ConsumerState<LanguageScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(languageProvider);
    final allLanguages = L10n.worldLanguages;
    final filtered = allLanguages.where((l) {
      if (_filter.isEmpty) return true;
      final q = _filter.toLowerCase();
      return l.name.toLowerCase().contains(q) ||
          l.nativeName.toLowerCase().contains(q) ||
          l.code.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(L10n.s(ref, 'language'), style: AppTextStyles.headingSmall),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search 25+ world languages...',
                  hintStyle: const TextStyle(color: Colors.white30),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.aquaCore),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.aquaCore),
                  ),
                ),
                onChanged: (val) => setState(() => _filter = val.trim()),
              ),
            ),
            const SizedBox(height: 8),

            // Language List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final lang = filtered[index];
                  final isSelected = currentLang == lang.name;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        await ref.read(languageProvider.notifier).setLanguage(lang.name);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Language changed to ${lang.name} (${lang.nativeName})'),
                              backgroundColor: AppColors.onlineGreen,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      child: GlassContainer(
                        useOwnLayer: true,
                        shape: const LiquidRoundedSuperellipse(borderRadius: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.aquaCore.withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? AppColors.aquaCore : Colors.white12,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  lang.code.toUpperCase(),
                                  style: TextStyle(
                                    color: isSelected ? AppColors.aquaCore : Colors.white70,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lang.name,
                                    style: AppTextStyles.body.copyWith(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                      color: isSelected ? AppColors.aquaCore : Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    lang.nativeName,
                                    style: AppTextStyles.caption.copyWith(color: Colors.white60),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.aquaCore,
                                size: 22,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
