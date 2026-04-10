import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/l10n.dart';

/// Pinned message banner displayed below the app bar in chat screens
class PinnedMessageBanner extends ConsumerWidget {
  final String chatId;
  final bool isGroup;
  final VoidCallback? onTap;
  final VoidCallback? onUnpin;

  const PinnedMessageBanner({
    super.key,
    required this.chatId,
    required this.isGroup,
    this.onTap,
    this.onUnpin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collection = isGroup ? 'groups' : 'chats';

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance
              .collection(collection)
              .doc(chatId)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data();
        if (data == null) return const SizedBox.shrink();

        final pinnedMessageId = data['pinnedMessageId'] as String?;
        if (pinnedMessageId == null || pinnedMessageId.isEmpty) {
          return const SizedBox.shrink();
        }

        // Get the pinned message text
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream:
              FirebaseFirestore.instance
                  .collection(collection)
                  .doc(chatId)
                  .collection('messages')
                  .doc(pinnedMessageId)
                  .snapshots(),
          builder: (context, msgSnapshot) {
            if (!msgSnapshot.hasData || msgSnapshot.data == null) {
              return const SizedBox.shrink();
            }

            final msgData = msgSnapshot.data!.data();
            if (msgData == null) return const SizedBox.shrink();

            final text = msgData['text'] as String? ?? '';
            final isDeleted = msgData['isDeleted'] as bool? ?? false;

            if (isDeleted) return const SizedBox.shrink();

            return GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.aquaCore.withOpacity(0.1),
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.aquaCore.withOpacity(0.15),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.push_pin_rounded,
                      color: AppColors.aquaCore,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            L10n.s(ref, 'pinnedMessage'),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.aquaCore,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            text.isNotEmpty
                                ? text
                                : msgData['type'] == 'image'
                                ? L10n.s(ref, 'image')
                                : msgData['type'] == 'video'
                                ? L10n.s(ref, 'video')
                                : msgData['type'] == 'file'
                                ? L10n.s(ref, 'document')
                                : msgData['type'] == 'voice'
                                ? L10n.s(ref, 'voiceMessage')
                                : msgData['type'] == 'gif'
                                ? L10n.s(ref, 'gif')
                                : L10n.s(ref, 'pinnedMessage'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.body.copyWith(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onUnpin != null)
                      GestureDetector(
                        onTap: onUnpin,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.close,
                            color: Colors.white.withOpacity(0.4),
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
