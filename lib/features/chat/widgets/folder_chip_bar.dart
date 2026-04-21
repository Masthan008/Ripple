import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/folder_model.dart';
import '../services/chat_organisation_service.dart';

/// Horizontal scrollable folder chips for chat list filtering
class FolderChipBar extends ConsumerStatefulWidget {
  final String? selectedFolderId;
  final Function(String?) onFolderSelected;

  const FolderChipBar({
    super.key,
    this.selectedFolderId,
    required this.onFolderSelected,
  });

  @override
  ConsumerState<FolderChipBar> createState() => _FolderChipBarState();
}

class _FolderChipBarState extends ConsumerState<FolderChipBar> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FolderModel>>(
      stream: ChatOrganisationService.getFolders(),
      builder: (context, snapshot) {
        final folders = snapshot.data ?? [];

        return Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: folders.length + 1, // +1 for "All" chip
            itemBuilder: (context, index) {
              if (index == 0) {
                // "All" chip
                return _buildChip(
                  label: 'All',
                  icon: Icons.chat_bubble_outline,
                  isSelected: widget.selectedFolderId == null,
                  onTap: () => widget.onFolderSelected(null),
                  color: AppColors.aquaCore,
                );
              }

              final folder = folders[index - 1];
              return _buildChip(
                label: folder.name,
                icon: _getIconData(folder.icon),
                isSelected: widget.selectedFolderId == folder.folderId,
                onTap: () => widget.onFolderSelected(folder.folderId),
                color: _parseColor(folder.color),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withOpacity(0.3)
                    : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? color : Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected ? color : Colors.white70,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconData(String icon) {
    switch (icon) {
      case 'work':
        return Icons.work_outline;
      case 'group':
        return Icons.group_outlined;
      case 'favorite':
        return Icons.favorite_outline;
      case 'business':
        return Icons.business_outlined;
      case 'school':
        return Icons.school_outlined;
      case 'family':
        return Icons.family_restroom_outlined;
      default:
        return Icons.folder_outlined;
    }
  }

  Color _parseColor(String colorHex) {
    try {
      return Color(int.parse('0xFF$colorHex'));
    } catch (_) {
      return AppColors.aquaCore;
    }
  }
}
