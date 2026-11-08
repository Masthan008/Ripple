import '../../../core/services/firebase_service.dart';
import '../../../shared/widgets/aqua_avatar.dart';
import 'package:flutter/material.dart';

import '../../../core/services/privacy_service.dart';

/// Shows list of locked chats with ability to unlock.
class ChatLockSettingsScreen extends StatefulWidget {
  const ChatLockSettingsScreen({super.key});

  @override
  State<ChatLockSettingsScreen> createState() => _ChatLockSettingsScreenState();
}

class _ChatLockSettingsScreenState extends State<ChatLockSettingsScreen> {
  List<String> _lockedChats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLockedChats();
  }

  Future<void> _loadLockedChats() async {
    final locked = await PrivacyService.getLockedChats();
    if (mounted) {
      setState(() {
        _lockedChats = locked;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: Color(0xFF0EA5E9), size: 22),
            SizedBox(width: 8),
            Text('Chat Lock'),
          ],
        ),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF0EA5E9).withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_rounded, color: Color(0xFF0EA5E9), size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Long press any chat in the chat list to lock it. '
                    'Locked chats require fingerprint or PIN to open.',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF0EA5E9)))
                : _lockedChats.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_open_rounded, color: Colors.white24, size: 64),
                            SizedBox(height: 16),
                            Text('No locked chats',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            SizedBox(height: 8),
                            Text('Long press a chat to lock it',
                                style: TextStyle(color: Colors.white54)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _lockedChats.length,
                        itemBuilder: (_, i) {
                          final chatId = _lockedChats[i];
                          return _LockedChatTile(
                            chatId: chatId,
                            onUnlock: () async {
                              await PrivacyService.unlockChatLock(chatId);
                              _loadLockedChats();
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}



class _LockedChatTile extends StatelessWidget {
  final String chatId;
  final VoidCallback onUnlock;

  const _LockedChatTile({
    required this.chatId,
    required this.onUnlock,
  });

  Future<Map<String, dynamic>> _resolveContactInfo() async {
    try {
      final currentUid = FirebaseService.auth.currentUser?.uid;
      String targetUid = chatId;
      if (chatId.contains('_')) {
        final parts = chatId.split('_');
        targetUid = parts.firstWhere((p) => p != currentUid, orElse: () => parts.first);
      }

      // Check users collection first
      final userDoc = await FirebaseService.firestore.collection('users').doc(targetUid).get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        final name = (data['displayName'] ?? data['name'] ?? data['username'] ?? 'User').toString();
        final avatar = (data['avatarUrl'] ?? data['photoURL'] ?? data['profilePicture'] ?? '').toString();
        final handle = data['handle'] != null ? '@${data['handle']}' : (data['username'] != null ? '@${data['username']}' : null);
        return {
          'name': name,
          'avatar': avatar,
          'handle': handle,
          'isGroup': false,
        };
      }

      // Check groups collection
      final groupDoc = await FirebaseService.firestore.collection('groups').doc(chatId).get();
      if (groupDoc.exists && groupDoc.data() != null) {
        final gData = groupDoc.data()!;
        final name = (gData['name'] ?? 'Group Chat').toString();
        final avatar = (gData['photoUrl'] ?? gData['avatarUrl'] ?? '').toString();
        return {
          'name': name,
          'avatar': avatar,
          'handle': 'Group Chat',
          'isGroup': true,
        };
      }
    } catch (_) {}

    return {
      'name': 'Chat (${chatId.length > 8 ? chatId.substring(0, 8) : chatId})',
      'avatar': '',
      'handle': null,
      'isGroup': false,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _resolveContactInfo(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final name = info?['name'] ?? 'Loading...';
        final avatar = info?['avatar'] as String?;
        final handle = info?['handle'] as String?;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: ListTile(
            leading: AquaAvatar(
              imageUrl: (avatar != null && avatar.isNotEmpty) ? avatar : null,
              name: name,
              size: 44,
            ),
            title: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            subtitle: handle != null
                ? Text(
                    handle,
                    style: TextStyle(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  )
                : null,
            trailing: IconButton(
              icon: const Icon(Icons.lock_open_rounded, color: Color(0xFF0EA5E9)),
              tooltip: 'Unlock chat',
              onPressed: onUnlock,
            ),
          ),
        );
      },
    );
  }
}
