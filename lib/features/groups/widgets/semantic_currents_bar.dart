import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/semantic_currents_service.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../chat/models/message_model.dart';
import '../providers/semantic_currents_provider.dart';

/// Semantic Currents™ — Topic Filter Bar
///
/// A horizontally scrollable bar of topic chips that appears at the top
/// of group chats. Each chip represents a detected conversation "current"
/// (topic thread). Tapping a chip filters the message list to only show
/// messages belonging to that topic.
///
/// Features:
/// - Animated chip selection with liquid glass styling
/// - Topic icons and labels from SemanticCurrentsService
/// - Message count badges per topic
/// - "All" chip to reset filtering
class SemanticCurrentsBar extends ConsumerWidget {
  final List<MessageModel> messages;

  const SemanticCurrentsBar({super.key, required this.messages});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTopics = ref.watch(activeTopicsProvider(messages));
    final selectedTopic = ref.watch(selectedTopicProvider);
    final classifications = ref.watch(semanticClassificationProvider(messages));

    // Don't show if only 'general' topic exists
    if (activeTopics.length <= 1 &&
        activeTopics.firstOrNull == 'general') {
      return const SizedBox.shrink();
    }

    // Count messages per topic
    final topicCounts = <String, int>{};
    for (final topic in classifications.values) {
      topicCounts[topic] = (topicCounts[topic] ?? 0) + 1;
    }

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.abyssBackground.withOpacity(0.6),
        border: Border(
          bottom: BorderSide(
            color: AppColors.glassBorder,
            width: 0.5,
          ),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: activeTopics.length + 1, // +1 for "All" chip
        itemBuilder: (context, index) {
          if (index == 0) {
            // "All" chip
            return _TopicChip(
              icon: '🌊',
              label: 'All Currents',
              count: messages.length,
              isSelected: selectedTopic == null,
              onTap: () {
                AppHaptics.lightTap();
                ref.read(selectedTopicProvider.notifier).state = null;
              },
            );
          }

          final topic = activeTopics[index - 1];
          final icon = SemanticCurrentsService.currentIcons[topic] ?? '💬';
          final label = SemanticCurrentsService.currentLabels[topic] ?? topic;
          final count = topicCounts[topic] ?? 0;

          return _TopicChip(
            icon: icon,
            label: label,
            count: count,
            isSelected: selectedTopic == topic,
            onTap: () {
              AppHaptics.lightTap();
              if (selectedTopic == topic) {
                // Deselect
                ref.read(selectedTopicProvider.notifier).state = null;
              } else {
                ref.read(selectedTopicProvider.notifier).state = topic;
              }
            },
          );
        },
      ),
    );
  }
}

class _TopicChip extends StatelessWidget {
  final String icon;
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _TopicChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.aquaCore.withOpacity(0.2)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppColors.aquaCore.withOpacity(0.5)
                  : Colors.white.withOpacity(0.1),
              width: isSelected ? 1.5 : 0.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.aquaCore.withOpacity(0.15),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? AppColors.aquaCore
                      : Colors.white.withOpacity(0.7),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.aquaCore.withOpacity(0.3)
                      : Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? AppColors.aquaCore
                        : Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
