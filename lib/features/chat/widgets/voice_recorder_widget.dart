import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../../core/constants/app_colors.dart';

/// Voice recorder widget — hold mic to record, swipe left to cancel
/// Shows pulsing red dot, duration timer, waveform, and slide-to-cancel hint
class VoiceRecorderWidget extends StatefulWidget {
  final Function(String filePath, Duration duration, List<double> waveformData)
      onRecordingComplete;
  final VoidCallback onCancelled;

  const VoiceRecorderWidget({
    super.key,
    required this.onRecordingComplete,
    required this.onCancelled,
  });

  @override
  State<VoiceRecorderWidget> createState() => VoiceRecorderWidgetState();
}

class VoiceRecorderWidgetState extends State<VoiceRecorderWidget>
    with SingleTickerProviderStateMixin {
  final _audioRecorder = AudioRecorder();
  late AnimationController _pulseController;
  Timer? _durationTimer;
  Duration _recordingDuration = Duration.zero;
  String? _recordingPath;
  final List<double> _waveformAmplitudes = [];
  Timer? _amplitudeTimer;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _startRecording();
  }

  Future<void> _startRecording() async {
    try {
      final permission = await Permission.microphone.request();
      if (!permission.isGranted) {
        widget.onCancelled();
        return;
      }

      final dir = await getTemporaryDirectory();
      _recordingPath =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _recordingPath!,
      );

      _isRecording = true;

      // Duration timer
      _durationTimer =
          Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {
            _recordingDuration += const Duration(seconds: 1);
          });
          if (_recordingDuration.inSeconds >= 120) {
            stopAndSend(); // Max 2 minutes
          }
        }
      });

      // Amplitude sampling for waveform
      _amplitudeTimer =
          Timer.periodic(const Duration(milliseconds: 100), (_) async {
        try {
          final amp = await _audioRecorder.getAmplitude();
          if (mounted) {
            setState(() {
              // Normalize amplitude from dBFS (-60 to 0) → 0.0 to 1.0
              final normalized = ((amp.current + 60) / 60).clamp(0.0, 1.0);
              _waveformAmplitudes.add(normalized);
            });
          }
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('⚠️ Recording failed: $e');
      widget.onCancelled();
    }
  }

  Future<void> stopAndSend() async {
    if (!_isRecording) return;
    _isRecording = false;

    _durationTimer?.cancel();
    _amplitudeTimer?.cancel();

    try {
      final path = await _audioRecorder.stop();
      if (path != null && _recordingDuration.inSeconds >= 1) {
        widget.onRecordingComplete(
          path,
          _recordingDuration,
          List<double>.from(_waveformAmplitudes),
        );
      } else {
        widget.onCancelled();
      }
    } catch (_) {
      widget.onCancelled();
    }
  }

  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    _isRecording = false;

    _durationTimer?.cancel();
    _amplitudeTimer?.cancel();

    try {
      await _audioRecorder.stop();
      // Delete the recorded file
      if (_recordingPath != null) {
        final file = File(_recordingPath!);
        if (await file.exists()) await file.delete();
      }
    } catch (_) {}

    widget.onCancelled();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _durationTimer?.cancel();
    _amplitudeTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0A1628),
        border: Border(
          top: BorderSide(color: Colors.white12),
        ),
      ),
      child: Row(
        children: [
          // Pulsing red dot
          AnimatedBuilder(
            animation: _pulseController,
            builder: (_, __) => Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.lerp(
                  Colors.red,
                  Colors.red.withValues(alpha: 0.3),
                  _pulseController.value,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Duration
          Text(
            _formatDuration(_recordingDuration),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 16),

          // Waveform visualization
          Expanded(
            child: _waveformAmplitudes.isEmpty
                ? const SizedBox()
                : CustomPaint(
                    painter: _WaveformPainter(_waveformAmplitudes),
                    size: const Size(double.infinity, 32),
                  ),
          ),

          const SizedBox(width: 8),

          // Slide to cancel hint
          const Text(
            '< Slide to cancel',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Waveform painter for recording visualization
class _WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  _WaveformPainter(this.amplitudes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.aquaCore
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const barWidth = 3.0;
    const gap = 2.0;
    final maxBars = (size.width / (barWidth + gap)).floor();
    final displayAmps = amplitudes.length > maxBars
        ? amplitudes.sublist(amplitudes.length - maxBars)
        : amplitudes;

    for (int i = 0; i < displayAmps.length; i++) {
      final x = i * (barWidth + gap);
      final barHeight = (displayAmps[i] * size.height).clamp(2.0, size.height);
      final y = (size.height - barHeight) / 2;
      canvas.drawLine(
        Offset(x, y),
        Offset(x, y + barHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => true;
}
