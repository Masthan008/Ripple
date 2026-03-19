import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'navbar_item_widget.dart';
import 'navbar_draggable_indicator.dart';
import 'navbar_background.dart';
import 'navbar_providers.dart';

class LiquidNavbarWidget extends ConsumerStatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<int> unreadCounts;
  final String? userPhotoUrl;

  final double indicatorWidth;
  final double navbarHeight;
  final double bottomPadding;
  final double horizontalPadding;

  const LiquidNavbarWidget({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.unreadCounts = const [0, 0, 0, 0, 0, 0],
    this.userPhotoUrl,
    this.indicatorWidth = 60,
    this.navbarHeight = 72,
    this.bottomPadding = 20,
    this.horizontalPadding = 20,
  });

  @override
  ConsumerState<LiquidNavbarWidget> createState() => _LiquidNavbarWidgetState();
}

class _LiquidNavbarWidgetState extends ConsumerState<LiquidNavbarWidget> {
  static const _labels = ['Chats', 'Status', 'Groups', 'Calls', 'AI', 'Profile'];

  static const _activeIcons = [
    Icons.chat_bubble_rounded,
    Icons.circle_notifications_rounded,
    Icons.group_rounded,
    Icons.call_rounded,
    Icons.smart_toy_rounded,
    Icons.person_rounded,
  ];

  static const _inactiveIcons = [
    Icons.chat_bubble_outline_rounded,
    Icons.circle_notifications_outlined,
    Icons.group_outlined,
    Icons.call_outlined,
    Icons.smart_toy_outlined,
    Icons.person_outline_rounded,
  ];

  late List<GlobalKey> _iconKeys;

  @override
  void initState() {
    super.initState();
    _iconKeys = List.generate(_labels.length, (_) => GlobalKey());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final notifier = ref.read(liquidNavbarStateProvider.notifier);
        notifier.initMeasuredPositions(_iconKeys);
        
        // Sync initial external index
        if (notifier.state.currentIndex != widget.currentIndex) {
          notifier.setCurrentIndex(widget.currentIndex);
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant LiquidNavbarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      final notifier = ref.read(liquidNavbarStateProvider.notifier);
      if (notifier.state.currentIndex != widget.currentIndex) {
        notifier.setCurrentIndex(widget.currentIndex);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final navbarState = ref.watch(liquidNavbarStateProvider);
    final notifier = ref.read(liquidNavbarStateProvider.notifier);

    final screenWidth = MediaQuery.of(context).size.width;
    final itemCount = _labels.length;

    final positions = navbarState.positions;
    final dragCenter = navbarState.draggablePosition;
    final currentIndex = navbarState.currentIndex;

    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final effectiveBottomPad = widget.bottomPadding + bottomSafeArea;

    return SizedBox(
      width: screenWidth,
      height: widget.navbarHeight + effectiveBottomPad,
      child: Stack(
        alignment: Alignment.bottomLeft,
        children: [
          // Background
          Positioned(
            left: 0,
            right: 0,
            bottom: effectiveBottomPad,
            child: LiquidNavbarBackground(
              width: screenWidth,
              height: widget.navbarHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(itemCount, (i) {
                  final unread = i < widget.unreadCounts.length ? widget.unreadCounts[i] : 0;
                  final isProfile = i == 5;
                  
                  return LiquidNavbarItemWidget(
                    key: _iconKeys[i],
                    icon: Icon(currentIndex == i ? _activeIcons[i] : _inactiveIcons[i]),
                    label: _labels[i],
                    isSelected: i == currentIndex,
                    unreadCount: unread,
                    isProfileTab: isProfile,
                    userPhotoUrl: widget.userPhotoUrl,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    onTap: () {
                      notifier.setCurrentIndex(i);
                      widget.onTap(i);
                    },
                  );
                }),
              ),
            ),
          ),

          // Draggable indicator
          if (positions.isNotEmpty)
            LiquidNavbarDraggableIndicator(
              position: dragCenter,
              baseSize: widget.indicatorWidth,
              itemCount: itemCount,
              snapPositions: positions,
              bottomOffset: effectiveBottomPad,
              onDragUpdate: notifier.setDraggablePosition,
              onDragEnd: (index) {
                notifier.setCurrentIndex(index);
                widget.onTap(index);
              },
            ),
        ],
      ),
    );
  }
}
