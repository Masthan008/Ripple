import 'dart:async';
import 'package:flutter/material.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/ai_service.dart';

/// Sonic Whispers™ — Context-Aware Voice Notes
/// Automatically detects the receiver's ambient noise level and adapts:
/// - Loud environment → Shows large transcription text prominently
/// - Quiet environment → Hides transcription, plays at softer intimate volume
/// Also provides on-demand transcription toggle.

class SonicWhisperOverlay extends StatefulWidget {
  final String audioUrl;
  final bool isMe;
  final Widget child; // The existing voice bubble widget

  const SonicWhisperOverlay({
    super.key,
    required this.audioUrl,
    required this.isMe,
    required this.child,
  });

  @override
  State<SonicWhisperOverlay> createState() => _SonicWhisperOverlayState();
}

class _SonicWhisperOverlayState extends State<SonicWhisperOverlay> {
  String? _transcription;
  bool _isTranscribing = false;
  bool _showTranscription = false;
  bool _isLoudEnvironment = false;
  bool _hasCheckedNoise = false;
  double _ambientDecibels = 0;
  StreamSubscription? _noiseSub;

  @override
  void initState() {
    super.initState();
    if (!widget.isMe) {
      _checkAmbientNoise();
    }
  }

  @override
  void dispose() {
    _noiseSub?.cancel();
    super.dispose();
  }

  Future<void> _checkAmbientNoise() async {
    try {
      final status = await Permission.microphone.status;
      if (!status.isGranted) {
        // If no mic permission, default to showing transcription
        setState(() {
          _isLoudEnvironment = true;
          _hasCheckedNoise = true;
        });
        _transcribe();
        return;
      }

      final noiseMeter = NoiseMeter();
      int sampleCount = 0;
      double totalDb = 0;

      _noiseSub = noiseMeter.noise.listen((NoiseReading reading) {
        totalDb += reading.meanDecibel;
        sampleCount++;

        // Sample for 2 seconds then decide
        if (sampleCount >= 20) {
          _noiseSub?.cancel();
          final avgDb = totalDb / sampleCount;
          if (mounted) {
            setState(() {
              _ambientDecibels = avgDb;
              _isLoudEnvironment = avgDb > 60; // >60dB = loud
              _hasCheckedNoise = true;
            });

            // Auto-transcribe in loud environments
            if (_isLoudEnvironment) {
              _transcribe();
            }
          }
        }
      });

      // Timeout after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (!_hasCheckedNoise && mounted) {
          _noiseSub?.cancel();
          setState(() {
            _hasCheckedNoise = true;
            _isLoudEnvironment = false;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasCheckedNoise = true;
          _isLoudEnvironment = false;
        });
      }
    }
  }

  Future<void> _transcribe() async {
    if (_transcription != null || _isTranscribing) return;

    setState(() => _isTranscribing = true);

    try {
      final text = await AiService.transcribeVoiceUrl(widget.audioUrl);
      if (mounted) {
        setState(() {
          _transcription = text.isNotEmpty ? text : 'Could not transcribe';
          _isTranscribing = false;
          if (_isLoudEnvironment) _showTranscription = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _transcription = 'Transcription failed';
          _isTranscribing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Original voice bubble
        widget.child,

        const SizedBox(height: 4),

        // Sonic Whisper controls row
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Environment indicator
            if (_hasCheckedNoise && !widget.isMe)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (_isLoudEnvironment
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF10B981))
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isLoudEnvironment
                          ? Icons.volume_up_rounded
                          : Icons.volume_down_rounded,
                      size: 11,
                      color: _isLoudEnvironment
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _isLoudEnvironment ? 'Loud' : 'Quiet',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: _isLoudEnvironment
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(width: 6),

            // Transcription toggle
            GestureDetector(
              onTap: () {
                if (_transcription == null && !_isTranscribing) {
                  _transcribe();
                  setState(() => _showTranscription = true);
                } else {
                  setState(() => _showTranscription = !_showTranscription);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.aquaCore.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isTranscribing)
                      SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: AppColors.aquaCore,
                        ),
                      )
                    else
                      Icon(
                        _showTranscription
                            ? Icons.subtitles_off_rounded
                            : Icons.subtitles_rounded,
                        size: 11,
                        color: AppColors.aquaCore,
                      ),
                    const SizedBox(width: 3),
                    Text(
                      _showTranscription ? 'Hide' : 'Transcribe',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: AppColors.aquaCore,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Transcription text
        if (_showTranscription && _transcription != null) ...[
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxWidth: 260),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 10,
                      color: AppColors.aquaCore.withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'SONIC WHISPER',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: AppColors.aquaCore.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _transcription!,
                  style: TextStyle(
                    fontSize: _isLoudEnvironment ? 16 : 13,
                    fontWeight:
                        _isLoudEnvironment ? FontWeight.w600 : FontWeight.w400,
                    color: Colors.white.withOpacity(0.85),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
