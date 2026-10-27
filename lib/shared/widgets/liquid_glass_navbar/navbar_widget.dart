import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/theme/theme_provider.dart';
import 'navbar_item_widget.dart';
import 'navbar_background.dart';
import 'navbar_providers.dart';


/// Full Liquid Glass Navigation Bar with fluid draggable indicator,
/// real-time blur backdrop, glow effects, and responsive layout.
class LiquidNavbarWidget extends ConsumerStatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<int> unreadCounts;
  final String? userPhotoUrl;

  final double indicatorWidth;
  final double navbarHeight;
  final double bottomPadding;
  final double horizontalPadding;
  final List<String>? customLabels;
  final List<IconData>? customActiveIcons;
  final List<IconData>? customInactiveIcons;

  const LiquidNavbarWidget({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.unreadCounts = const [0, 0, 0, 0, 0],
    this.userPhotoUrl,
    this.indicatorWidth = 64,
    this.navbarHeight = 72,
    this.bottomPadding = 16,
    this.horizontalPadding = 16,
    this.customLabels,
    this.customActiveIcons,
    this.customInactiveIcons,
  });

  @override
  ConsumerState<LiquidNavbarWidget> createState() => _LiquidNavbarWidgetState();
}

class _LiquidNavbarWidgetState extends ConsumerState<LiquidNavbarWidget> {
  List<String> _getLabels(WidgetRef ref) {
    if (widget.customLabels != null) return widget.customLabels!;
    return [
      L10n.s(ref, 'chats'),
      'Status',
      L10n.s(ref, 'groups'),
      L10n.s(ref, 'calls'),
      L10n.s(ref, 'profile'),
    ];
  }

  static const _defaultActiveIcons = [
    Icons.chat_bubble_rounded,
    Icons.circle_notifications_rounded,
    Icons.group_rounded,
    Icons.call_rounded,
    Icons.person_rounded,
  ];

  static const _defaultInactiveIcons = [
    Icons.chat_bubble_outline_rounded,
    Icons.circle_notifications_outlined,
    Icons.group_outlined,
    Icons.call_outlined,
    Icons.person_outline_rounded,
  ];

  late List<GlobalKey> _iconKeys;

  @override
  void initState() {
    super.initState();
    final count = widget.customLabels?.length ?? 5;
    _iconKeys = List.generate(count, (_) => GlobalKey());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final notifier = ref.read(liquidNavbarStateProvider.notifier);
        notifier.initMeasuredPositions(_iconKeys, context);

        final currentState = ref.read(liquidNavbarStateProvider);
        if (currentState.currentIndex != widget.currentIndex) {
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
      final currentState = ref.read(liquidNavbarStateProvider);
      if (currentState.currentIndex != widget.currentIndex) {
        notifier.setCurrentIndex(widget.currentIndex);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final navbarState = ref.watch(liquidNavbarStateProvider);
    final notifier = ref.read(liquidNavbarStateProvider.notifier);
    final labels = _getLabels(ref);
    final theme = ref.watch(rippleThemeProvider);

    final activeIcons = widget.customActiveIcons ?? _defaultActiveIcons;
    final inactiveIcons = widget.customInactiveIcons ?? _defaultInactiveIcons;

    final screenWidth = MediaQuery.of(context).size.width;
    final itemCount = labels.length;

    // Safety checks


    final currentIndex = navbarState.currentIndex;

    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final effectiveBottomPad = widget.bottomPadding + bottomSafeArea;
    final parentWidth = (screenWidth - (widget.horizontalPadding * 2)).clamp(280.0, 600.0);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: parentWidth + (widget.horizontalPadding * 2),
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
            // 1. Background Liquid Glass Layer
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LiquidNavbarBackground(
                width: parentWidth,
                height: widget.navbarHeight,
                theme: theme,
                child: const SizedBox.shrink(),
              ),
            ),

            // 2. Tab Items Row (with locked liquid droplets)

            // 3. Tab Items Row
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SizedBox(
                width: parentWidth,
                height: widget.navbarHeight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(itemCount, (i) {
                    final isSelected = currentIndex == i;
                    final unread = i < widget.unreadCounts.length
                        ? widget.unreadCounts[i]
                        : 0;

                    return Expanded(
                      child: LiquidNavbarItemWidget(
                        key: _iconKeys[i],
                        label: labels[i],
                        icon: Icon(
                          isSelected ? activeIcons[i] : inactiveIcons[i],
                        ),
                        isSelected: isSelected,
                        selectedColor: theme.colors.primary,
                        unselectedColor: theme.colors.textMuted,
                        unreadCount: unread,
                        userPhotoUrl: widget.userPhotoUrl,
                        isProfileTab: i == itemCount - 1,
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
      ),
    );
  }
}
