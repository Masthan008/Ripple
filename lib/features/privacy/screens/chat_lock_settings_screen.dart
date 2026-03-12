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
      backgroundColor: const Color(0xFF060D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        title: const Text('🔒 Chat Lock'),
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
                Text('🔒', style: TextStyle(fontSize: 24)),
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
                            Text('🔓', style: TextStyle(fontSize: 64)),
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
                          return ListTile(
                            leading: const Icon(Icons.lock_rounded,
                                color: Color(0xFF0EA5E9)),
                            title: Text(chatId,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13)),
                            trailing: IconButton(
                              icon: const Icon(Icons.lock_open_rounded,
                                  color: Colors.red),
                              onPressed: () async {
                                await PrivacyService.unlockChatLock(chatId);
                                _loadLockedChats();
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
