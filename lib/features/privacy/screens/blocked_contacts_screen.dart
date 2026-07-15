import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_service.dart';
import '../../friends/providers/friends_provider.dart';

/// Manage blocked contacts — view all blocked users with ability to unblock.
class BlockedContactsScreen extends ConsumerWidget {
  const BlockedContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedUsersAsync = ref.watch(blockedUsersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF060D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        title: const Row(
          children: [
            Icon(Icons.block_rounded, color: Colors.redAccent, size: 22),
            SizedBox(width: 8),
            Text('Blocked Contacts'),
          ],
        ),
        foregroundColor: Colors.white,
      ),
      body: blockedUsersAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF0EA5E9)),
        ),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: Colors.white54)),
        ),
        data: (blockedUids) {
          if (blockedUids.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      color: Colors.white.withOpacity(0.15), size: 72),
                  const SizedBox(height: 16),
                  const Text(
                    'No blocked contacts',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'You haven\'t blocked anyone yet',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Info banner
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.redAccent.withOpacity(0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: Colors.redAccent, size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Blocked contacts can\'t call you, send you messages, '
                        'or see your last seen and online status.',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView.builder(
                  itemCount: blockedUids.length,
                  itemBuilder: (_, i) {
                    final uid = blockedUids[i];
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseService.firestore
                          .collection('users')
                          .doc(uid)
                          .get(),
                      builder: (context, snapshot) {
                        final data = snapshot.data?.data()
                            as Map<String, dynamic>?;
                        final name = data?['username'] as String? ??
                            data?['displayName'] as String? ??
                            uid;
                        final photo =
                            data?['profileImageUrl'] as String? ?? '';

                        return ListTile(
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundColor:
                                const Color(0xFF0EA5E9).withOpacity(0.2),
                            backgroundImage: photo.isNotEmpty
                                ? NetworkImage(photo)
                                : null,
                            child: photo.isEmpty
                                ? Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Color(0xFF0EA5E9),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          title: Text(name,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 15)),
                          trailing: TextButton(
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  backgroundColor: const Color(0xFF0A1628),
                                  title: const Text('Unblock Contact',
                                      style: TextStyle(color: Colors.white)),
                                  content: Text(
                                    'Unblock $name? They will be able to '
                                    'contact you again.',
                                    style: const TextStyle(
                                        color: Colors.white70),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Unblock',
                                          style: TextStyle(
                                              color: Colors.redAccent)),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true) {
                                ref
                                    .read(friendsServiceProvider)
                                    .unblockUser(uid);
                              }
                            },
                            child: const Text('Unblock',
                                style: TextStyle(color: Colors.redAccent)),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
