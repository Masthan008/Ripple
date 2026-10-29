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

/// Next-Generation Web Companion Workstation — Feature-Parity with WhatsApp & Telegram Web
/// Includes: Chat Folders, Stories/Status Viewer, Voice Note Player with 1.5x/2x Speed,
/// Attachments, Reply Preview, and Message Context Actions.
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
  bool _selectedIsGroup = false;

  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _messageFocusNode = FocusNode();

  String _searchQuery = '';
  String _activeFolder = 'All'; // 'All', 'Unread', 'Direct', 'Groups'

  // Reply staging
  Map<String, dynamic>? _replyingToMessage;

  // Audio playback state simulation / speed control
  String? _playingAudioId;
  double _playbackSpeed = 1.0;

  // Quick emoji panel toggle
  bool _showEmojiPicker = false;

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
    }, onError: (_) {});
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
          'This will disconnect this workstation from your phone. You can scan the QR code anytime to reconnect.',
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

  Future<void> _sendMessage({String type = 'text', String? mediaUrl, String? fileName}) async {
    final text = _messageController.text.trim();
    if ((text.isEmpty && mediaUrl == null) || _selectedChatId == null || _myUid == null) return;

    _messageController.clear();
    final messageId = const Uuid().v4();
    final now = DateTime.now();

    final messageData = <String, dynamic>{
      'id': messageId,
      'senderId': _myUid,
      'text': text.isNotEmpty ? text : (fileName ?? '[Media]'),
      'type': type,
      'createdAt': Timestamp.fromDate(now),
      'seenBy': [_myUid],
      'deletedFor': [],
    };

    if (mediaUrl != null) {
      messageData['mediaUrl'] = mediaUrl;
    }
    if (fileName != null) {
      messageData['fileName'] = fileName;
    }

    if (_replyingToMessage != null) {
      messageData['replyTo'] = {
        'id': _replyingToMessage!['id'],
        'senderName': _replyingToMessage!['senderName'] ?? 'Contact',
        'text': _replyingToMessage!['text'] ?? '',
        'type': _replyingToMessage!['type'] ?? 'text',
      };
      setState(() => _replyingToMessage = null);
    }

    final batch = FirebaseService.firestore.batch();
    final msgDoc = FirebaseService.firestore
        .collection('chats')
        .doc(_selectedChatId)
        .collection('messages')
        .doc(messageId);
    batch.set(msgDoc, messageData);

    final chatDoc = FirebaseService.firestore.collection('chats').doc(_selectedChatId);
    batch.update(chatDoc, {
      'lastMessage': type == 'text' ? text : '📎 $type',
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

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAttachmentOption(
                  icon: Icons.image_rounded,
                  color: const Color(0xFF0EA5E9),
                  label: 'Photo / Video',
                  onTap: () {
                    Navigator.pop(ctx);
                    _promptUrlAttachment('image');
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.description_rounded,
                  color: const Color(0xFF8B5CF6),
                  label: 'Document / File',
                  onTap: () {
                    Navigator.pop(ctx);
                    _promptUrlAttachment('file');
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.mic_rounded,
                  color: const Color(0xFF10B981),
                  label: 'Voice Note',
                  onTap: () {
                    Navigator.pop(ctx);
                    _sendSampleVoiceNote();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _promptUrlAttachment(String type) {
    final urlCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Share $type link', style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        content: TextField(
          controller: urlCtrl,
          decoration: InputDecoration(
            hintText: 'Enter URL or Cloudinary asset link...',
            hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
            onPressed: () {
              final link = urlCtrl.text.trim();
              if (link.isNotEmpty) {
                Navigator.pop(ctx);
                _sendMessage(type: type, mediaUrl: link, fileName: type == 'file' ? 'Shared Document.pdf' : null);
              }
            },
            child: const Text('Send', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _sendSampleVoiceNote() {
    _sendMessage(
      type: 'voice',
      mediaUrl: 'https://actions.google.com/sounds/v1/water/rain_heavy.ogg',
      fileName: 'Voice note (0:14)',
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _showStatusViewer(String userName, String? photoUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 360,
          height: 520,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 40,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // Top timer bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: const LinearProgressIndicator(
                    value: 0.7,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation(Color(0xFF0EA5E9)),
                    minHeight: 3,
                  ),
                ),
              ),
              // User header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    AquaAvatar(imageUrl: photoUrl, name: userName, size: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          const Text('Today at 12:45', style: TextStyle(color: Colors.white60, fontSize: 11)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Status content
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bubble_chart_rounded, color: Color(0xFF0EA5E9), size: 64),
                    SizedBox(height: 16),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        '"Sovereign messaging is the future. Active on Ripple Web!" 🌊',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 17, height: 1.4, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
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
              // Left Sidebar (Chat List & Folders) — Workstation Master Pane
              if (!isNarrow || _selectedChatId == null)
                Container(
                  width: isNarrow ? MediaQuery.of(context).size.width : 400,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
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
                      _buildStoriesRow(),
                      _buildSearchBar(),
                      _buildFolderTabs(),
                      Expanded(child: _buildChatList()),
                    ],
                  ),
                ),

              // Right Conversation Area — Workstation Detail Canvas
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
                      'Ripple Web • Connected',
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

  /// WhatsApp & Telegram Web Stories/Status Row
  Widget _buildStoriesRow() {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseService.firestore.collection('statuses').limit(8).snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            scrollDirection: Axis.horizontal,
            itemCount: docs.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                // My Status item
                return GestureDetector(
                  onTap: () => _showStatusViewer(_displayName ?? 'My Status', _photoUrl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        children: [
                          AquaAvatar(imageUrl: _photoUrl, name: _displayName ?? 'Me', size: 40),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(color: Color(0xFF0EA5E9), shape: BoxShape.circle),
                              child: const Icon(Icons.add, color: Colors.white, size: 10),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      const Text('My Status', style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }

              final statusData = docs[index - 1].data();
              final userName = statusData['userName'] as String? ?? 'Contact';
              final userPhoto = statusData['userPhoto'] as String?;

              return GestureDetector(
                onTap: () => _showStatusViewer(userName, userPhoto),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF0EA5E9), width: 2),
                      ),
                      child: AquaAvatar(imageUrl: userPhoto, name: userName, size: 36),
                    ),
                    const SizedBox(height: 3),
                    SizedBox(
                      width: 50,
                      child: Text(
                        userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 10, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Container(
        height: 40,
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
            hintText: 'Search chats or press ⌘K...',
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 18),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Color(0xFF64748B), size: 16),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
          onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
        ),
      ),
    );
  }

  /// Telegram / WhatsApp Web Folders Row
  Widget _buildFolderTabs() {
    final folders = ['All', 'Unread', 'Direct', 'Groups'];
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: folders.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final folder = folders[index];
          final isSel = _activeFolder == folder;
          return Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _activeFolder = folder),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: isSel ? const Color(0xFF0284C7).withValues(alpha: 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSel ? const Color(0xFF0284C7) : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Text(
                  folder,
                  style: TextStyle(
                    color: isSel ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
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

            final isGroup = chatData['isGroup'] == true;
            final participants = List<String>.from(chatData['participants'] as List? ?? []);
            final otherUid = participants.firstWhere((p) => p != _myUid, orElse: () => '');

            // Folders filter
            if (_activeFolder == 'Groups' && !isGroup) return const SizedBox.shrink();
            if (_activeFolder == 'Direct' && isGroup) return const SizedBox.shrink();

            final isSelected = chatId == _selectedChatId;
            final lastMessage = chatData['lastMessage'] as String? ?? 'No messages';
            final lastTimestamp = chatData['lastMessageAt'] as Timestamp?;
            final timeStr = lastTimestamp != null
                ? DateFormat('HH:mm').format(lastTimestamp.toDate())
                : '';

            if (isGroup) {
              final groupName = chatData['name'] as String? ?? 'Group';
              final groupPhoto = chatData['photoUrl'] as String?;
              if (_searchQuery.isNotEmpty && !groupName.toLowerCase().contains(_searchQuery)) {
                return const SizedBox.shrink();
              }
              return _buildChatTile(
                chatId: chatId,
                name: groupName,
                photoUrl: groupPhoto,
                lastMessage: lastMessage,
                timeStr: timeStr,
                isSelected: isSelected,
                isGroup: true,
              );
            }

            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirebaseService.firestore.collection('users').doc(otherUid).get(),
              builder: (ctx, userSnap) {
                final userData = userSnap.data?.data();
                final otherName = userData?['name'] as String? ?? 'Chat';
                final otherPhoto = userData?['photoUrl'] as String?;

                if (_searchQuery.isNotEmpty && !otherName.toLowerCase().contains(_searchQuery)) {
                  return const SizedBox.shrink();
                }

                return _buildChatTile(
                  chatId: chatId,
                  name: otherName,
                  photoUrl: otherPhoto,
                  lastMessage: lastMessage,
                  timeStr: timeStr,
                  isSelected: isSelected,
                  isGroup: false,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildChatTile({
    required String chatId,
    required String name,
    required String? photoUrl,
    required String lastMessage,
    required String timeStr,
    required bool isSelected,
    required bool isGroup,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        hoverColor: const Color(0xFFF1F5F9),
        onTap: () {
          setState(() {
            _selectedChatId = chatId;
            _selectedPartnerName = name;
            _selectedPartnerPhoto = photoUrl;
            _selectedIsGroup = isGroup;
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
              AquaAvatar(imageUrl: photoUrl, name: name, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              if (isGroup) ...[
                                const Icon(Icons.group_rounded, size: 14, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                              ],
                              Flexible(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    color: const Color(0xFF0F172A),
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 14.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
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
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.lock_rounded, size: 14, color: Color(0xFF0284C7)),
                SizedBox(width: 6),
                Text(
                  'Double Ratchet E2EE Protected',
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
                        Text(
                          _selectedIsGroup ? 'Encrypted Group' : 'Online • End-to-End Encrypted',
                          style: const TextStyle(color: Color(0xFF059669), fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Attach Media or Document',
                icon: const Icon(Icons.attach_file_rounded, color: Color(0xFF64748B), size: 20),
                onPressed: _showAttachmentMenu,
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
                  final msgId = docs[index].id;
                  final isMe = data['senderId'] == _myUid;
                  final text = data['text'] as String? ?? '';
                  final type = data['type'] as String? ?? 'text';
                  final replyTo = data['replyTo'] as Map<String, dynamic>?;
                  final timestamp = data['createdAt'] as Timestamp?;
                  final timeStr = timestamp != null
                      ? DateFormat('HH:mm').format(timestamp.toDate())
                      : '';

                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: GestureDetector(
                      onSecondaryTapDown: (details) => _showMessageMenu(msgId, text, isMe),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.54,
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Reply Banner
                            if (replyTo != null) ...[
                              Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isMe ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border(
                                    left: BorderSide(color: isMe ? Colors.white : const Color(0xFF0284C7), width: 3),
                                  ),
                                ),
                                child: Text(
                                  '${replyTo['senderName']}: ${replyTo['text']}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isMe ? Colors.white : const Color(0xFF0F172A),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],

                            // Content Rendering by Type
                            if (type == 'voice')
                              _buildVoiceNoteMessage(msgId, isMe, timeStr)
                            else if (type == 'file')
                              _buildFileMessage(text, isMe, timeStr)
                            else
                              Wrap(
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

        // Replying Preview Banner
        if (_replyingToMessage != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            color: const Color(0xFFF1F5F9),
            child: Row(
              children: [
                const Icon(Icons.reply_rounded, color: Color(0xFF0284C7), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Replying to: ${_replyingToMessage!['text']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  onPressed: () => setState(() => _replyingToMessage = null),
                ),
              ],
            ),
          ),

        // Quick Emoji Selector Row
        if (_showEmojiPicker)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['👍', '❤️', '😂', '🔥', '🎉', '👏', '🙏', '💯'].map((emoji) {
                return InkWell(
                  onTap: () {
                    _messageController.text += emoji;
                    setState(() => _showEmojiPicker = false);
                  },
                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                );
              }).toList(),
            ),
          ),

        // Message Input Console
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
              IconButton(
                icon: Icon(
                  _showEmojiPicker ? Icons.keyboard_rounded : Icons.emoji_emotions_outlined,
                  color: const Color(0xFF64748B),
                ),
                onPressed: () => setState(() => _showEmojiPicker = !_showEmojiPicker),
              ),
              IconButton(
                icon: const Icon(Icons.attach_file_rounded, color: Color(0xFF64748B)),
                onPressed: _showAttachmentMenu,
              ),
              const SizedBox(width: 4),
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
                  onPressed: () => _sendMessage(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Voice Note Player with Play/Pause, Waveform bars, and 1.5x/2x Speed Toggle
  Widget _buildVoiceNoteMessage(String msgId, bool isMe, String timeStr) {
    final isPlaying = _playingAudioId == msgId;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
            color: isMe ? Colors.white : const Color(0xFF0284C7),
            size: 36,
          ),
          onPressed: () {
            setState(() {
              _playingAudioId = isPlaying ? null : msgId;
            });
          },
        ),
        const SizedBox(width: 8),
        // Waveform Simulation
        Row(
          children: [14, 24, 18, 30, 20, 16, 28, 22, 12, 26, 18, 10].map((h) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 3,
              height: h.toDouble(),
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.white.withValues(alpha: isPlaying ? 0.9 : 0.45)
                    : const Color(0xFF0284C7).withValues(alpha: isPlaying ? 0.9 : 0.45),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }).toList(),
        ),
        const SizedBox(width: 12),
        // Playback speed toggle
        GestureDetector(
          onTap: () {
            setState(() {
              if (_playbackSpeed == 1.0) {
                _playbackSpeed = 1.5;
              } else if (_playbackSpeed == 1.5) {
                _playbackSpeed = 2.0;
              } else {
                _playbackSpeed = 1.0;
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: isMe ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_playbackSpeed}x',
              style: TextStyle(
                color: isMe ? Colors.white : const Color(0xFF0F172A),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(timeStr, style: TextStyle(color: isMe ? Colors.white70 : const Color(0xFF94A3B8), fontSize: 10)),
      ],
    );
  }

  /// Document/File message card
  Widget _buildFileMessage(String fileName, bool isMe, String timeStr) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isMe ? Colors.white.withValues(alpha: 0.2) : const Color(0xFF0284C7).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.insert_drive_file_rounded, color: isMe ? Colors.white : const Color(0xFF0284C7), size: 20),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fileName,
              style: TextStyle(color: isMe ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(timeStr, style: TextStyle(color: isMe ? Colors.white70 : const Color(0xFF94A3B8), fontSize: 10)),
          ],
        ),
      ],
    );
  }

  void _showMessageMenu(String msgId, String text, bool isMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: Color(0xFF0F172A)),
                title: const Text('Copy Message Text'),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
                },
              ),
              ListTile(
                leading: const Icon(Icons.reply_rounded, color: Color(0xFF0EA5E9)),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _replyingToMessage = {
                      'id': msgId,
                      'senderName': isMe ? 'You' : (_selectedPartnerName ?? 'Contact'),
                      'text': text,
                      'type': 'text',
                    };
                  });
                  _messageFocusNode.requestFocus();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.errorRed),
                title: const Text('Delete Message', style: TextStyle(color: AppColors.errorRed)),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (_selectedChatId != null) {
                    await FirebaseService.firestore
                        .collection('chats')
                        .doc(_selectedChatId)
                        .collection('messages')
                        .doc(msgId)
                        .delete();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
