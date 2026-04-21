import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../../core/constants/app_colors.dart';
import '../models/sticker_model.dart';

/// Glassmorphism sticker picker sheet
class StickerPickerSheet extends StatefulWidget {
  final Function(String stickerEmoji) onStickerSelected;

  const StickerPickerSheet({
    super.key,
    required this.onStickerSelected,
  });

  @override
  State<StickerPickerSheet> createState() => _StickerPickerSheetState();
}

class _StickerPickerSheetState extends State<StickerPickerSheet>
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

  @override
  Widget build(BuildContext context) {
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
          _buildCategoryTabs(),
          
          // Sticker grid
          Expanded(
            child: _buildStickerGrid(),
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

  Widget _buildCategoryTabs() {
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
          return Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  category.icon,
                  style: const TextStyle(fontSize: 20),
                ),
                if (category.isLocked) ...[
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

  Widget _buildStickerGrid() {
    final categoryStickers = RippleStickers.defaultStickers
        .where((s) => s.category == _selectedCategory)
        .toList();

    if (categoryStickers.isEmpty) {
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
              'Premium Category',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Unlock with achievements',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ],
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
