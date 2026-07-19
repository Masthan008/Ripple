import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/reaction_icons.dart';
import '../models/mood_config.dart';
import '../models/status_comment_model.dart';
import '../models/status_model.dart';
import '../services/status_service.dart';

/// Fullscreen status viewer — Instagram/WhatsApp style with progress bars,
/// tap navigation, long-press pause, interactive reply bar, comments sheet,
/// status forwarding/sharing, and viewers list.
class StatusViewerScreen extends StatefulWidget {
  final List<StatusModel> statuses;
  final int initialIndex;
  final String viewerName;

  const StatusViewerScreen({
    super.key,
    required this.statuses,
    this.initialIndex = 0,
    required this.viewerName,
  });

  @override
  State<StatusViewerScreen> createState() => _StatusViewerScreenState();
}

class _StatusViewerScreenState extends State<StatusViewerScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _progressController;
  late int _currentIndex;
  VideoPlayerController? _videoController;
  bool _isPaused = false;
  bool _showQuickEmojis = false;

  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();

  static const _photoDuration = Duration(seconds: 5);
  static const _textDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _progressController = AnimationController(vsync: this);

    _replyFocusNode.addListener(() {
      if (_replyFocusNode.hasFocus) {
        _pause();
      } else if (_replyController.text.isEmpty) {
        _resume();
      }
    });

    _showStatus(_currentIndex);
  }

  Future<void> _showStatus(int index) async {
    if (index < 0 || index >= widget.statuses.length) return;

    final status = widget.statuses[index];

    // Mark as viewed (non-blocking)
    StatusService.markViewed(
      statusId: status.statusId,
      viewerName: widget.viewerName,
    );

    // Dispose previous video controller
    _videoController?.dispose();
    _videoController = null;

    // Set duration based on type
    Duration duration;
    if (status.type == 'video' && status.mediaUrl != null) {
      try {
        _videoController =
            VideoPlayerController.networkUrl(Uri.parse(status.mediaUrl!));
        await _videoController!.initialize();
        duration = _videoController!.value.duration;
        _videoController!.play();
      } catch (_) {
        duration = _photoDuration;
      }
    } else {
      duration = status.type == 'text' ? _textDuration : _photoDuration;
    }

    if (!mounted) return;
    setState(() {});

    _progressController.reset();
    _progressController.duration = duration;
    _progressController.forward().then((_) {
      if (!_isPaused && mounted && !_replyFocusNode.hasFocus) _nextStatus();
    });
  }

  void _nextStatus() {
    if (_replyFocusNode.hasFocus) {
      _replyFocusNode.unfocus();
    }
    if (_currentIndex < widget.statuses.length - 1) {
      setState(() => _currentIndex++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _showStatus(_currentIndex);
    } else {
      Navigator.pop(context);
    }
  }

  void _previousStatus() {
    if (_replyFocusNode.hasFocus) {
      _replyFocusNode.unfocus();
    }
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _showStatus(_currentIndex);
    }
  }

  void _pause() {
    _isPaused = true;
    _progressController.stop();
    _videoController?.pause();
  }

  void _resume() {
    if (_replyFocusNode.hasFocus) return;
    _isPaused = false;
    _progressController.forward();
    _videoController?.play();
  }

  Future<void> _sendReply(StatusModel status) async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    _replyController.clear();
    _replyFocusNode.unfocus();
    HapticFeedback.lightImpact();

    await StatusService.addComment(
      statusId: status.statusId,
      text: text,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reply sent! 💬'),
          duration: Duration(seconds: 2),
          backgroundColor: AppColors.aquaCore,
        ),
      );
    }
    _resume();
  }

  @override
  Widget build(BuildContext context) {
    final currentStatus = widget.statuses[_currentIndex];
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isMyStatus = currentStatus.uid == myUid;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── Status content (PageView) ──────────────────
          PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.statuses.length,
            itemBuilder: (_, i) =>
                _StatusContent(status: widget.statuses[i], videoController: i == _currentIndex ? _videoController : null),
          ),

          // ── Gesture detector for Tap + Swipe Up ───────
          GestureDetector(
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null && details.primaryVelocity! < -300) {
                // Swipe up gesture -> open comments
                _showCommentsSheet(currentStatus);
              }
            },
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _previousStatus,
                    onLongPressStart: (_) => _pause(),
                    onLongPressEnd: (_) => _resume(),
                    child: Container(color: Colors.transparent),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: _nextStatus,
                    onLongPressStart: (_) => _pause(),
                    onLongPressEnd: (_) => _resume(),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ],
            ),
          ),

          // ── Top UI — progress bars + header ────────────
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress bars
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: List.generate(
                      widget.statuses.length,
                      (i) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: i < _currentIndex
                              ? const LinearProgressIndicator(
                                  value: 1.0,
                                  backgroundColor: Colors.white30,
                                  valueColor: AlwaysStoppedAnimation(
                                      Colors.white),
                                  minHeight: 2,
                                )
                              : i == _currentIndex
                                  ? AnimatedBuilder(
                                      animation: _progressController,
                                      builder: (_, __) =>
                                          LinearProgressIndicator(
                                        value: _progressController.value,
                                        backgroundColor: Colors.white30,
                                        valueColor:
                                            const AlwaysStoppedAnimation(
                                                Colors.white),
                                        minHeight: 2,
                                      ),
                                    )
                                  : const LinearProgressIndicator(
                                      value: 0.0,
                                      backgroundColor: Colors.white30,
                                      valueColor: AlwaysStoppedAnimation(
                                          Colors.white),
                                      minHeight: 2,
                                    ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Header — avatar + name + time + action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF1A2A40),
                        backgroundImage: currentStatus.ownerPhoto.isNotEmpty
                            ? CachedNetworkImageProvider(currentStatus.ownerPhoto)
                            : null,
                        child: currentStatus.ownerPhoto.isEmpty
                            ? Text(
                                currentStatus.ownerName.isNotEmpty
                                    ? currentStatus.ownerName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(color: Colors.white),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isMyStatus ? 'My Status' : currentStatus.ownerName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              _timeAgo(currentStatus.createdAt),
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send_rounded, color: Colors.white),
                        tooltip: 'Share Status',
                        onPressed: () => _showShareSheet(currentStatus),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom bar — reply field or viewers bar ───
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.of(context).padding.bottom + 12,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: isMyStatus
                  ? _buildViewersBar(currentStatus)
                  : _buildInteractiveReplyBar(currentStatus),
            ),
          ),
        ],
      ),
    );
  }

  // ── Interactive Reply Bar for Viewers ────────────────────
  Widget _buildInteractiveReplyBar(StatusModel status) {
    const reactions = ['favorite', 'laugh', 'wow', 'cry', 'fire', 'clap'];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Swipe Up hint indicator
        GestureDetector(
          onTap: () => _showCommentsSheet(status),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  status.commentCount > 0
                      ? '${status.commentCount} comments · Swipe up to reply'
                      : 'Swipe up to reply',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Quick Emoji Reaction Bar (collapsible / expandable)
        if (_showQuickEmojis)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1628).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: reactions
                  .map(
                    (r) => GestureDetector(
                      onTap: () async {
                        await StatusService.reactToStatus(
                          statusId: status.statusId,
                          emoji: r,
                        );
                        setState(() => _showQuickEmojis = false);
                        HapticFeedback.lightImpact();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Reacted with '),
                                  ReactionIcons.getIcon(r, size: 16),
                                ],
                              ),
                              duration: const Duration(seconds: 1),
                              backgroundColor: const Color(0xFF1A2A40),
                            ),
                          );
                        }
                      },
                      child: ReactionIcons.getIcon(r, size: 28),
                    ),
                  )
                  .toList(),
            ),
          ),

        // Text input field + emoji button + comments sheet button + send
        Row(
          children: [
            // Emoji toggle button
            IconButton(
              icon: Icon(
                _showQuickEmojis
                    ? Icons.keyboard_hide_rounded
                    : Icons.add_reaction_outlined,
                color: Colors.white,
                size: 24,
              ),
              onPressed: () {
                setState(() => _showQuickEmojis = !_showQuickEmojis);
              },
            ),

            // Main reply text field
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white24),
                ),
                child: TextField(
                  controller: _replyController,
                  focusNode: _replyFocusNode,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Send message...',
                    hintStyle: TextStyle(color: Colors.white54, fontSize: 14),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _sendReply(status),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Comments Sheet Button (shows badge if > 0)
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline_rounded,
                      color: Colors.white, size: 22),
                  onPressed: () => _showCommentsSheet(status),
                ),
                if (status.commentCount > 0)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.aquaCore,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${status.commentCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Send Button
            IconButton(
              icon: const Icon(Icons.send_rounded,
                  color: AppColors.aquaCore, size: 24),
              onPressed: () => _sendReply(status),
            ),
          ],
        ),
      ],
    );
  }

  // ── Viewers Bar for Status Owner ────────────────────────
  Widget _buildViewersBar(StatusModel status) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => _showCommentsSheet(status),
          child: Row(
            children: [
              const Icon(Icons.chat_bubble_outline_rounded,
                  color: Colors.white70, size: 20),
              const SizedBox(width: 6),
              Text(
                '${status.commentCount}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => _showViewersList(status),
          child: Row(
            children: [
              const Icon(Icons.visibility_rounded,
                  color: Colors.white70, size: 20),
              const SizedBox(width: 6),
              Text(
                '${status.viewers.length}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.white70),
          onPressed: () async {
            await StatusService.deleteStatus(status.statusId);
            if (mounted) Navigator.pop(context);
          },
        ),
      ],
    );
  }

  // ── Bottom Sheet for Status Comments / Replies ────────────
  void _showCommentsSheet(StatusModel status) {
    _pause();
    final sheetTextCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A1628),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final isOwner = status.uid == myUid;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            height: MediaQuery.of(ctx).size.height * 0.65,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Row(
                  children: [
                    const Icon(Icons.chat_bubble_rounded,
                        color: AppColors.aquaCore, size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'Status Replies',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(color: Colors.white12),

                // Stream of Comments
                Expanded(
                  child: StreamBuilder<List<StatusCommentModel>>(
                    stream: StatusService.getComments(status.statusId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.aquaCore,
                            strokeWidth: 2,
                          ),
                        );
                      }
                      final comments = snapshot.data ?? [];
                      if (comments.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: Colors.white24,
                                size: 48,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'No replies yet. Be the first to reply!',
                                style: TextStyle(color: Colors.white38),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: comments.length,
                        itemBuilder: (context, i) {
                          final c = comments[i];
                          final canDelete = isOwner || c.uid == myUid;

                          return ListTile(
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFF1A2A40),
                              backgroundImage: c.photoUrl.isNotEmpty
                                  ? CachedNetworkImageProvider(c.photoUrl)
                                  : null,
                              child: c.photoUrl.isEmpty
                                  ? Text(
                                      c.name.isNotEmpty
                                          ? c.name[0].toUpperCase()
                                          : '?',
                                      style:
                                          const TextStyle(color: Colors.white),
                                    )
                                  : null,
                            ),
                            title: Text(
                              c.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              c.text,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _timeAgo(c.createdAt),
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 11),
                                ),
                                if (canDelete)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.white38,
                                      size: 18,
                                    ),
                                    onPressed: () async {
                                      await StatusService.deleteComment(
                                        statusId: status.statusId,
                                        commentId: c.commentId,
                                      );
                                    },
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // Reply Input Field inside Sheet
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: TextField(
                            controller: sheetTextCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Write a reply...',
                              hintStyle: TextStyle(color: Colors.white38),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send_rounded,
                            color: AppColors.aquaCore),
                        onPressed: () async {
                          final text = sheetTextCtrl.text.trim();
                          if (text.isEmpty) return;
                          sheetTextCtrl.clear();
                          await StatusService.addComment(
                            statusId: status.statusId,
                            text: text,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) => _resume());
  }

  // ── Share / Forward Status Modal Sheet ───────────────────
  void _showShareSheet(StatusModel status) {
    _pause();
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final selectedUids = <String>{};

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A1628),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(myUid)
                  .snapshots(),
              builder: (context, snapshot) {
                final userData =
                    snapshot.data?.data() as Map<String, dynamic>? ?? {};
                final friendsUids =
                    List<String>.from(userData['friends'] as List? ?? []);

                return Container(
                  height: MediaQuery.of(context).size.height * 0.6,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 4, bottom: 12),
                        alignment: Alignment.center,
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.send_rounded,
                              color: AppColors.aquaCore, size: 22),
                          const SizedBox(width: 8),
                          const Text(
                            'Forward Status to...',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: selectedUids.isEmpty
                                ? null
                                : () async {
                                    Navigator.pop(ctx);
                                    await StatusService.shareStatusToChat(
                                      status: status,
                                      recipientUids: selectedUids.toList(),
                                    );
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Status forwarded to ${selectedUids.length} chat(s)!',
                                          ),
                                          backgroundColor: AppColors.aquaCore,
                                        ),
                                      );
                                    }
                                  },
                            child: const Text('Send',
                                style: TextStyle(
                                    color: AppColors.aquaCore,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white12),
                      if (friendsUids.isEmpty)
                        const Expanded(
                          child: Center(
                            child: Text('No friends found to forward to.',
                                style: TextStyle(color: Colors.white38)),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            itemCount: friendsUids.length,
                            itemBuilder: (context, i) {
                              final uid = friendsUids[i];
                              return FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(uid)
                                    .get(),
                                builder: (context, friendSnap) {
                                  if (!friendSnap.hasData) {
                                    return const SizedBox.shrink();
                                  }
                                  final data = friendSnap.data?.data()
                                          as Map<String, dynamic>? ??
                                      {};
                                  final name = data['name'] as String? ?? 'User';
                                  final photo = data['photoUrl'] as String? ?? '';
                                  final isSelected = selectedUids.contains(uid);

                                  return CheckboxListTile(
                                    activeColor: AppColors.aquaCore,
                                    value: isSelected,
                                    onChanged: (val) {
                                      setSheetState(() {
                                        if (val == true) {
                                          selectedUids.add(uid);
                                        } else {
                                          selectedUids.remove(uid);
                                        }
                                      });
                                    },
                                    secondary: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: const Color(0xFF1A2A40),
                                      backgroundImage: photo.isNotEmpty
                                          ? CachedNetworkImageProvider(photo)
                                          : null,
                                      child: photo.isEmpty
                                          ? Text(
                                              name.isNotEmpty
                                                  ? name[0].toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                  color: Colors.white),
                                            )
                                          : null,
                                    ),
                                    title: Text(name,
                                        style: const TextStyle(
                                            color: Colors.white)),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    ).then((_) => _resume());
  }

  void _showViewersList(StatusModel status) {
    _pause();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A1628),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        final viewers = status.viewers;
        return Column(
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.visibility_rounded,
                      color: Colors.white54, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Viewed by ${viewers.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            if (viewers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text('No viewers yet',
                    style: TextStyle(color: Colors.white38)),
              )
            else
              ...viewers.map((v) {
                final reaction = status.reactions[v['uid']];
                final viewedAt = v['viewedAt'] as Timestamp?;
                return ListTile(
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF1A2A40),
                    child: Text(
                      (v['name'] as String? ?? '?')[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    v['name'] as String? ?? 'Unknown',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  subtitle: viewedAt != null
                      ? Text(
                          _timeAgo(viewedAt),
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12),
                        )
                      : null,
                  trailing: reaction != null
                      ? ReactionIcons.getIcon(reaction, size: 20)
                      : null,
                );
              }),
            const SizedBox(height: 16),
          ],
        );
      },
    ).then((_) => _resume());
  }

  String _timeAgo(Timestamp ts) {
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  @override
  void dispose() {
    _replyController.dispose();
    _replyFocusNode.dispose();
    _progressController.dispose();
    _pageController.dispose();
    _videoController?.dispose();
    super.dispose();
  }
}

