import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_provider.dart';

/// Reusable pill-shaped header widget for chat/group/channel screens.
/// Telegram-inspired floating frosted glass capsule header.
class PillHeader extends ConsumerWidget {
  final Widget? leading;
  final Widget? avatar;
  final String? title;
  final String? subtitle;
  final Color? subtitleColor;
  final List<Widget>? actions;
  final VoidCallback? onTitleTap;
  final Widget? titleWidget;

  const PillHeader({
    super.key,
    this.leading,
    this.avatar,
    this.title,
    this.subtitle,
    this.subtitleColor,
    this.actions,
    this.onTitleTap,
    this.titleWidget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(rippleThemeProvider);
    final topPad = MediaQuery.of(context).padding.top;

    return Padding(
      padding: EdgeInsets.only(
        top: topPad + 6,
        left: 12,
        right: 12,
        bottom: 6,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: _buildContent(theme),
      ),
    );
  }

  Widget _buildContent(dynamic theme) {
    final container = Container(
      height: 56,
      decoration: BoxDecoration(
        color: theme.isDark
            ? theme.colors.surface.withOpacity(0.85)
            : theme.colors.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.colors.glassBorder.withOpacity(0.15),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(theme.isDark ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 4),

          // Leading (back button)
          if (leading != null) leading!,
          if (leading == null) const SizedBox(width: 12),

          // Avatar
          if (avatar != null) ...[
            avatar!,
            const SizedBox(width: 10),
          ],

          // Title + Subtitle
          Expanded(
            child: GestureDetector(
              onTap: onTitleTap,
              behavior: HitTestBehavior.opaque,
              child: titleWidget ?? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Text(
                      title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: subtitleColor ??
                            theme.colors.textMuted.withOpacity(0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Actions
          if (actions != null) ...actions!,
          const SizedBox(width: 8),
        ],
      ),
    );

    if (kIsWeb) return container;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
      child: container,
    );
  }
}
