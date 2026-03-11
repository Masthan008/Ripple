import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../services/chat_organisation_service.dart';

/// Screen showing all saved/bookmarked messages.
class SavedMessagesScreen extends StatelessWidget {
  const SavedMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Text('🔖', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text('Saved Messages',
                style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: ChatOrganisationService.getSavedMessages(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.aquaCore));
          }

          final messages = snapshot.data ?? [];

          if (messages.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🔖', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 16),
                  const Text('No saved messages',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'Long press any message\nand tap Save',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4)),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: messages.length,
            itemBuilder: (_, i) {
              final msg = messages[i];
              return _SavedMessageTile(
                message: msg,
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
  final VoidCallback onUnsave;

  const _SavedMessageTile({
    required this.message,
    required this.onUnsave,
  });

  @override
  Widget build(BuildContext context) {
    final type = message['type'] as String? ?? 'text';
    final text = message['text'] as String? ?? '';
    final senderName = message['senderName'] as String? ?? 'Unknown';
    final savedAt = message['savedAt'] as Timestamp?;

    return Dismissible(
      key: Key(message['id'] as String? ?? ''),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red.shade900,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onUnsave(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header — sender + time
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFF1A2A40),
                  child: Text(
                    senderName[0].toUpperCase(),
                    style:
                        const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Text(senderName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                const Spacer(),
                if (savedAt != null)
                  Text(
                    DateFormat('MMM d, h:mm a').format(savedAt.toDate()),
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11),
                  ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onUnsave,
                  child: const Icon(Icons.bookmark_remove_rounded,
                      color: AppColors.aquaCore, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Content
            if (type == 'text')
              Text(text,
                  style: const TextStyle(color: Colors.white70, fontSize: 14))
            else if (type == 'image')
              const Row(children: [
                Icon(Icons.image_rounded,
                    color: AppColors.aquaCore, size: 16),
                SizedBox(width: 4),
                Text('Photo',
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
              ])
            else if (type == 'voice')
              const Row(children: [
                Icon(Icons.mic_rounded,
                    color: AppColors.aquaCore, size: 16),
                SizedBox(width: 4),
                Text('Voice message',
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
              ])
            else if (type == 'gif')
              const Row(children: [
                Text('GIF',
                    style: TextStyle(
                        color: AppColors.aquaCore,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
                SizedBox(width: 4),
                Text('Animation',
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
              ])
            else
              Row(children: [
                const Icon(Icons.attach_file_rounded,
                    color: AppColors.aquaCore, size: 16),
                const SizedBox(width: 4),
                Text(type,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 13)),
              ]),
          ],
        ),
      ),
    );
  }
}
