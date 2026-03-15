import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../services/chat_theme_service.dart';

/// Bottom sheet for selecting a per-chat background theme
class ChatThemePicker extends StatefulWidget {
  final String chatId;
  final VoidCallback? onThemeChanged;

  const ChatThemePicker({
    super.key,
    required this.chatId,
    this.onThemeChanged,
  });

  @override
  State<ChatThemePicker> createState() => _ChatThemePickerState();
}

class _ChatThemePickerState extends State<ChatThemePicker> {
  int _selectedIndex = 0;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A1628),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text('Chat Theme', style: AppTextStyles.heading.copyWith(fontSize: 18)),
                const Spacer(),
                if (_isSaving)
                  const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.aquaCore),
                  )
                else
                  GestureDetector(
                    onTap: _applyTheme,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: AppColors.buttonGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('Apply', style: AppTextStyles.label),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Theme grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              itemCount: ChatThemeService.presets.length,
              itemBuilder: (_, i) {
                final preset = ChatThemeService.presets[i];
                final colors = (preset['colors'] as List<String>)
                    .map((c) => Color(int.parse('FF$c', radix: 16)))
                    .toList();
                final accent = Color(int.parse('FF${preset['accent']}', radix: 16));
                final isSelected = _selectedIndex == i;

                return GestureDetector(
                  onTap: () {
                    AppHaptics.selectionTick();
                    setState(() => _selectedIndex = i);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: colors,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? accent : Colors.white12,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Preview dot with accent
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accent.withValues(alpha: 0.3),
                            border: Border.all(color: accent, width: 1.5),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 14, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          preset['name'] as String,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 10,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
        ],
      ),
    );
  }

  Future<void> _applyTheme() async {
    setState(() => _isSaving = true);
    try {
      final preset = ChatThemeService.presets[_selectedIndex];
      if (_selectedIndex == 0) {
        await ChatThemeService.clearTheme(widget.chatId);
      } else {
        await ChatThemeService.setTheme(
          chatId: widget.chatId,
          gradientColors: List<String>.from(preset['colors'] as List),
          accentColor: preset['accent'] as String,
        );
      }
      AppHaptics.success();
      widget.onThemeChanged?.call();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
