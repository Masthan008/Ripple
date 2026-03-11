import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/firebase_service.dart';
import '../services/chat_organisation_service.dart';

/// Screen showing archived chats.
class ArchivedChatsScreen extends StatelessWidget {
  const ArchivedChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF060D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Archived Chats',
            style: TextStyle(color: Colors.white, fontSize: 18)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseService.firestore
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, userSnap) {
          final archivedIds = List<String>.from(
              userSnap.data?.data() is Map
                  ? ((userSnap.data!.data() as Map)['archivedChats']
                          as List? ??
                      [])
                  : []);

          if (archivedIds.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.archive_outlined,
                      size: 64,
                      color: Colors.white.withValues(alpha: 0.1)),
                  const SizedBox(height: 16),
                  const Text('No archived chats',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Long press a chat to archive it',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4))),
                ],
              ),
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseService.firestore
                .collection('chats')
                .where('participants', arrayContains: uid)
                .snapshots(),
            builder: (context, chatsSnap) {
              if (!chatsSnap.hasData) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.aquaCore));
              }

              final archivedChats = chatsSnap.data!.docs
                  .where((d) => archivedIds.contains(d.id))
                  .toList();

              if (archivedChats.isEmpty) {
                return const Center(
                  child: Text('No archived chats',
                      style: TextStyle(color: Colors.white54)),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: archivedChats.length,
                itemBuilder: (_, i) {
                  final doc = archivedChats[i];
                  final data = doc.data() as Map<String, dynamic>;
                  final chatId = doc.id;
                  final participants =
                      List<String>.from(data['participants'] ?? []);
                  final otherUid =
                      participants.firstWhere((p) => p != uid,
                          orElse: () => '');
                  final name =
                      data['name'] as String? ?? 'Chat';
                  final lastMsg =
                      data['lastMessage'] as String? ?? '';
                  final lastMsgAt =
                      data['lastMessageAt'] as Timestamp?;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF1A2A40),
                      child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white)),
                    ),
                    title: Text(name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                    subtitle: Text(lastMsg,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13)),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (lastMsgAt != null)
                          Text(
                            DateFormat('MMM d').format(lastMsgAt.toDate()),
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11),
                          ),
                      ],
                    ),
                    onLongPress: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: const Color(0xFF0A1628),
                        shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (_) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            ListTile(
                              leading: const Icon(Icons.unarchive_rounded,
                                  color: AppColors.aquaCore),
                              title: const Text('Unarchive',
                                  style: TextStyle(color: Colors.white)),
                              onTap: () async {
                                await ChatOrganisationService.unarchiveChat(
                                    chatId);
                                if (context.mounted) Navigator.pop(context);
                              },
                            ),
                            SizedBox(
                                height:
                                    MediaQuery.of(context).padding.bottom + 16),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
