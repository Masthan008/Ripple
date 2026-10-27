import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/firebase_service.dart';
import '../../../shared/widgets/aqua_avatar.dart';
import '../services/web_companion_service.dart';

class WebMainScreen extends ConsumerStatefulWidget {
  const WebMainScreen({super.key});

  static const routePath = '/web-main';

  @override
  ConsumerState<WebMainScreen> createState() => _WebMainScreenState();
}

class _WebMainScreenState extends ConsumerState<WebMainScreen> {
  String? _myUid;
  String? _displayName;
  String? _photoUrl;

  String? _selectedChatId;
  String? _selectedPartnerName;
  String? _selectedPartnerPhoto;

  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _messageFocusNode = FocusNode();
  String _searchQuery = '';

  StreamSubscription? _deviceRevocationSub;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessionAndVerify();
  }

  @override
  void dispose() {
    _deviceRevocationSub?.cancel();
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSessionAndVerify() async {
    final service = ref.read(webCompanionServiceProvider);
    final session = await service.getSavedWebSession();

    if (session == null) {
      if (mounted) context.go('/web-pairing');
      return;
    }
    if (!mounted) return;

    final uid = session['uid']!;
    final sessionId = session['sessionId']!;

    setState(() {
      _myUid = uid;
      _displayName = session['displayName'];
      _photoUrl = session['photoUrl'];
      _isLoading = false;
    });

    // Listen for remote device termination from mobile app
    _deviceRevocationSub = service.streamDeviceStatus(uid, sessionId).listen((doc) {
      if (!doc.exists && mounted) {
        _deviceRevocationSub?.cancel();
        _deviceRevocationSub = null;
        service.unlinkWebSession();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session was disconnected from your phone.'),
            backgroundColor: AppColors.errorRed,
          ),
        );
        context.go('/web-pairing');
      }
    }, onError: (_) {
      // Ignore permission errors if token/session is revoked
    });
  }

  Future<void> _disconnectSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        title: const Text(
          'Log out from Ripple Web?',
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: const Text(
          'This will disconnect this browser workstation from your phone. You will need to scan the QR code again to reconnect.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _deviceRevocationSub?.cancel();
        _deviceRevocationSub = null;
        await ref.read(webCompanionServiceProvider).unlinkWebSession();
      } catch (e) {
        debugPrint('Logout cleanup error: $e');
      } finally {
        if (mounted) {
          setState(() {
            _selectedChatId = null;
            _myUid = null;
          });
          context.go('/web-pairing');
        }
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _selectedChatId == null || _myUid == null) return;

    _messageController.clear();
    final messageId = const Uuid().v4();
    final now = DateTime.now();

    final messageData = {
      'id': messageId,
      'senderId': _myUid,
      'text': text,
      'type': 'text',
      'createdAt': Timestamp.fromDate(now),
      'seenBy': [_myUid],
      'deletedFor': [],
    };

    final batch = FirebaseService.firestore.batch();
    final msgDoc = FirebaseService.firestore
        .collection('chats')
        .doc(_selectedChatId)
        .collection('messages')
        .doc(messageId);
    batch.set(msgDoc, messageData);

    final chatDoc = FirebaseService.firestore.collection('chats').doc(_selectedChatId);
    batch.update(chatDoc, {
      'lastMessage': text,
      'lastMessageAt': Timestamp.fromDate(now),
      'lastSenderId': _myUid,
    });

    await batch.commit();

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF0284C7))),
      );
    }

    final isNarrow = MediaQuery.of(context).size.width < 768;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
          _searchFocusNode.requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () {
          _searchFocusNode.requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_selectedChatId != null) {
            setState(() => _selectedChatId = null);
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: Row(
            children: [
              // Left Sidebar (Chat List) — Liquid Light Workstation Pane
              if (!isNarrow || _selectedChatId == null)
                Container(
                  width: isNarrow ? MediaQuery.of(context).size.width : 400,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    border: const Border(
                      right: BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                        blurRadius: 16,
                        offset: const Offset(4, 0),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildSidebarHeader(),
                      _buildSearchBar(),
                      Expanded(child: _buildChatList()),
                    ],
                  ),
                ),

              // Right Conversation Area — Liquid Light Canvas
              if (!isNarrow || _selectedChatId != null)
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFF8FAFC), Color(0xFFF0F4F8), Color(0xFFE8F0F8)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: _selectedChatId == null
                        ? _buildEmptyState()
                        : _buildActiveChatArea(isNarrow),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEDF2F7), width: 1.2)),
      ),
      child: Row(
        children: [
          AquaAvatar(
            imageUrl: _photoUrl,
            name: _displayName ?? 'User',
            size: 44,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayName ?? 'Ripple User',
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Ripple Web • Active',
                      style: TextStyle(
                        color: Color(0xFF059669),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Log out / Disconnect Web',
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF64748B), size: 20),
            onPressed: _disconnectSession,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13.5),
          decoration: InputDecoration(
            hintText: 'Search conversations...',
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 19),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Color(0xFF64748B), size: 16),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : Container(
                    margin: const EdgeInsets.all(7),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Text(
                      '⌘K',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
          onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
        ),
      ),
    );
  }

  Widget _buildChatList() {
    if (_myUid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseService.firestore
          .collection('chats')
          .where('participants', arrayContains: _myUid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF0284C7)));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFFCBD5E1), size: 44),
                SizedBox(height: 12),
                Text(
                  'No conversations yet',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (context, index) {
            final chatDoc = docs[index];
            final chatData = chatDoc.data();
            final chatId = chatDoc.id;

            final participants = List<String>.from(chatData['participants'] as List? ?? []);
            final otherUid = participants.firstWhere((p) => p != _myUid, orElse: () => '');

            final isSelected = chatId == _selectedChatId;
            final lastMessage = chatData['lastMessage'] as String? ?? 'No messages';
            final lastTimestamp = chatData['lastMessageAt'] as Timestamp?;
            final timeStr = lastTimestamp != null
                ? DateFormat('HH:mm').format(lastTimestamp.toDate())
                : '';

            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirebaseService.firestore.collection('users').doc(otherUid).get(),
              builder: (ctx, userSnap) {
                final userData = userSnap.data?.data();
                final otherName = userData?['name'] as String? ?? 'Chat';
                final otherPhoto = userData?['photoUrl'] as String?;

                if (_searchQuery.isNotEmpty && !otherName.toLowerCase().contains(_searchQuery)) {
                  return const SizedBox.shrink();
                }

                return Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    hoverColor: const Color(0xFFF1F5F9),
                    onTap: () {
                      setState(() {
                        _selectedChatId = chatId;
                        _selectedPartnerName = otherName;
                        _selectedPartnerPhoto = otherPhoto;
                      });
                      _messageFocusNode.requestFocus();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF0284C7).withValues(alpha: 0.09)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF0284C7).withValues(alpha: 0.3) : Colors.transparent,
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          AquaAvatar(imageUrl: otherPhoto, name: otherName, size: 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        otherName,
                                        style: TextStyle(
                                          color: const Color(0xFF0F172A),
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                          fontSize: 14.5,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      timeStr,
                                      style: TextStyle(
                                        color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF94A3B8),
                                        fontSize: 11,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  lastMessage,
                                  style: TextStyle(
                                    color: isSelected ? const Color(0xFF334155) : const Color(0xFF64748B),
                                    fontSize: 12.5,
                                    height: 1.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.16),
                  blurRadius: 36,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.shield_rounded, color: Color(0xFF0284C7), size: 44),
          ),
          const SizedBox(height: 22),
          Text(
            'Ripple Web Workstation',
            style: AppTextStyles.heading.copyWith(
              color: const Color(0xFF0F172A),
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Select a conversation on the left to start messaging in real time.\nPress Enter to send, Shift + Enter for new lines, Esc to clear.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5, height: 1.5),
            ),
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFCBD5E1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.lock_rounded, size: 14, color: Color(0xFF0284C7)),
                SizedBox(width: 6),
                Text(
                  'End-to-End Encrypted',
                  style: TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveChatArea(bool isNarrow) {
    return Column(
      children: [
        // Conversation Top Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              if (isNarrow)
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
                  onPressed: () => setState(() => _selectedChatId = null),
                ),
              AquaAvatar(
                imageUrl: _selectedPartnerPhoto,
                name: _selectedPartnerName ?? 'Chat',
                size: 42,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedPartnerName ?? 'Chat',
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text('Online', style: TextStyle(color: Color(0xFF059669), fontSize: 11.5, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Log out / Disconnect Web',
                icon: const Icon(Icons.logout_rounded, color: Color(0xFF64748B), size: 19),
                onPressed: _disconnectSession,
              ),
              IconButton(
                tooltip: 'Close conversation (Esc)',
                icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                onPressed: () => setState(() => _selectedChatId = null),
              ),
            ],
          ),
        ),

        // Message Thread
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseService.firestore
                .collection('chats')
                .doc(_selectedChatId)
                .collection('messages')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF0284C7)));
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    'No messages yet. Say hello!',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                  ),
                );
              }

              return ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data();
                  final isMe = data['senderId'] == _myUid;
                  final text = data['text'] as String? ?? '';
                  final timestamp = data['createdAt'] as Timestamp?;
                  final timeStr = timestamp != null
                      ? DateFormat('HH:mm').format(timestamp.toDate())
                      : '';

                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.52,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: isMe
                            ? const LinearGradient(
                                colors: [Color(0xFF0284C7), Color(0xFF0EA5E9)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isMe ? null : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isMe ? 18 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 18),
                        ),
                        border: isMe ? null : Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: isMe
                                ? const Color(0xFF0284C7).withValues(alpha: 0.22)
                                : Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        children: [
                          Text(
                            text,
                            style: TextStyle(
                              color: isMe ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 14.5,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    color: isMe
                                        ? Colors.white.withValues(alpha: 0.75)
                                        : const Color(0xFF94A3B8),
                                    fontSize: 10.5,
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.done_all_rounded, color: Colors.white, size: 13),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        // Message Input Console — Liquid Light Styling with Keyboard Action
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  alignment: Alignment.center,
                  child: TextField(
                    controller: _messageController,
                    focusNode: _messageFocusNode,
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Type a message... (Press Enter to send)',
                      hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0284C7), Color(0xFF0EA5E9)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 19),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
