import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/l10n.dart';
import '../services/chat_organisation_service.dart';

/// Screen showing all saved/bookmarked messages with theme support and resolved sender identities.
class SavedMessagesScreen extends ConsumerWidget {
  const SavedMessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(rippleThemeProvider);
    final isDark = theme.isDark;
    final textColor = isDark ? Colors.white : const Color(0xFF09090B);
    final textMuted = isDark ? Colors.white60 : const Color(0xFF71717A);
    final cardBorder = isDark ? Colors.white12 : const Color(0xFFE4E4E7);
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;

    return Scaffold(
      backgroundColor: theme.colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Icon(Icons.bookmark_rounded, color: theme.colors.primary, size: 22),
            const SizedBox(width: 8),
            Text(L10n.s(ref, 'savedMessages'),
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: ChatOrganisationService.getSavedMessages(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(color: theme.colors.primary));
          }

          final messages = snapshot.data ?? [];

          if (messages.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colors.primary.withValues(alpha: isDark ? 0.12 : 0.08),
                      border: Border.all(
                        color: theme.colors.primary.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.bookmark_outline_rounded,
                      size: 38,
                      color: theme.colors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('No saved messages',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'Long press any message in a chat\nand tap Save to store it here',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textMuted),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: messages.length,
            itemBuilder: (_, i) {
              final msg = messages[i];
              return _SavedMessageTile(
                message: msg,
                cardBg: cardBg,
                cardBorder: cardBorder,
                textColor: textColor,
                textMuted: textMuted,
                primaryColor: theme.colors.primary,
                onUnsave: () => ChatOrganisationService.unsaveMessage(
                    msg['id'] as String),
              );
            },
          );
        },
      ),
    );
  }
}

class _SavedMessageTile extends StatelessWidget {
  final Map<String, dynamic> message;
  final Color cardBg;
  final Color cardBorder;
  final Color textColor;
  final Color textMuted;
  final Color primaryColor;
  final VoidCallback onUnsave;

  const _SavedMessageTile({
    required this.message,
    required this.cardBg,
    required this.cardBorder,
    required this.textColor,
    required this.textMuted,
    required this.primaryColor,
    required this.onUnsave,
  });

  @override
  Widget build(BuildContext context) {
    final type = message['type'] as String? ?? 'text';
    final text = message['text'] as String? ?? '';
    final savedAt = message['savedAt'] as Timestamp?;
    final senderId = message['senderId'] as String?;
    final myUid = FirebaseService.auth.currentUser?.uid;

    // Resolve proper human-readable sender name
    final rawSender = message['senderName'] as String?;
    String senderName = 'Contact';
    if (senderId != null && senderId == myUid) {
      senderName = 'You';
    } else if (rawSender != null && rawSender.isNotEmpty && rawSender != 'Unknown' && rawSender.length < 24) {
      senderName = rawSender;
    } else if (rawSender != null && rawSender.isNotEmpty) {
      senderName = rawSender;
    }

    final initial = senderName.isNotEmpty ? senderName[0].toUpperCase() : 'Y';

    return Dismissible(
      key: Key(message['id'] as String? ?? ''),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.shade900,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onUnsave(),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header — sender + time
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: primaryColor.withValues(alpha: 0.15),
                  child: Text(
                    initial,
                    style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Text(senderName,
                    style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5)),
                const Spacer(),
                if (savedAt != null)
                  Text(
                    DateFormat('MMM d, h:mm a').format(savedAt.toDate()),
                    style: TextStyle(color: textMuted, fontSize: 11),
                  ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: onUnsave,
                  child: Icon(Icons.bookmark_remove_rounded,
                      color: primaryColor, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Content
            if (type == 'text')
              Text(text, style: TextStyle(color: textColor, fontSize: 14))
            else if (type == 'image')
              Row(children: [
                Icon(Icons.image_rounded, color: primaryColor, size: 16),
                const SizedBox(width: 6),
                Text('Photo', style: TextStyle(color: textMuted, fontSize: 13)),
              ])
            else if (type == 'voice')
              Row(children: [
                Icon(Icons.mic_rounded, color: primaryColor, size: 16),
                const SizedBox(width: 6),
                Text('Voice message', style: TextStyle(color: textMuted, fontSize: 13)),
              ])
            else if (type == 'gif')
              Row(children: [
                Text('GIF', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(width: 6),
                Text('Animation', style: TextStyle(color: textMuted, fontSize: 13)),
              ])
            else
              Row(children: [
                Icon(Icons.attach_file_rounded, color: primaryColor, size: 16),
                const SizedBox(width: 6),
                Text(type, style: TextStyle(color: textMuted, fontSize: 13)),
              ]),
          ],
        ),
      ),
    );
  }
}
