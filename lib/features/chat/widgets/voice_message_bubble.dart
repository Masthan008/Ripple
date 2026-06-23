import 'dart:io';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/steganography_service.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/bio_acoustic_waveform.dart';

/// Voice message bubble with play/pause, waveform progress, and duration display
class VoiceMessageBubble extends ConsumerStatefulWidget {
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
  ConsumerState<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends ConsumerState<VoiceMessageBubble> {
  final _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  late Duration _total;
  bool _hasError = false;

  // Transcription states
  bool _isTranscribing = false;
  String? _transcript;
  String? _transcribeError;

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
        AppHaptics.lightTap();
        await _player.pause();
      } else {
        AppHaptics.mediumTap();
        if (_player.audioSource == null) {
          String playUrl = widget.audioUrl;
          if (widget.audioUrl.toLowerCase().contains('.wav') || widget.audioUrl.toLowerCase().contains('/raw')) {
            try {
              final tempDir = await getTemporaryDirectory();
              final localStegoPath = '${tempDir.path}/stego_${DateTime.now().millisecondsSinceEpoch}.wav';
              
              // Download stego file
              await Dio().download(widget.audioUrl, localStegoPath);
              final stegoBytes = await File(localStegoPath).readAsBytes();
              
              // Attempt to decode stego payload
              final decodedPayload = await SteganographyService.decode(stegoWavBytes: stegoBytes);
              if (decodedPayload != null && decodedPayload.isNotEmpty) {
                final decodedBytes = base64.decode(decodedPayload);
                final decodedFile = File('${tempDir.path}/decoded_voice_${DateTime.now().millisecondsSinceEpoch}.m4a');
                await decodedFile.writeAsBytes(decodedBytes);
                playUrl = decodedFile.path;
              }
              
              // Clean up stego WAV file
              final f = File(localStegoPath);
              if (await f.exists()) await f.delete();
            } catch (e) {
              debugPrint('⚠️ Steganography playback decoding error: $e');
            }
          }
          
          if (playUrl.startsWith('http')) {
            await _player.setUrl(playUrl);
          } else {
            await _player.setFilePath(playUrl);
          }
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

  Future<void> _transcribe() async {
    if (_transcript != null) return;
    AppHaptics.lightTap();
    setState(() {
      _isTranscribing = true;
      _transcribeError = null;
    });

    try {
      // 1. Download file temporarily
      final dir = await getTemporaryDirectory();
      final targetPath =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await Dio().download(widget.audioUrl, targetPath);

      // 2. Transcribe via Whisper
      final text = await AiService.transcribeAudio(targetPath);

      if (mounted) {
        setState(() {
          _transcript = text;
          _isTranscribing = false;
        });
        AppHaptics.success();
      }

      // Cleanup
      final file = File(targetPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTranscribing = false;
          _transcribeError = L10n.s(ref, 'transcribeFailed');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress =
        _total.inSeconds > 0 ? _position.inSeconds / _total.inSeconds : 0.0;

    final contentColor = widget.isMyMessage ? Colors.white : AppColors.aquaCore;

    final audioRow = SizedBox(
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
                color: widget.isMyMessage ? AppColors.aquaCore : Colors.white,
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
                // Bio-Acoustic Waveform™ with pitch-mapped colors
                BioAcousticWaveform(
                  waveformData: widget.waveformData,
                  progress: progress,
                  isPlaying: _isPlaying,
                  baseColor: contentColor,
                  height: 36,
                  width: 180,
                ),
                const SizedBox(height: 4),

                // Duration & Transcribe button row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isPlaying || _position.inSeconds > 0
                          ? _formatDuration(_position)
                          : _formatDuration(_total),
                      style: TextStyle(
                        color: contentColor.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                    if (_transcript == null)
                      GestureDetector(
                        onTap: _isTranscribing ? null : _transcribe,
                        child: Row(
                          children: [
                            if (_isTranscribing)
                              SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: contentColor.withValues(alpha: 0.7),
                                ),
                              )
                            else
                              Icon(
                                Icons.auto_awesome,
                                size: 12,
                                color: contentColor.withValues(alpha: 0.7),
                              ),
                            const SizedBox(width: 4),
                            Text(
                              _isTranscribing
                                  ? L10n.s(ref, 'transcribing')
                                  : L10n.s(ref, 'transcribe'),
                              style: TextStyle(
                                color: contentColor.withValues(alpha: 0.7),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (_transcript != null || _transcribeError != null) {
      return Column(
        crossAxisAlignment:
            widget.isMyMessage
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
        children: [
          audioRow,
          const SizedBox(height: 8),

          // Transcript Display
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  widget.isMyMessage
                      ? Colors.white.withValues(alpha: 0.1)
                      : AppColors.aquaCore.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _transcribeError != null
                      ? Icons.error_outline
                      : Icons.format_quote_rounded,
                  size: 16,
                  color:
                      _transcribeError != null
                          ? AppColors.errorRed
                          : contentColor.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _transcribeError ?? _transcript!,
                    style: TextStyle(
                      color:
                          _transcribeError != null
                              ? AppColors.errorRed
                              : contentColor.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return audioRow;
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
            (i % 3 == 0
                ? 0.8
                : i % 2 == 0
                ? 0.5
                : 0.3) *
            size.height;
        _drawBar(
          canvas,
          x,
          h,
          size.height,
          i / 30 < progress ? activeColor : inactiveColor,
        );
      }
      return;
    }

    final barWidth = size.width / amplitudes.length;
    for (int i = 0; i < amplitudes.length; i++) {
      final x = i * barWidth;
      final h = (amplitudes[i] * size.height).clamp(2.0, size.height);
      _drawBar(
        canvas,
        x,
        h,
        size.height,
        i / amplitudes.length < progress ? activeColor : inactiveColor,
      );
    }
  }

  void _drawBar(Canvas canvas, double x, double h, double totalH, Color color) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
    // Add glowing shadow to active bars
    if (color == activeColor) {
      canvas.drawRect(
        Rect.fromLTWH(x - 1, (totalH - h) / 2, 4, h),
        Paint()
          ..color = activeColor.withOpacity(0.1)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
    final y = (totalH - h) / 2;
    canvas.drawLine(Offset(x, y), Offset(x, y + h), paint);
  }

  @override
  bool shouldRepaint(_PlaybackWaveformPainter old) => old.progress != progress;
}
