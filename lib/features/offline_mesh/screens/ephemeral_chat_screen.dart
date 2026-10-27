import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../models/ephemeral_peer.dart';
import '../services/ephemeral_vault.dart';
import '../services/offline_mesh_service.dart';

class EphemeralChatScreen extends ConsumerStatefulWidget {
  final EphemeralPeer? targetPeer;

  const EphemeralChatScreen({super.key, this.targetPeer});

  @override
  ConsumerState<EphemeralChatScreen> createState() => _EphemeralChatScreenState();
}

class _EphemeralChatScreenState extends ConsumerState<EphemeralChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _selectedTtl = 60; // 60 seconds default burn timer

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    // Auto-wipe memory vault on screen exit — zero disk persistence guarantee
    ref.read(ephemeralVaultProvider.notifier).panicWipe();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    AppHaptics.lightTap();

    ref.read(offlineMeshServiceProvider).sendMessage(
          text: text,
          ttlSeconds: _selectedTtl,
          targetPeer: widget.targetPeer,
        );

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _panicBurnAndExit() {
    AppHaptics.heavyTap();
    ref.read(ephemeralVaultProvider.notifier).panicWipe();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Conversation incinerated. Memory buffer scrubbed to 0x00.'),
        backgroundColor: AppColors.errorRed,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(ephemeralVaultProvider);
    final targetName = widget.targetPeer?.alias ?? 'Mesh Broadcast Room';

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          ref.read(ephemeralVaultProvider.notifier).panicWipe();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF060D1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0A1424),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                targetName,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded, color: Colors.orangeAccent, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    'Burns after ${_selectedTtl}s • RAM Only',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            // TTL Selector Dropdown
            PopupMenuButton<int>(
              icon: const Icon(Icons.timer_rounded, color: AppColors.aquaCore),
              tooltip: 'Set Auto-Burn Timer',
              onSelected: (val) => setState(() => _selectedTtl = val),
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 30, child: Text('30 Seconds Dissolve')),
                const PopupMenuItem(value: 60, child: Text('1 Minute Dissolve')),
                const PopupMenuItem(value: 300, child: Text('5 Minutes Dissolve')),
              ],
            ),

            // Panic Wipe Button
            IconButton(
              tooltip: 'Panic Wipe & Exit',
              icon: const Icon(Icons.delete_forever_rounded, color: AppColors.errorRed),
              onPressed: _panicBurnAndExit,
            ),
          ],
        ),
        body: Column(
          children: [
            // Ephemeral Security Notice Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.black38,
              child: Row(
                children: const [
                  Icon(Icons.shield_rounded, color: AppColors.onlineGreen, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'BitChat Protocol: Messages dissolve in memory when timer expires. Leaving this screen wipes all traces permanently.',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),

            // Message List
            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.security_rounded, color: AppColors.aquaCyan, size: 48),
                          SizedBox(height: 12),
                          Text(
                            'No active mesh messages.',
                            style: TextStyle(color: Colors.white60, fontSize: 14),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Messages exist only in volatile RAM while timer runs.',
                            style: TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        // Reverse index for list view
                        final msg = messages[messages.length - 1 - index];
                        final isMe = msg.isMine;
                        final remaining = msg.remainingSeconds;

                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.75,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? AppColors.aquaCore.withValues(alpha: remaining < 5 ? 0.15 : 0.28)
                                  : const Color(0xFF142236).withValues(alpha: remaining < 5 ? 0.3 : 1.0),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(isMe ? 16 : 4),
                                bottomRight: Radius.circular(isMe ? 4 : 16),
                              ),
                              border: Border.all(
                                color: remaining < 5
                                    ? Colors.orangeAccent.withValues(alpha: 0.6)
                                    : (isMe ? AppColors.aquaCore.withValues(alpha: 0.4) : Colors.white12),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isMe)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      msg.senderAlias,
                                      style: const TextStyle(
                                        color: AppColors.aquaCyan,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                Text(
                                  msg.text,
                                  style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.35),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Icon(
                                      Icons.local_fire_department_rounded,
                                      color: remaining < 10 ? Colors.redAccent : Colors.orangeAccent,
                                      size: 13,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${remaining}s left',
                                      style: TextStyle(
                                        color: remaining < 10 ? Colors.redAccent : Colors.white54,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Message Compose Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF0C1626),
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      child: TextField(
                        controller: _textController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'BitChat message (${_selectedTtl}s burn)...',
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.aquaGradient,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.black, size: 20),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
