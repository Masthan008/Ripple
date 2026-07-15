import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/dopamine_effects.dart';
import '../../../core/utils/haptic_feedback.dart';

/// AI-suggested quick reply chips
/// Shows above chat input when AI generates suggestions
class SmartReplyChips extends StatelessWidget {
  final List<String> suggestions;
  final Function(String) onSuggestionTap;
  final VoidCallback? onDismiss;

  const SmartReplyChips({
    super.key,
    required this.suggestions,
    required this.onSuggestionTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ProviderScope.containerOf(context).read(rippleThemeProvider);

    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with AI indicator
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 14,
                color: theme.colors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Suggested replies',
                style: TextStyle(
                  color: theme.colors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (onDismiss != null)
                GestureDetector(
                  onTap: onDismiss,
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: theme.colors.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Suggestion chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.map((suggestion) {
              return _SuggestionChip(
                text: suggestion,
                onTap: () {
                  AppHaptics.lightTap();
                  DopamineEffects.showConfettiBurst(
                    context,
                    position: Offset(
                      MediaQuery.of(context).size.width / 2,
                      MediaQuery.of(context).size.height - 100,
                    ),
                    particleCount: 8,
                    colors: [theme.colors.primary, theme.colors.secondary],
                    duration: const Duration(milliseconds: 400),
                  );
                  onSuggestionTap(suggestion);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends ConsumerWidget {
  final String text;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(rippleThemeProvider);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colors.primary.withOpacity(0.15),
              theme.colors.secondary.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colors.primary.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colors.primary.withOpacity(0.1),
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: theme.colors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Smart reply provider for managing suggestions
class SmartReplyProvider extends StateNotifier<List<String>> {
  SmartReplyProvider() : super([]);

  void setSuggestions(List<String> suggestions) {
    state = suggestions.take(3).toList();
  }

  void clearSuggestions() {
    state = [];
  }

  void removeSuggestion(String suggestion) {
    state = state.where((s) => s != suggestion).toList();
  }
}

final smartReplyProvider = StateNotifierProvider<SmartReplyProvider, List<String>>(
  (ref) => SmartReplyProvider(),
);

/// Widget that wraps the chat input with smart reply functionality
class SmartReplyInputWrapper extends ConsumerStatefulWidget {
  final Widget child;
  final String chatId;
  final String otherUserName;
  final String myName;

  const SmartReplyInputWrapper({
    super.key,
    required this.child,
    required this.chatId,
    required this.otherUserName,
    required this.myName,
  });

  @override
  ConsumerState<SmartReplyInputWrapper> createState() => _SmartReplyInputWrapperState();
}

class _SmartReplyInputWrapperState extends ConsumerState<SmartReplyInputWrapper> {
  @override
  Widget build(BuildContext context) {
    final suggestions = ref.watch(smartReplyProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (suggestions.isNotEmpty)
          SmartReplyChips(
            suggestions: suggestions,
            onSuggestionTap: (suggestion) {
              // Insert suggestion into text field
              // This will be handled by the parent
              ref.read(smartReplyProvider.notifier).clearSuggestions();
            },
            onDismiss: () {
              ref.read(smartReplyProvider.notifier).clearSuggestions();
            },
          ),
        widget.child,
      ],
    );
  }
}
