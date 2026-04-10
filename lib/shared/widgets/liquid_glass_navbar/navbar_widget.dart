import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/l10n.dart'; // Add this
import 'navbar_item_widget.dart';
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
  // Use a method instead of a static list to allow localization
  List<String> _getLabels(WidgetRef ref) => [
    L10n.s(ref, 'chats'),
    'Status', // L10n.s(ref, 'status')
    L10n.s(ref, 'groups'),
    L10n.s(ref, 'calls'),
    L10n.s(ref, 'ai'),
    L10n.s(ref, 'profile'),
  ];

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
    // Initialize keys based on fixed length
    _iconKeys = List.generate(6, (_) => GlobalKey());

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
    final labels = _getLabels(ref); // Get localized labels

    final screenWidth = MediaQuery.of(context).size.width;
    final itemCount = labels.length;

    final positions = navbarState.positions;
    final dragCenter = navbarState.draggablePosition;
    final currentIndex = navbarState.currentIndex;

    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final effectiveBottomPad = widget.bottomPadding + bottomSafeArea;

    return Container(
      height: widget.navbarHeight + effectiveBottomPad,
      padding: EdgeInsets.fromLTRB(
        widget.horizontalPadding,
        0,
        widget.horizontalPadding,
        effectiveBottomPad,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LiquidNavbarBackground(
              width: screenWidth - (widget.horizontalPadding * 2),
              height: widget.navbarHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(itemCount, (i) {
                  final isSelected = currentIndex == i;
                  return Expanded(
                    child: LiquidNavbarItemWidget(
                      key: _iconKeys[i],
                      label: labels[i],
                      icon: Icon(
                        isSelected ? _activeIcons[i] : _inactiveIcons[i],
                      ),
                      isSelected: isSelected,
                      unreadCount: widget.unreadCounts[i],
                      userPhotoUrl: widget.userPhotoUrl,
                      isProfileTab: i == 5,
                      onTap: () {
                        notifier.setCurrentIndex(i);
                        widget.onTap(i);
                      },
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