// ─── Status Content Widget ──────────────────────────────────

class _StatusContent extends StatelessWidget {
  final StatusModel status;
  final VideoPlayerController? videoController;

  const _StatusContent({required this.status, this.videoController});

  @override
  Widget build(BuildContext context) {
    switch (status.type) {
      case 'photo':
        return status.mediaUrl != null
            ? CachedNetworkImage(
                imageUrl: status.mediaUrl!,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.aquaCore, strokeWidth: 2),
                ),
              )
            : Container(color: Colors.black);

      case 'video':
        if (videoController != null && videoController!.value.isInitialized) {
          return Center(
            child: AspectRatio(
              aspectRatio: videoController!.value.aspectRatio,
              child: VideoPlayer(videoController!),
            ),
          );
        }
        return const Center(
          child: CircularProgressIndicator(
              color: AppColors.aquaCore, strokeWidth: 2),
        );

      case 'text':
        return _TextStatusContent(
          text: status.text ?? '',
          gradientColors: status.gradientColors ?? ['0EA5E9', '6366F1'],
        );

      case 'mood':
        return _MoodStatusContent(
          mood: status.mood ?? 'vibing',
          text: status.text,
        );

      default:
        return Container(color: Colors.black);
    }
  }
}

class _TextStatusContent extends StatelessWidget {
  final String text;
  final List<String> gradientColors;

  const _TextStatusContent({
    required this.text,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors
              .map((c) => Color(int.parse('FF$c', radix: 16)))
              .toList(),
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: text.length > 100 ? 20 : 28,
              fontWeight: FontWeight.bold,
              shadows: const [
                Shadow(blurRadius: 8, color: Colors.black45),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoodStatusContent extends StatelessWidget {
  final String mood;
  final String? text;

  const _MoodStatusContent({required this.mood, this.text});

  @override
  Widget build(BuildContext context) {
    final colors = MoodConfig.getColors(mood);
    final iconData = MoodConfig.getIcon(mood);
    final label = MoodConfig.getLabel(mood);

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [
            colors[0].withValues(alpha: 0.3),
            colors[1].withValues(alpha: 0.1),
            const Color(0xFF060D1A),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconData, size: 80, color: colors[0]),
            const SizedBox(height: 16),
            Text(
              label,
              style: TextStyle(
                color: colors[0],
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (text != null && text!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  text!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
