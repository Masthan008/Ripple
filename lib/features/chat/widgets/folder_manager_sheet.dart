import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../models/folder_model.dart';
import '../services/chat_organisation_service.dart';

/// Bottom sheet for creating and managing chat folders
class FolderManagerSheet extends StatefulWidget {
  final List<FolderModel> existingFolders;

  const FolderManagerSheet({
    super.key,
    required this.existingFolders,
  });

  @override
  State<FolderManagerSheet> createState() => _FolderManagerSheetState();
}

class _FolderManagerSheetState extends State<FolderManagerSheet> {
  final _nameController = TextEditingController();
  String _selectedIcon = 'folder';
  String _selectedColor = '0EA5E9';
  bool _isCreating = false;

  final List<Map<String, dynamic>> _icons = [
    {'name': 'folder', 'icon': Icons.folder_outlined},
    {'name': 'work', 'icon': Icons.work_outline},
    {'name': 'group', 'icon': Icons.group_outlined},
    {'name': 'favorite', 'icon': Icons.favorite_outline},
    {'name': 'business', 'icon': Icons.business_outlined},
    {'name': 'school', 'icon': Icons.school_outlined},
  ];

  final List<String> _colors = [
    '0EA5E9', // Aqua
    '22D3EE', // Cyan
    'A855F7', // Purple
    'F472B6', // Pink
    'FBBF24', // Amber
    '34D399', // Emerald
    'F87171', // Red
    '818CF8', // Indigo
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A1628),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Chat Folders',
                  style: AppTextStyles.heading3,
                ),
                const Spacer(),
                if (_isCreating)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.aquaCore,
                    ),
                  ),
              ],
            ),
          ),

          // Existing folders list
          if (widget.existingFolders.isNotEmpty)
            Container(
              height: 60,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.existingFolders.length,
                itemBuilder: (context, index) {
                  final folder = widget.existingFolders[index];
                  return _buildFolderPreview(folder);
                },
              ),
            ),

          const Divider(height: 32, indent: 16, endIndent: 16),

          // Create new folder section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create New Folder',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),

                // Folder name input
                TextField(
                  controller: _nameController,
                  style: AppTextStyles.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Folder name (e.g., Work, Family)',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white54,
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.aquaCore),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Icon selection
                Text(
                  'Icon',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  children: _icons.map((iconData) {
                    final isSelected = _selectedIcon == iconData['name'];
                    return GestureDetector(
                      onTap: () {
                        AppHaptics.lightTap();
                        setState(() => _selectedIcon = iconData['name'] as String);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.aquaCore.withOpacity(0.3)
                              : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.aquaCore
                                : Colors.transparent,
                          ),
                        ),
                        child: Icon(
                          iconData['icon'] as IconData,
                          color: isSelected ? AppColors.aquaCore : Colors.white70,
                          size: 24,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Color selection
                Text(
                  'Color',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _colors.map((color) {
                    final isSelected = _selectedColor == color;
                    return GestureDetector(
                      onTap: () {
                        AppHaptics.lightTap();
                        setState(() => _selectedColor = color);
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Color(int.parse('0xFF$color')),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Color(int.parse('0xFF$color')).withOpacity(0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 18)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Create button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createFolder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.aquaCore,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create Folder'),
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFolderPreview(FolderModel folder) {
    final color = Color(int.parse('0xFF${folder.color}'));
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getIconData(folder.icon),
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            folder.name,
            style: AppTextStyles.bodySmall.copyWith(color: Colors.white),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _deleteFolder(folder.folderId),
            child: Icon(
              Icons.close,
              size: 14,
              color: Colors.white54,
            ),
          ),
        ],
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
      default:
        return Icons.folder_outlined;
    }
  }

  Future<void> _createFolder() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a folder name')),
      );
      return;
    }

    setState(() => _isCreating = true);
    AppHaptics.mediumTap();

    try {
      await ChatOrganisationService.createFolder(
        name: name,
        icon: _selectedIcon,
        color: _selectedColor,
        order: widget.existingFolders.length,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Folder "$name" created')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating folder: $e')),
        );
      }
    }
  }

  Future<void> _deleteFolder(String folderId) async {
    AppHaptics.heavyTap();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A1628),
        title: Text('Delete Folder?', style: AppTextStyles.heading4),
        content: Text(
          'Chats in this folder will remain in your main chat list.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ChatOrganisationService.deleteFolder(folderId);
    }
  }
}
