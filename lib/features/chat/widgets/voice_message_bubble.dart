import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/constants/app_colors.dart';

/// Voice message bubble with play/pause, waveform progress, and duration display
class VoiceMessageBubble extends StatefulWidget {
  final String audioUrl;
  final int durationSeconds;
  final List<double> waveformData;
  final bool isMyMessage;

  const VoiceMessageBubble({
    super.key,
    required this.audioUrl,
    required this.durationSeconds,
    required this.waveformData,
    required this.isMyMessage,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  final _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  late Duration _total;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _total = Duration(seconds: widget.durationSeconds);

    _player.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });

    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          if (state.processingState == ProcessingState.completed) {
            _isPlaying = false;
            _position = Duration.zero;
            _player.seek(Duration.zero);
            _player.pause();
          }
        });
      }
    });
  }

  Future<void> _togglePlay() async {
    try {
      if (_isPlaying) {
        await _player.pause();
      } else {
        if (_player.audioSource == null) {
          await _player.setUrl(widget.audioUrl);
        }
        await _player.play();
      }
    } catch (e) {
      debugPrint('⚠️ Audio playback error: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress =
        _total.inSeconds > 0 ? _position.inSeconds / _total.inSeconds : 0.0;

    final contentColor =
        widget.isMyMessage ? Colors.white : AppColors.aquaCore;

    return SizedBox(
      width: 240,
      child: Row(
        children: [
          // Play/pause button
          GestureDetector(
            onTap: _hasError ? null : _togglePlay,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: contentColor,
              ),
              child: Icon(
                _hasError
                    ? Icons.error_outline_rounded
                    : _isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                color: widget.isMyMessage
                    ? AppColors.aquaCore
                    : Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Waveform + progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Waveform with progress overlay
                SizedBox(
                  height: 32,
                  child: CustomPaint(
                    painter: _PlaybackWaveformPainter(
                      amplitudes: widget.waveformData,
                      progress: progress,
                      activeColor: contentColor,
                      inactiveColor: contentColor.withValues(alpha: 0.3),
                    ),
                    size: const Size(double.infinity, 32),
                  ),
                ),
                const SizedBox(height: 4),

                // Duration
                Text(
                  _isPlaying || _position.inSeconds > 0
                      ? _formatDuration(_position)
                      : _formatDuration(_total),
                  style: TextStyle(
                    color: contentColor.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Playback waveform painter — shows progress through the audio
class _PlaybackWaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  _PlaybackWaveformPainter({
    required this.amplitudes,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty) {
      // Draw placeholder bars if no waveform data
      for (int i = 0; i < 30; i++) {
        final x = i * (size.width / 30);
        final h =
            (i % 3 == 0 ? 0.8 : i % 2 == 0 ? 0.5 : 0.3) * size.height;
        _drawBar(canvas, x, h, size.height,
            i / 30 < progress ? activeColor : inactiveColor);
      }
      return;
    }

    final barWidth = size.width / amplitudes.length;
    for (int i = 0; i < amplitudes.length; i++) {
      final x = i * barWidth;
      final h = (amplitudes[i] * size.height).clamp(2.0, size.height);
      _drawBar(canvas, x, h, size.height,
          i / amplitudes.length < progress ? activeColor : inactiveColor);
    }
  }

  void _drawBar(
      Canvas canvas, double x, double h, double totalH, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final y = (totalH - h) / 2;
    canvas.drawLine(Offset(x, y), Offset(x, y + h), paint);
  }

  @override
  bool shouldRepaint(_PlaybackWaveformPainter old) => old.progress != progress;
}
