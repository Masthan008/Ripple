import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/glass_card.dart';

/// Saved Messages Screen — accessible from Profile
/// Shows messages starred/saved by the current user
class SavedMessagesScreen extends StatelessWidget {
  const SavedMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              right: 16,
              bottom: 12,
            ),
            decoration: const BoxDecoration(
              color: Color(0xE6060D1A),
              border: Border(
                bottom: BorderSide(
                    color: Color(0x0FFFFFFF), width: 1),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                      Icons.arrow_back_ios_rounded, size: 20),
                  onPressed: () =>
                      Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                Icon(Icons.bookmark_rounded,
                    color: AppColors.aquaCore, size: 24),
                const SizedBox(width: 10),
                Text('Saved Messages',
                    style: AppTextStyles.headingSmall
                        .copyWith(fontSize: 18)),
              ],
            ),
          ),

          // Saved messages list
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('savedMessages')
                  .orderBy('savedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(
                          AppColors.aquaCore),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bookmark_border_rounded,
                            color: AppColors.aquaCore
                                .withOpacity(0.2),
                            size: 64),
                        const SizedBox(height: 12),
                        Text('No saved messages',
                            style: AppTextStyles.bodySmall),
                        const SizedBox(height: 4),
                        Text(
                            'Star messages to save them here',
                            style: AppTextStyles.caption),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final data = docs[i].data();
                    final messageId = docs[i].id;
                    final text =
                        data['text'] as String? ?? '';
                    final type =
                        data['type'] as String? ?? 'text';
                    final savedAt =
                        data['savedAt'] as Timestamp?;
                    final chatId =
                        data['chatId'] as String? ?? '';
                    final isGroup =
                        data['isGroup'] as bool? ?? false;
                    final senderId =
                        data['senderId'] as String? ?? '';

                    return Padding(
                      padding:
                          const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onLongPress: () {
                          _showUnsaveDialog(
                              context, uid, messageId);
                        },
                        child: GlassCard(
                          borderRadius: 14,
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              // Source info
                              Row(
                                children: [
                                  Icon(
                                    isGroup
                                        ? Icons.group_rounded
                                        : Icons.chat_rounded,
                                    color: AppColors.aquaCore
                                        .withOpacity(0.6),
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: FutureBuilder<
                                        DocumentSnapshot>(
                                      future: _getChatName(
                                          chatId, isGroup),
                                      builder: (context,
                                          snap) {
                                        final name = snap
                                                .data
                                                ?.get(
                                                    'name') as String? ??
                                            chatId;
                                        return Text(
                                          isGroup
                                              ? name
                                              : 'Direct Chat',
                                          style: AppTextStyles
                                              .caption
                                              .copyWith(
                                            fontSize: 10,
                                            color: AppColors
                                                .aquaCore
                                                .withOpacity(
                                                    0.7),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  if (savedAt != null)
                                    Text(
                                      _formatDate(
                                          savedAt.toDate()),
                                      style: AppTextStyles
                                          .caption
                                          .copyWith(
                                              fontSize: 10),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Message content
                              if (type == 'text' ||
                                  type == 'emoji')
                                Text(
                                  text,
                                  style: AppTextStyles.body
                                      .copyWith(
                                          fontSize: 14),
                                  maxLines: 4,
                                  overflow:
                                      TextOverflow.ellipsis,
                                )
                              else
                                Row(
                                  children: [
                                    Icon(
                                      type == 'image'
                                          ? Icons
                                              .image_rounded
                                          : type == 'video'
                                              ? Icons
                                                  .videocam_rounded
                                              : Icons
                                                  .insert_drive_file_rounded,
                                      color: AppColors
                                          .textMuted,
                                      size: 18,
                                    ),
                                    const SizedBox(
                                        width: 6),
                                    Text(
                                      text.isNotEmpty
                                          ? text
                                          : '[$type]',
                                      style: AppTextStyles
                                          .caption,
                                    ),
                                  ],
                                ),

                              // Star icon
                              Align(
                                alignment:
                                    Alignment.centerRight,
                                child: Icon(
                                    Icons.star_rounded,
                                    color: Colors.amber
                                        .withOpacity(0.5),
                                    size: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<DocumentSnapshot> _getChatName(
      String chatId, bool isGroup) {
    if (isGroup) {
      return FirebaseFirestore.instance
          .collection('groups')
          .doc(chatId)
          .get();
    }
    // For 1-to-1 chats, return the chat doc itself
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .get();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      const days = [
        'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
      ];
      return days[date.weekday - 1];
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showUnsaveDialog(
      BuildContext context, String uid, String messageId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0A1628),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text('Remove from Saved?',
            style: AppTextStyles.body
                .copyWith(fontWeight: FontWeight.w600)),
        content: Text(
          'This message will be removed from your saved messages.',
          style: AppTextStyles.caption,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style:
                    TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('savedMessages')
                  .doc(messageId)
                  .delete();
              if (context.mounted) Navigator.pop(context);
            },
            child: Text('Remove',
                style: TextStyle(
                    color: AppColors.errorRed)),
          ),
        ],
      ),
    );
  }
}
