import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/utils/l10n.dart';

/// Global search screen — searches people, chats, messages, media, and links.
/// Phase 2 upgrade: filter chips, media/link search, functional navigation.
class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  bool _isSearching = false;
  Timer? _searchDebounce;
  String _activeFilter = 'All';

  List<String> _getFilters(WidgetRef ref) => [
        L10n.s(ref, 'all'),
        L10n.s(ref, 'people'),
        L10n.s(ref, 'messages'),
        L10n.s(ref, 'media'),
        L10n.s(ref, 'links'),
      ];

  List<Map<String, dynamic>> _peopleResults = [];
  List<Map<String, dynamic>> _chatResults = [];
  List<Map<String, dynamic>> _messageResults = [];
  List<Map<String, dynamic>> _mediaResults = [];
  List<Map<String, dynamic>> _linkResults = [];

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
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: L10n.s(ref, 'searchHint'),
            hintStyle: const TextStyle(color: Colors.white38),
            border: InputBorder.none,
          ),
          onChanged: (q) {
            setState(() => _query = q);
            if (q.trim().length >= 2) {
              _performSearch(q.trim());
            } else {
              _clearResults();
            }
          },
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.white54),
              onPressed: () {
                _controller.clear();
                setState(() => _query = '');
                _clearResults();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          if (_query.length >= 2) _buildFilterBar(),

          // Results
          Expanded(
            child:
                _query.length < 2
                    ? _buildSearchSuggestions()
                    : _isSearching
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.aquaCore,
                      ),
                    )
                    : _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = _getFilters(ref);
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0A1628),
        border: Border(
          bottom: BorderSide(color: Color(0x0FFFFFFF), width: 0.5),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final filterText = filters[i];
          final filterValue =
              i == 0 ? 'All' : ['People', 'Messages', 'Media', 'Links'][i - 1];
          final isActive = _activeFilter == filterValue;
          final count = _getFilterCount(filterValue);
          return GestureDetector(
            onTap: () {
              AppHaptics.selectionTick();
              setState(() => _activeFilter = filterValue);
            },
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color:
                      isActive
                          ? AppColors.aquaCore.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.06),
                  border: Border.all(
                    color: isActive ? AppColors.aquaCore : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      filterText,
                      style: TextStyle(
                        color: isActive ? AppColors.aquaCore : Colors.white54,
                        fontSize: 13,
                        fontWeight:
                            isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isActive
                                  ? AppColors.aquaCore.withValues(alpha: 0.3)
                                  : Colors.white12,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color:
                                isActive ? AppColors.aquaCore : Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  int _getFilterCount(String filter) {
    switch (filter) {
      case 'People':
        return _peopleResults.length;
      case 'Messages':
        return _messageResults.length;
      case 'Media':
        return _mediaResults.length;
      case 'Links':
        return _linkResults.length;
      default:
        return 0;
    }
  }

  Widget _buildSearchSuggestions() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_rounded,
            size: 64,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          const SizedBox(height: 16),
          Text(
            L10n.s(ref, 'searchRipple'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            L10n.s(ref, 'searchSuggestions'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final showPeople = _activeFilter == 'All' || _activeFilter == 'People';
    final showMessages = _activeFilter == 'All' || _activeFilter == 'Messages';
    final showMedia = _activeFilter == 'All' || _activeFilter == 'Media';
    final showLinks = _activeFilter == 'All' || _activeFilter == 'Links';

    final hasAny =
        (showPeople && _peopleResults.isNotEmpty) ||
        (showMessages && _messageResults.isNotEmpty) ||
        (showMedia && _mediaResults.isNotEmpty) ||
        (showLinks && _linkResults.isNotEmpty);

    if (!hasAny) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('😕', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              '${L10n.s(ref, 'noResults')} "$_query"',
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        // PEOPLE section
        if (showPeople && _peopleResults.isNotEmpty) ...[
          _sectionHeader(L10n.s(ref, 'people'), Icons.person_rounded),
          ..._peopleResults.map(_buildPersonTile),
        ],

        // MESSAGES section
        if (showMessages && _messageResults.isNotEmpty) ...[
          _sectionHeader(L10n.s(ref, 'messages'), Icons.chat_rounded),
          ..._messageResults.map(_buildMessageTile),
        ],

        // MEDIA section
        if (showMedia && _mediaResults.isNotEmpty) ...[
          _sectionHeader(L10n.s(ref, 'media'), Icons.photo_library_rounded),
          _buildMediaGrid(),
        ],

        // LINKS section
        if (showLinks && _linkResults.isNotEmpty) ...[
          _sectionHeader(L10n.s(ref, 'links'), Icons.link_rounded),
          ..._linkResults.map(_buildLinkTile),
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPersonTile(Map<String, dynamic> user) {
    final photoUrl = user['photoUrl'] as String? ?? '';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF1A2A40),
        backgroundImage:
            photoUrl.isNotEmpty ? CachedNetworkImageProvider(photoUrl) : null,
        child:
            photoUrl.isEmpty
                ? Text(
                  (user['name'] as String? ?? '?')[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                )
                : null,
      ),
      title: Text(
        user['name'] as String? ?? '',
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: Text(
        '@${user['username'] ?? ''}',
        style: const TextStyle(color: Colors.white54, fontSize: 13),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Colors.white24,
        size: 18,
      ),
      onTap: () {
        final uid = user['uid'] as String? ?? '';
        if (uid.isNotEmpty) {
          // Navigate to chat with this user (find or create chat)
          GoRouter.of(context).push(
            '/chat?partnerUid=$uid&partnerName=${Uri.encodeComponent(user['name'] ?? 'User')}&partnerPhoto=${Uri.encodeComponent(photoUrl)}',
          );
        }
      },
    );
  }

  Widget _buildMessageTile(Map<String, dynamic> msg) {
    final partnerPhoto = msg['partnerPhoto'] as String? ?? '';
    final partnerName = msg['partnerName'] as String? ?? 'User';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF1A2A40),
        backgroundImage:
            partnerPhoto.isNotEmpty
                ? CachedNetworkImageProvider(partnerPhoto)
                : null,
        child:
            partnerPhoto.isEmpty
                ? Text(
                  partnerName[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                )
                : null,
      ),
      title: Text(partnerName, style: const TextStyle(color: Colors.white)),
      subtitle: _HighlightedText(
        text: msg['text'] as String? ?? '',
        query: _query,
      ),
      trailing: Text(
        _timeAgo(msg['createdAt']),
        style: const TextStyle(color: Colors.white38, fontSize: 11),
      ),
      onTap: () {
        final chatId = msg['chatId'] as String? ?? '';
        final partnerUid = msg['partnerUid'] as String? ?? '';
        if (chatId.isNotEmpty && partnerUid.isNotEmpty) {
          GoRouter.of(context).push(
            '/chat?chatId=$chatId&partnerUid=$partnerUid&partnerName=${Uri.encodeComponent(partnerName)}&partnerPhoto=${Uri.encodeComponent(partnerPhoto)}',
          );
        }
      },
    );
  }

  Widget _buildMediaGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: _mediaResults.length,
        itemBuilder: (_, i) {
          final media = _mediaResults[i];
          final url = media['mediaUrl'] as String? ?? '';
          final isVideo = media['type'] == 'video';
          return GestureDetector(
            onTap: () {
              final chatId = media['chatId'] as String? ?? '';
              final partnerUid = media['partnerUid'] as String? ?? '';
              final partnerName = media['partnerName'] as String? ?? 'User';
              final partnerPhoto = media['partnerPhoto'] as String? ?? '';
              if (chatId.isNotEmpty && partnerUid.isNotEmpty) {
                GoRouter.of(context).push(
                  '/chat?chatId=$chatId&partnerUid=$partnerUid&partnerName=${Uri.encodeComponent(partnerName)}&partnerPhoto=${Uri.encodeComponent(partnerPhoto)}',
                );
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: (media['thumbnailUrl'] as String?) ?? url,
                    fit: BoxFit.cover,
                    placeholder:
                        (_, __) => Container(
                          color: AppColors.glassPanel,
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.aquaCore,
                            ),
                          ),
                        ),
                    errorWidget:
                        (_, __, ___) => Container(
                          color: AppColors.glassPanel,
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.white24,
                            size: 24,
                          ),
                        ),
                  ),
                  if (isVideo)
                    Center(
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.6),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLinkTile(Map<String, dynamic> msg) {
    final text = msg['text'] as String? ?? '';
    final url = _extractUrl(text) ?? text;
    final partnerName = msg['partnerName'] as String? ?? 'User';
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.aquaCore.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.link_rounded,
          color: AppColors.aquaCore,
          size: 20,
        ),
      ),
      title: Text(
        url,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.aquaCyan,
          fontSize: 13,
          decoration: TextDecoration.underline,
        ),
      ),
      subtitle: Text(
        'from $partnerName',
        style: const TextStyle(color: Colors.white38, fontSize: 11),
      ),
      trailing: Text(
        _timeAgo(msg['createdAt']),
        style: const TextStyle(color: Colors.white38, fontSize: 11),
      ),
      onTap: () {
        final chatId = msg['chatId'] as String? ?? '';
        final partnerUid = msg['partnerUid'] as String? ?? '';
        final partnerPhoto = msg['partnerPhoto'] as String? ?? '';
        if (chatId.isNotEmpty && partnerUid.isNotEmpty) {
          GoRouter.of(context).push(
            '/chat?chatId=$chatId&partnerUid=$partnerUid&partnerName=${Uri.encodeComponent(partnerName)}&partnerPhoto=${Uri.encodeComponent(partnerPhoto)}',
          );
        }
      },
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Icon(icon, color: AppColors.aquaCore, size: 16),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: AppColors.aquaCore,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Search functions ─────────────────────────────────

  void _performSearch(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _isSearching = true);

      await Future.wait([
        _searchPeople(query),
        _searchMessages(query),
        _searchMedia(query),
        _searchLinks(query),
      ]);

      if (mounted) setState(() => _isSearching = false);
    });
  }

  Future<void> _searchPeople(String query) async {
    try {
      final snap =
          await FirebaseFirestore.instance
              .collection('users')
              .where('name', isGreaterThanOrEqualTo: query)
              .where('name', isLessThanOrEqualTo: '$query\uf8ff')
              .limit(5)
              .get();

      final usernameSnap =
          await FirebaseFirestore.instance
              .collection('users')
              .where('username', isGreaterThanOrEqualTo: query.toLowerCase())
              .where(
                'username',
                isLessThanOrEqualTo: '${query.toLowerCase()}\uf8ff',
              )
              .limit(5)
              .get();

      // Merge + deduplicate
      final seen = <String>{};
      final all = <Map<String, dynamic>>[];
      for (final d in [...snap.docs, ...usernameSnap.docs]) {
        if (d.id == FirebaseAuth.instance.currentUser?.uid) continue;
        if (seen.add(d.id)) {
          all.add({...d.data(), 'uid': d.id});
        }
      }

      if (mounted) setState(() => _peopleResults = all);
    } catch (_) {}
  }

  Future<void> _searchMessages(String query) async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final q = query.toLowerCase();
      final results = <Map<String, dynamic>>[];

      final chatsSnap =
          await FirebaseFirestore.instance
              .collection('chats')
              .where('participants', arrayContains: uid)
              .limit(20)
              .get();

      for (final chat in chatsSnap.docs) {
        final participants = List<String>.from(
          chat.data()['participants'] ?? [],
        );
        final partnerUid = participants.firstWhere(
          (id) => id != uid,
          orElse: () => '',
        );
        if (partnerUid.isEmpty) continue;

        // Fetch partner info once per chat
        String partnerName = 'User';
        String partnerPhoto = '';
        try {
          final partnerDoc =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(partnerUid)
                  .get();
          partnerName = partnerDoc.data()?['name'] as String? ?? 'User';
          partnerPhoto = partnerDoc.data()?['photoUrl'] as String? ?? '';
        } catch (_) {}

        final msgsSnap =
            await FirebaseFirestore.instance
                .collection('chats')
                .doc(chat.id)
                .collection('messages')
                .orderBy('createdAt', descending: true)
                .limit(50)
                .get();

        for (final msg in msgsSnap.docs) {
          final text = (msg.data()['text'] as String? ?? '').toLowerCase();
          if (text.contains(q)) {
            results.add({
              ...msg.data(),
              'messageId': msg.id,
              'chatId': chat.id,
              'partnerUid': partnerUid,
              'partnerName': partnerName,
              'partnerPhoto': partnerPhoto,
            });
          }
        }
        if (results.length >= 10) break;
      }

      if (mounted) setState(() => _messageResults = results);
    } catch (_) {}
  }

  Future<void> _searchMedia(String query) async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final results = <Map<String, dynamic>>[];

      final chatsSnap =
          await FirebaseFirestore.instance
              .collection('chats')
              .where('participants', arrayContains: uid)
              .limit(20)
              .get();

      for (final chat in chatsSnap.docs) {
        final participants = List<String>.from(
          chat.data()['participants'] ?? [],
        );
        final partnerUid = participants.firstWhere(
          (id) => id != uid,
          orElse: () => '',
        );
        if (partnerUid.isEmpty) continue;

        // Fetch partner info once per chat
        String partnerName = 'User';
        String partnerPhoto = '';
        try {
          final partnerDoc =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(partnerUid)
                  .get();
          partnerName = partnerDoc.data()?['name'] as String? ?? 'User';
          partnerPhoto = partnerDoc.data()?['photoUrl'] as String? ?? '';
        } catch (_) {}

        final msgsSnap =
            await FirebaseFirestore.instance
                .collection('chats')
                .doc(chat.id)
                .collection('messages')
                .where('type', whereIn: ['image', 'video'])
                .orderBy('createdAt', descending: true)
                .limit(15)
                .get();

        for (final msg in msgsSnap.docs) {
          results.add({
            ...msg.data(),
            'messageId': msg.id,
            'chatId': chat.id,
            'partnerUid': partnerUid,
            'partnerName': partnerName,
            'partnerPhoto': partnerPhoto,
          });
        }
        if (results.length >= 20) break;
      }

      if (mounted) setState(() => _mediaResults = results);
    } catch (_) {}
  }

  Future<void> _searchLinks(String query) async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final results = <Map<String, dynamic>>[];

      final chatsSnap =
          await FirebaseFirestore.instance
              .collection('chats')
              .where('participants', arrayContains: uid)
              .limit(20)
              .get();

      for (final chat in chatsSnap.docs) {
        final participants = List<String>.from(
          chat.data()['participants'] ?? [],
        );
        final partnerUid = participants.firstWhere(
          (id) => id != uid,
          orElse: () => '',
        );
        if (partnerUid.isEmpty) continue;

        // Fetch partner info
        String partnerName = 'User';
        String partnerPhoto = '';
        try {
          final partnerDoc =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(partnerUid)
                  .get();
          partnerName = partnerDoc.data()?['name'] as String? ?? 'User';
          partnerPhoto = partnerDoc.data()?['photoUrl'] as String? ?? '';
        } catch (_) {}

        final msgsSnap =
            await FirebaseFirestore.instance
                .collection('chats')
                .doc(chat.id)
                .collection('messages')
                .where('type', isEqualTo: 'text')
                .orderBy('createdAt', descending: true)
                .limit(50)
                .get();

        for (final msg in msgsSnap.docs) {
          final text = msg.data()['text'] as String? ?? '';
          if (_containsUrl(text)) {
            results.add({
              ...msg.data(),
              'messageId': msg.id,
              'chatId': chat.id,
              'partnerUid': partnerUid,
              'partnerName': partnerName,
              'partnerPhoto': partnerPhoto,
            });
          }
        }
        if (results.length >= 15) break;
      }

      if (mounted) setState(() => _linkResults = results);
    } catch (_) {}
  }

  static final _urlRegex = RegExp(
    r'(https?:\/\/)?(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
    caseSensitive: false,
  );

  bool _containsUrl(String text) => _urlRegex.hasMatch(text);

  String? _extractUrl(String text) {
    final match = _urlRegex.firstMatch(text)?.group(0);
    if (match == null) return null;
    if (!match.startsWith('http://') && !match.startsWith('https://')) {
      return 'https://$match';
    }
    return match;
  }

  void _clearResults() {
    setState(() {
      _peopleResults = [];
      _chatResults = [];
      _messageResults = [];
      _mediaResults = [];
      _linkResults = [];
    });
  }

  String _timeAgo(dynamic ts) {
    if (ts == null) return '';
    final date = (ts as Timestamp).toDate();
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    return '${diff.inMinutes}m';
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _controller.dispose();
    super.dispose();
  }
}

// ─── Highlighted Text Widget ──────────────────────────────

class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;

  const _HighlightedText({required this.text, required this.query});

  @override
  Widget build(BuildContext context) {
    final lower = text.toLowerCase();
    final idx = lower.indexOf(query.toLowerCase());
    if (idx == -1) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white54),
      );
    }

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        children: [
          TextSpan(
            text: text.substring(0, idx),
            style: const TextStyle(color: Colors.white54),
          ),
          TextSpan(
            text: text.substring(idx, idx + query.length),
            style: TextStyle(
              color: AppColors.aquaCore,
              fontWeight: FontWeight.bold,
              backgroundColor: AppColors.aquaCore.withValues(alpha: 0.15),
            ),
          ),
          TextSpan(
            text: text.substring(idx + query.length),
            style: const TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
