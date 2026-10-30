import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
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
    final theme = ref.watch(rippleThemeProvider);
    final isDark = theme.isDark;
    final textColor = isDark ? Colors.white : const Color(0xFF09090B);
    final textMuted = isDark ? Colors.white60 : const Color(0xFF71717A);
    final cardBorder = isDark ? Colors.white12 : const Color(0xFFE4E4E7);
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;

    final allLanguages = L10n.worldLanguages;
    final filtered = allLanguages.where((l) {
      if (_filter.isEmpty) return true;
      final q = _filter.toLowerCase();
      return l.name.toLowerCase().contains(q) ||
          l.nativeName.toLowerCase().contains(q) ||
          l.code.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: theme.colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(L10n.s(ref, 'language'), style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
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
                style: TextStyle(color: textColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search Indian & regional languages...',
                  hintStyle: TextStyle(color: textMuted),
                  prefixIcon: Icon(Icons.search_rounded, color: theme.colors.primary),
                  filled: true,
                  fillColor: cardBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: theme.colors.primary),
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
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? theme.colors.primary : cardBorder,
                            width: isSelected ? 1.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [BoxShadow(color: theme.colors.primary.withValues(alpha: 0.1), blurRadius: 10)]
                              : [],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colors.primary.withValues(alpha: isDark ? 0.2 : 0.1)
                                    : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF4F4F5)),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? theme.colors.primary : cardBorder,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  lang.code.toUpperCase(),
                                  style: TextStyle(
                                    color: isSelected ? theme.colors.primary : textMuted,
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
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                      color: isSelected ? theme.colors.primary : textColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    lang.nativeName,
                                    style: TextStyle(color: textMuted, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle_rounded,
                                color: theme.colors.primary,
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
