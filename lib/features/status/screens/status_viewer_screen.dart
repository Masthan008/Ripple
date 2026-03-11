import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../core/constants/app_colors.dart';
import '../models/mood_config.dart';
import '../models/status_model.dart';
import '../services/status_service.dart';

/// Fullscreen status viewer — Instagram/WhatsApp style with progress bars,
/// tap navigation, long-press pause, reaction bar, and viewers list.
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

  static const _photoDuration = Duration(seconds: 5);
  static const _textDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _progressController = AnimationController(vsync: this);
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
      if (!_isPaused && mounted) _nextStatus();
    });
  }

  void _nextStatus() {
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
    _isPaused = false;
    _progressController.forward();
    _videoController?.play();
  }

  @override
  Widget build(BuildContext context) {
    final currentStatus = widget.statuses[_currentIndex];
    final isMyStatus =
        currentStatus.uid == FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.black,
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

          // ── Tap areas — left/right navigation ─────────
          Row(
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

                // Header — avatar + name + time
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF1A2A40),
                        backgroundImage: currentStatus
                                .ownerPhoto.isNotEmpty
                            ? CachedNetworkImageProvider(
                                currentStatus.ownerPhoto)
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
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom bar — reactions or viewers ──────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: isMyStatus
                  ? _buildViewersBar(currentStatus)
                  : _buildReactionBar(currentStatus),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionBar(StatusModel status) {
    const emojis = ['❤️', '😂', '😮', '😢', '🔥', '👏'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: emojis
          .map((emoji) => GestureDetector(
                onTap: () async {
                  await StatusService.reactToStatus(
                    statusId: status.statusId,
                    emoji: emoji,
                  );
                  HapticFeedback.lightImpact();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Reacted with $emoji'),
                        duration: const Duration(seconds: 1),
                        backgroundColor: const Color(0xFF1A2A40),
                      ),
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(emoji, style: const TextStyle(fontSize: 28)),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildViewersBar(StatusModel status) {
    return Row(
      children: [
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
                final reaction = status.reactions[v['uid']] as String?;
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
                      ? Text(reaction,
                          style: const TextStyle(fontSize: 20))
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
    final emoji = MoodConfig.getEmoji(mood);
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
            Text(emoji, style: const TextStyle(fontSize: 80)),
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
