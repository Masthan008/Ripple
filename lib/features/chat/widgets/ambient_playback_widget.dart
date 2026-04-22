import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/constants/app_colors.dart';

/// Ambient Playback Widget — Ambient Sonic Footprints™
///
/// A tiny, invisible-by-default widget embedded in each message bubble
/// that has an ambient audio URL. When the message scrolls into view,
/// it fades in the ambient audio at very low volume (0.08) for a
/// subtle, immersive effect.
///
/// Shows a tiny 🎧 indicator when audio is available.
class AmbientPlaybackWidget extends StatefulWidget {
  final String? ambientAudioUrl;
  final bool isVisible; // driven by scroll visibility

  const AmbientPlaybackWidget({
    super.key,
    this.ambientAudioUrl,
    this.isVisible = true,
  });

  @override
  State<AmbientPlaybackWidget> createState() => _AmbientPlaybackWidgetState();
}

class _AmbientPlaybackWidgetState extends State<AmbientPlaybackWidget> {
  AudioPlayer? _player;
  bool _isPlaying = false;
  bool _hasPlayed = false;

  @override
  void initState() {
    super.initState();
    if (widget.ambientAudioUrl != null) {
      _initPlayer();
    }
  }

  Future<void> _initPlayer() async {
    try {
      _player = AudioPlayer();
      await _player!.setUrl(widget.ambientAudioUrl!);
      _player!.setVolume(0.08); // Very subtle
      _player!.setLoopMode(LoopMode.one); // Loop the 2-second clip
    } catch (e) {
      debugPrint('🎧 Ambient playback init error: $e');
    }
  }

  @override
  void didUpdateWidget(AmbientPlaybackWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isVisible && !_hasPlayed && _player != null) {
      _startPlayback();
    } else if (!widget.isVisible && _isPlaying) {
      _stopPlayback();
    }
  }

  Future<void> _startPlayback() async {
    if (_isPlaying || _player == null) return;
    try {
      // Fade in
      _player!.setVolume(0.0);
      _player!.play();

      // Gradual volume increase over 500ms
      for (int i = 1; i <= 8; i++) {
        await Future.delayed(const Duration(milliseconds: 60));
        _player!.setVolume(i * 0.01);
      }

      setState(() {
        _isPlaying = true;
        _hasPlayed = true;
      });

      // Auto-stop after 6 seconds (3 loops)
      Future.delayed(const Duration(seconds: 6), () {
        if (mounted) _fadeOut();
      });
    } catch (e) {
      debugPrint('🎧 Ambient playback error: $e');
    }
  }

  Future<void> _fadeOut() async {
    if (_player == null) return;
    try {
      // Fade out over 500ms
      for (int i = 8; i >= 0; i--) {
        await Future.delayed(const Duration(milliseconds: 60));
        if (_player != null) {
          _player!.setVolume(i * 0.01);
        }
      }
      _stopPlayback();
    } catch (_) {}
  }

  void _stopPlayback() {
    _player?.pause();
    if (mounted) {
      setState(() => _isPlaying = false);
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ambientAudioUrl == null) return const SizedBox.shrink();

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 500),
      opacity: _isPlaying ? 1.0 : 0.5,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.aquaCore.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isPlaying
                  ? Icons.graphic_eq_rounded
                  : Icons.headphones_rounded,
              size: 10,
              color: AppColors.aquaCore.withOpacity(0.5),
            ),
            const SizedBox(width: 2),
            if (_isPlaying)
              Text(
                'ambient',
                style: TextStyle(
                  fontSize: 8,
                  color: AppColors.aquaCore.withOpacity(0.4),
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
