import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/message_model.dart';
import '../services/message_actions_service.dart';

/// Glass morphism context menu shown on long-press of a message
class MessageContextMenu extends StatefulWidget {
  final MessageModel message;
  final bool isMyMessage;
  final String chatId;
  final bool isGroup;
  final VoidCallback onReply;
  final VoidCallback? onEdit;
  final VoidCallback onDeleteForEveryone;
  final VoidCallback onDeleteForMe;
  final VoidCallback onForward;
  final VoidCallback onPin;
  final VoidCallback onStar;
  final VoidCallback onCopy;
  final String currentUid;

  const MessageContextMenu({
    super.key,
    required this.message,
    required this.isMyMessage,
    required this.chatId,
    required this.isGroup,
    required this.onReply,
    this.onEdit,
    required this.onDeleteForEveryone,
    required this.onDeleteForMe,
    required this.onForward,
    required this.onPin,
    required this.onStar,
    required this.onCopy,
    required this.currentUid,
  });

  @override
  State<MessageContextMenu> createState() => _MessageContextMenuState();
}

class _MessageContextMenuState extends State<MessageContextMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  static const quickReactions = [
    '❤️', '😂', '😮', '😢', '😡', '👍', '👎', '🔥',
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _close([VoidCallback? afterClose]) {
    _animController.reverse().then((_) {
      if (mounted) Navigator.of(context).pop();
      afterClose?.call();
    });
  }

  void _handleReaction(String emoji) {
    MessageActionsService.toggleReaction(
      chatId: widget.chatId,
      messageId: widget.message.id,
      emoji: emoji,
      isGroup: widget.isGroup,
    );
    _close();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _close,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: Colors.black.withOpacity(0.4),
              child: Center(
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    constraints: const BoxConstraints(maxWidth: 320),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A1628).withOpacity(0.92),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.aquaCyan.withOpacity(0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.aquaCore.withOpacity(0.15),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Quick reaction emoji row
                        _buildReactionRow(),
                        _divider(),
                        // Menu options
                        ..._buildMenuOptions(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReactionRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: quickReactions.map((emoji) {
          return GestureDetector(
            onTap: () => _handleReaction(emoji),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 18)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _divider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.white.withOpacity(0.08),
    );
  }

  List<Widget> _buildMenuOptions() {
    final options = <Widget>[];

    // Reply — always available
    options.add(_menuItem(
      icon: Icons.reply_rounded,
      label: 'Reply',
      onTap: () {
        _close();
        widget.onReply();
      },
    ));

    // Edit — own messages only, < 15 minutes
    // Uses afterClose callback so dialog opens AFTER menu is fully dismissed
    if (widget.isMyMessage && widget.onEdit != null) {
      final elapsed =
          DateTime.now().difference(widget.message.createdAt);
      if (elapsed.inMinutes <= 15) {
        options.add(_menuItem(
          icon: Icons.edit_outlined,
          label: 'Edit',
          onTap: () {
            _close(() => widget.onEdit!());
          },
        ));
      }
    }

    options.add(_divider());

    // Pin
    options.add(_menuItem(
      icon: Icons.push_pin_outlined,
      label: widget.message.isPinned ? 'Unpin' : 'Pin',
      onTap: () {
        _close();
        widget.onPin();
      },
    ));

    // Star
    final isStarred = widget.message.starredBy.contains(widget.currentUid);
    options.add(_menuItem(
      icon: isStarred ? Icons.star_rounded : Icons.star_border_rounded,
      label: isStarred ? 'Unsave' : 'Save',
      iconColor: isStarred ? Colors.amber : null,
      onTap: () {
        _close();
        widget.onStar();
      },
    ));

    // Copy
    if (widget.message.text != null && widget.message.text!.isNotEmpty) {
      options.add(_menuItem(
        icon: Icons.copy_rounded,
        label: 'Copy',
        onTap: () {
          Clipboard.setData(
              ClipboardData(text: widget.message.text ?? ''));
          _close();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Copied to clipboard')),
          );
        },
      ));
    }

    // Forward — uses afterClose callback so bottom sheet opens AFTER menu is dismissed
    options.add(_menuItem(
      icon: Icons.forward_to_inbox_rounded,
      label: 'Forward',
      onTap: () {
        _close(() => widget.onForward());
      },
    ));

    options.add(_divider());

    // Delete for everyone — own messages only
    if (widget.isMyMessage) {
      options.add(_menuItem(
        icon: Icons.delete_outline_rounded,
        label: 'Delete for Everyone',
        iconColor: AppColors.errorRed,
        labelColor: AppColors.errorRed,
        onTap: () {
          _close();
          widget.onDeleteForEveryone();
        },
      ));
    }

    // Delete for me — always available
    options.add(_menuItem(
      icon: Icons.delete_forever_outlined,
      label: 'Delete for Me',
      iconColor: AppColors.errorRed.withOpacity(0.7),
      labelColor: AppColors.errorRed.withOpacity(0.7),
      onTap: () {
        _close();
        widget.onDeleteForMe();
      },
    ));

    return options;
  }

  Widget _menuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
    Color? labelColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            Icon(icon,
                color: iconColor ?? Colors.white.withOpacity(0.85),
                size: 20),
            const SizedBox(width: 14),
            Text(
              label,
              style: AppTextStyles.body.copyWith(
                color: labelColor ?? Colors.white.withOpacity(0.9),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Show the context menu as a full-screen dialog
void showMessageContextMenu({
  required BuildContext context,
  required MessageModel message,
  required bool isMyMessage,
  required String chatId,
  required bool isGroup,
  required String currentUid,
  required VoidCallback onReply,
  VoidCallback? onEdit,
  required VoidCallback onDeleteForEveryone,
  required VoidCallback onDeleteForMe,
  required VoidCallback onForward,
  required VoidCallback onPin,
  required VoidCallback onStar,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close menu',
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (ctx, _, __) {
      return MessageContextMenu(
        message: message,
        isMyMessage: isMyMessage,
        chatId: chatId,
        isGroup: isGroup,
        currentUid: currentUid,
        onReply: onReply,
        onEdit: onEdit,
        onDeleteForEveryone: onDeleteForEveryone,
        onDeleteForMe: onDeleteForMe,
        onForward: onForward,
        onPin: onPin,
        onStar: onStar,
        onCopy: () {
          Clipboard.setData(
              ClipboardData(text: message.text ?? ''));
        },
      );
    },
  );
}
