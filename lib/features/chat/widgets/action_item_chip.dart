import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/ai_service.dart';

/// Widget to display action items extracted from messages as chips
class ActionItemChip extends StatelessWidget {
  final String task;
  final String? deadline;
  final VoidCallback? onTap;

  const ActionItemChip({
    super.key,
    required this.task,
    this.deadline,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.aquaCore.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.aquaCore.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 14,
              color: AppColors.aquaCore,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                task,
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.white,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (deadline != null) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  deadline!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.redAccent,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Widget to display a row of action item chips
class ActionItemChipsRow extends StatelessWidget {
  final ActionItems actionItems;
  final Function(String task, String? deadline)? onAddToCalendar;

  const ActionItemChipsRow({
    super.key,
    required this.actionItems,
    this.onAddToCalendar,
  });

  @override
  Widget build(BuildContext context) {
    if (!actionItems.hasActionItems || actionItems.tasks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Wrap(
        children: actionItems.tasks.map((task) {
          // Find matching deadline if any
          String? deadline;
          if (actionItems.deadlines.isNotEmpty) {
            final index = actionItems.tasks.indexOf(task);
            if (index < actionItems.deadlines.length) {
              deadline = actionItems.deadlines[index];
            }
          }

          return ActionItemChip(
            task: task,
            deadline: deadline,
            onTap: onAddToCalendar != null
                ? () => onAddToCalendar!(task, deadline)
                : null,
          );
        }).toList(),
      ),
    );
  }
}

/// Badge showing number of action items in a message
class ActionItemBadge extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;

  const ActionItemBadge({
    super.key,
    required this.count,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.aquaCore,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.task_alt,
              size: 12,
              color: Colors.white,
            ),
            const SizedBox(width: 2),
            Text(
              count.toString(),
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
