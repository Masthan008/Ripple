import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/haptic_feedback.dart';

/// Threaded Text Widget — Holographic Word-Threads™
///
/// Replaces standard text rendering in message bubbles with a
/// version where each word is individually tappable (via long-press).
/// When a user long-presses a word, it triggers the word thread
/// overlay to open.
///
/// Active thread words glow with a subtle underline to indicate
/// an existing micro-conversation.
class ThreadedTextWidget extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Set<int> activeWordIndices; // Words with active threads
  final void Function(int wordIndex, String word, Offset position)? onWordLongPress;

  const ThreadedTextWidget({
    super.key,
    required this.text,
    this.style,
    this.activeWordIndices = const {},
    this.onWordLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final words = text.split(RegExp(r'(\s+)'));

    return Wrap(
      children: words.asMap().entries.map((entry) {
        final index = entry.key;
        final word = entry.value;

        // Whitespace-only — just render as-is
        if (word.trim().isEmpty) {
          return Text(word, style: style);
        }

        final hasThread = activeWordIndices.contains(index);

        return GestureDetector(
          onLongPress: () {
            AppHaptics.mediumTap();
            // Get the word position on screen
            final box = context.findRenderObject() as RenderBox?;
            final offset = box?.localToGlobal(Offset.zero) ?? Offset.zero;
            onWordLongPress?.call(index, word, offset);
          },
          child: Container(
            padding: hasThread
                ? const EdgeInsets.symmetric(horizontal: 1)
                : null,
            decoration: hasThread
                ? BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.aquaCore.withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                  )
                : null,
            child: Text(
              word,
              style: (style ?? const TextStyle()).copyWith(
                color: hasThread
                    ? AppColors.aquaCore.withOpacity(0.9)
                    : null,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
