import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/utils/dopamine_effects.dart';
import '../../core/utils/haptic_feedback.dart';

/// Swipeable message bubble with actions
/// Supports swipe-to-reply, swipe-to-forward, and reveal actions
class SwipeableMessage extends StatefulWidget {
  final Widget child;
  final VoidCallback? onReply;
  final VoidCallback? onForward;
  final VoidCallback? onPin;
  final VoidCallback? onDelete;
  final VoidCallback? onMore;
  final bool isMe;
  final bool enableReply;
  final bool enableForward;
  final bool enablePin;
  final bool enableDelete;
  
  const SwipeableMessage({
    super.key,
    required this.child,
    this.onReply,
    this.onForward,
    this.onPin,
    this.onDelete,
    this.onMore,
    this.isMe = false,
    this.enableReply = true,
    this.enableForward = true,
    this.enablePin = true,
    this.enableDelete = true,
  });

  @override
  State<SwipeableMessage> createState() => _SwipeableMessageState();
}

class _SwipeableMessageState extends State<SwipeableMessage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnim;
  double _dragExtent = 0;
  static const double _threshold = 80;
  static const double _maxDrag = 120;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _slideAnim = Tween<double>(begin: 0, end: 0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    // Only allow swipe in one direction based on message position
    final isLeftSwipe = details.delta.dx < 0;
    final isRightSwipe = details.delta.dx > 0;
    
    // Right swipe for reply (both sides)
    // Left swipe for forward (both sides)
    setState(() {
      _dragExtent += details.delta.dx;
      _dragExtent = _dragExtent.clamp(-_maxDrag, _maxDrag);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx;
    
    // Check if we should trigger an action
    if (_dragExtent.abs() > _threshold || velocity.abs() > 300) {
      if (_dragExtent > 0 && widget.enableReply) {
        // Swiped right - Reply
        _triggerAction(context, 'reply', widget.onReply);
      } else if (_dragExtent < 0 && widget.enableForward) {
        // Swiped left - Forward
        _triggerAction(context, 'forward', widget.onForward);
      }
    }
    
    // Reset position
    setState(() {
      _dragExtent = 0;
    });
  }

  void _triggerAction(BuildContext context, String type, VoidCallback? callback) {
    AppHaptics.lightTap();
    
    // Show visual feedback
    DopamineEffects.showConfettiBurst(
      context,
      position: Offset(
        MediaQuery.of(context).size.width / 2,
        MediaQuery.of(context).size.height / 2,
      ),
      particleCount: 10,
      colors: [Colors.cyan, Colors.blue, Colors.green],
      duration: const Duration(milliseconds: 400),
    );
    
    callback?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ProviderScope.containerOf(context).read(rippleThemeProvider);
    final opacity = (_dragExtent.abs() / _threshold).clamp(0.0, 1.0);
    final showReplyAction = _dragExtent > 20 && widget.enableReply;
    final showForwardAction = _dragExtent < -20 && widget.enableForward;

    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Stack(
        children: [
          // Background actions
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left side - Reply action
                  if (showReplyAction || _dragExtent > 0)
                    AnimatedOpacity(
                      opacity: opacity,
                      duration: const Duration(milliseconds: 100),
                      child: Container(
                        margin: const EdgeInsets.only(left: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: theme.colors.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.reply,
                              color: theme.colors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Reply',
                              style: TextStyle(
                                color: theme.colors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    const SizedBox(),

                  // Right side - Forward action
                  if (showForwardAction || _dragExtent < 0)
                    AnimatedOpacity(
                      opacity: opacity,
                      duration: const Duration(milliseconds: 100),
                      child: Container(
                        margin: const EdgeInsets.only(right: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: theme.colors.secondary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Forward',
                              style: TextStyle(
                                color: theme.colors.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.forward,
                              color: theme.colors.secondary,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    const SizedBox(),
                ],
              ),
            ),
          ),

          // Foreground message
          Transform.translate(
            offset: Offset(_dragExtent, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

/// Message action bar that slides up from bottom
class MessageActionBar extends StatelessWidget {
  final VoidCallback? onReply;
  final VoidCallback? onForward;
  final VoidCallback? onPin;
  final VoidCallback? onDelete;
  final VoidCallback? onCopy;
  final VoidCallback? onReact;
  final bool isMe;

  const MessageActionBar({
    super.key,
    this.onReply,
    this.onForward,
    this.onPin,
    this.onDelete,
    this.onCopy,
    this.onReact,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ProviderScope.containerOf(context).read(rippleThemeProvider);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colors.surface.withOpacity(0.9),
            theme.colors.background,
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: theme.colors.glassBorder),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            
            // Reaction row
            if (onReact != null) ...[
              _buildReactionRow(context, theme),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
            ],
            
            // Action buttons
            Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                if (onReply != null)
                  _buildActionButton(
                    context: context,
                    icon: Icons.reply,
                    label: 'Reply',
                    color: theme.colors.primary,
                    onTap: onReply,
                  ),
                if (onForward != null)
                  _buildActionButton(
                    context: context,
                    icon: Icons.forward,
                    label: 'Forward',
                    color: theme.colors.secondary,
                    onTap: onForward,
                  ),
                if (onCopy != null)
                  _buildActionButton(
                    context: context,
                    icon: Icons.copy,
                    label: 'Copy',
                    color: theme.colors.textMuted,
                    onTap: onCopy,
                  ),
                if (onPin != null)
                  _buildActionButton(
                    context: context,
                    icon: Icons.push_pin,
                    label: 'Pin',
                    color: Colors.orange,
                    onTap: onPin,
                  ),
                if (onDelete != null && isMe)
                  _buildActionButton(
                    context: context,
                    icon: Icons.delete,
                    label: 'Delete',
                    color: Colors.red,
                    onTap: onDelete,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionRow(BuildContext context, dynamic theme) {
    final reactions = ['❤️', '😂', '😮', '😢', '👍', '🔥'];
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: reactions.map((emoji) {
        return GestureDetector(
          onTap: () {
            AppHaptics.lightTap();
            // Trigger reaction
            DopamineEffects.showConfettiBurst(
              context,
              position: Offset(
                MediaQuery.of(context).size.width / 2,
                MediaQuery.of(context).size.height - 100,
              ),
              particleCount: 8,
              colors: [Colors.red, Colors.orange, Colors.yellow],
            );
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colors.glassSurface,
              shape: BoxShape.circle,
              border: Border.all(color: theme.colors.glassBorder),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 24)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: () {
        AppHaptics.mediumTap();
        onTap?.call();
        Navigator.pop(context);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick action buttons that appear on long press
class QuickMessageActions extends StatelessWidget {
  final VoidCallback? onReply;
  final VoidCallback? onReact;
  final VoidCallback? onMore;

  const QuickMessageActions({
    super.key,
    this.onReply,
    this.onReact,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
