import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../social/models/achievement_model.dart';
import '../../social/services/social_service.dart';
import '../models/sticker_model.dart';

/// Glassmorphism sticker picker sheet
class StickerPickerSheet extends ConsumerStatefulWidget {
  final Function(String stickerEmoji) onStickerSelected;

  const StickerPickerSheet({
    super.key,
    required this.onStickerSelected,
  });

  @override
  ConsumerState<StickerPickerSheet> createState() => _StickerPickerSheetState();
}

class _StickerPickerSheetState extends ConsumerState<StickerPickerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCategory = 'ripple';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: RippleStickers.categories.length,
      vsync: this,
    );
    _tabController.addListener(() {
      setState(() {
        _selectedCategory = RippleStickers.categories[_tabController.index].id;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _isCategoryLocked(StickerCategory category, List<AchievementModel> achievements) {
    if (!category.isLocked) return false;
    if (category.id == 'love') {
      return achievements.isEmpty;
    }
    if (category.id == 'gaming') {
      return achievements.length < 3;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    if (uid == null) {
      return _buildPickerContent([]);
    }

    return StreamBuilder<List<AchievementModel>>(
      stream: SocialService.getAchievements(uid),
      builder: (context, snapshot) {
        final achievements = snapshot.data ?? [];
        return _buildPickerContent(achievements);
      },
    );
  }

  Widget _buildPickerContent(List<AchievementModel> achievements) {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: const Color(0xFF0A1628).withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: AppColors.aquaCyan.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(),
          
          // Category tabs
          _buildCategoryTabs(achievements),
          
          // Sticker grid
          Expanded(
            child: _buildStickerGrid(achievements),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Ripple Stickers',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs(List<AchievementModel> achievements) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: AppColors.aquaCore,
        indicatorWeight: 3,
        labelColor: AppColors.aquaCore,
        unselectedLabelColor: Colors.white54,
        tabs: RippleStickers.categories.map((category) {
          final isLocked = _isCategoryLocked(category, achievements);
          return Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  category.icon,
                  style: const TextStyle(fontSize: 20),
                ),
                if (isLocked) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.lock,
                    size: 12,
                    color: Colors.amber,
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStickerGrid(List<AchievementModel> achievements) {
    final selectedCategoryObj = RippleStickers.categories.firstWhere(
      (c) => c.id == _selectedCategory,
      orElse: () => RippleStickers.categories.first,
    );
    final isLocked = _isCategoryLocked(selectedCategoryObj, achievements);

    if (isLocked) {
      final requiredCount = _selectedCategory == 'love' ? 1 : 3;
      final currentCount = achievements.length;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              color: AppColors.aquaCore.withOpacity(0.5),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'Premium Category: ${selectedCategoryObj.name}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Unlock with achievements ($currentCount/$requiredCount)',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Text(
                _selectedCategory == 'love'
                    ? 'Earn at least 1 achievement to unlock'
                    : 'Earn at least 3 achievements to unlock',
                style: const TextStyle(
                  color: AppColors.aquaCyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final categoryStickers = RippleStickers.defaultStickers
        .where((s) => s.category == _selectedCategory)
        .toList();

    if (categoryStickers.isEmpty) {
      return Center(
        child: Text(
          'No stickers in this category',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 14,
          ),
        ),
      );
    }

    return AnimationLimiter(
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: categoryStickers.length,
        itemBuilder: (context, index) {
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 300),
            child: SlideAnimation(
              verticalOffset: 50,
              child: FadeInAnimation(
                child: _StickerItem(
                  sticker: categoryStickers[index],
                  onTap: () {
                    widget.onStickerSelected(categoryStickers[index].emoji);
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StickerItem extends StatelessWidget {
  final StickerModel sticker;
  final VoidCallback onTap;

  const _StickerItem({
    required this.sticker,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.glassPanel,
              AppColors.glassPanel.withOpacity(0.5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.aquaCyan.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.aquaCore.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Text(
            sticker.emoji,
            style: const TextStyle(fontSize: 32),
          ),
        ),
      ),
    );
  }
}

/// Show sticker picker as bottom sheet
void showStickerPicker({
  required BuildContext context,
  required Function(String stickerEmoji) onStickerSelected,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => StickerPickerSheet(
      onStickerSelected: onStickerSelected,
    ),
  );
}
