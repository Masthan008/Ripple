import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Global search screen — searches people, chats, and messages.
class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  bool _isSearching = false;
  Timer? _searchDebounce;

  List<Map<String, dynamic>> _peopleResults = [];
  List<Map<String, dynamic>> _chatResults = [];
  List<Map<String, dynamic>> _messageResults = [];

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
          decoration: const InputDecoration(
            hintText: 'Search people, chats, messages...',
            hintStyle: TextStyle(color: Colors.white38),
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
      body: _query.length < 2
          ? _buildSearchSuggestions()
          : _isSearching
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.aquaCore))
              : _buildResults(),
    );
  }

  Widget _buildSearchSuggestions() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_rounded, size: 64,
              color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 16),
          const Text('Search Ripple',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Find people, chats\nand messages',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final hasAny = _peopleResults.isNotEmpty ||
        _chatResults.isNotEmpty ||
        _messageResults.isNotEmpty;

    if (!hasAny) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('😕', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text('No results for "$_query"',
                style: const TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    return ListView(
      children: [
        // PEOPLE section
        if (_peopleResults.isNotEmpty) ...[
          _sectionHeader('People'),
          ..._peopleResults.map((user) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF1A2A40),
                  child: Text(
                    (user['name'] as String? ?? '?')[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(user['name'] as String? ?? '',
                    style: const TextStyle(color: Colors.white)),
                subtitle: Text('@${user['username'] ?? ''}',
                    style: const TextStyle(color: Colors.white54, fontSize: 13)),
                onTap: () {},
              )),
        ],

        // CHATS section
        if (_chatResults.isNotEmpty) ...[
          _sectionHeader('Chats'),
          ..._chatResults.map((chat) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF1A2A40),
                  child: const Icon(Icons.chat_bubble_outline,
                      color: Colors.white54, size: 18),
                ),
                title: Text(chat['name'] as String? ?? '',
                    style: const TextStyle(color: Colors.white)),
                subtitle: Text(chat['lastMessage'] as String? ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 13)),
                onTap: () {},
              )),
        ],

        // MESSAGES section
        if (_messageResults.isNotEmpty) ...[
          _sectionHeader('Messages'),
          ..._messageResults.map((msg) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF1A2A40),
                  child: Text(
                    (msg['senderName'] as String? ?? '?')[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(msg['senderName'] as String? ?? '',
                    style: const TextStyle(color: Colors.white)),
                subtitle: _HighlightedText(
                    text: msg['text'] as String? ?? '', query: _query),
                trailing: Text(
                  _timeAgo(msg['createdAt']),
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                onTap: () {},
              )),
        ],
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title,
          style: TextStyle(
              color: AppColors.aquaCore,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5)),
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
        _searchChats(query),
        _searchMessages(query),
      ]);

      if (mounted) setState(() => _isSearching = false);
    });
  }

  Future<void> _searchPeople(String query) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(5)
          .get();

      final usernameSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('username',
              isGreaterThanOrEqualTo: query.toLowerCase())
          .where('username',
              isLessThanOrEqualTo: '${query.toLowerCase()}\uf8ff')
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

  Future<void> _searchChats(String query) async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final snap = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: uid)
          .limit(50)
          .get();

      final q = query.toLowerCase();
      final results = snap.docs
          .map((d) => {...d.data(), 'chatId': d.id})
          .where((chat) {
        final name = (chat['name'] as String? ?? '').toLowerCase();
        final lastMsg =
            (chat['lastMessage'] as String? ?? '').toLowerCase();
        return name.contains(q) || lastMsg.contains(q);
      }).toList();

      if (mounted) setState(() => _chatResults = results);
    } catch (_) {}
  }

  Future<void> _searchMessages(String query) async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final q = query.toLowerCase();
      final results = <Map<String, dynamic>>[];

      final chatsSnap = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: uid)
          .limit(20)
          .get();

      for (final chat in chatsSnap.docs) {
        final msgsSnap = await FirebaseFirestore.instance
            .collection('chats')
            .doc(chat.id)
            .collection('messages')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .get();

        for (final msg in msgsSnap.docs) {
          final text =
              (msg.data()['text'] as String? ?? '').toLowerCase();
          if (text.contains(q)) {
            results.add({
              ...msg.data(),
              'messageId': msg.id,
              'chatId': chat.id,
            });
          }
        }
        if (results.length >= 10) break;
      }

      if (mounted) setState(() => _messageResults = results);
    } catch (_) {}
  }

  void _clearResults() {
    setState(() {
      _peopleResults = [];
      _chatResults = [];
      _messageResults = [];
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
      return Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white54));
    }

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(children: [
        TextSpan(
            text: text.substring(0, idx),
            style: const TextStyle(color: Colors.white54)),
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
            style: const TextStyle(color: Colors.white54)),
      ]),
    );
  }
}
