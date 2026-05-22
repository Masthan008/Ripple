import 'dart:math';
import 'package:flutter/material.dart';

/// Bio-Acoustic Waveform™ — Proposal #8
/// A glowing, organic, particle-based waveform that responds to audio
/// playback with pitch-mapped color shifts and volume-driven particle spray.
/// Replaces the boring static waveform bar in voice message bubbles.

class BioAcousticWaveform extends StatefulWidget {
  final List<double> waveformData;
  final double progress; // 0.0 – 1.0 playback progress
  final bool isPlaying;
  final Color baseColor;
  final double height;
  final double width;

  const BioAcousticWaveform({
    super.key,
    required this.waveformData,
    this.progress = 0.0,
    this.isPlaying = false,
    this.baseColor = const Color(0xFF0EA5E9),
    this.height = 48,
    this.width = 200,
  });

  @override
  State<BioAcousticWaveform> createState() => _BioAcousticWaveformState();
}

class _BioAcousticWaveformState extends State<BioAcousticWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, _) {
          return CustomPaint(
            painter: _BioWaveformPainter(
              waveformData: widget.waveformData,
              progress: widget.progress,
              isPlaying: widget.isPlaying,
              baseColor: widget.baseColor,
              pulsePhase: _pulseController.value,
            ),
          );
        },
      ),
    );
  }
}

class _BioWaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final double progress;
  final bool isPlaying;
  final Color baseColor;
  final double pulsePhase;

  _BioWaveformPainter({
    required this.waveformData,
    required this.progress,
    required this.isPlaying,
    required this.baseColor,
    required this.pulsePhase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    final random = Random(42);
    final centerY = size.height / 2;
    final barWidth = size.width / waveformData.length;
    final progressIndex = (progress * waveformData.length).round();

    for (int i = 0; i < waveformData.length; i++) {
      final x = i * barWidth + barWidth / 2;
      final amplitude = waveformData[i].clamp(0.0, 1.0);
      final isPast = i <= progressIndex;

      // Pitch-mapped color: low frequencies → blue, high → cyan/magenta
      final colorLerp = (amplitude * 2).clamp(0.0, 1.0);
      final barColor = isPast
          ? Color.lerp(
              baseColor,
              const Color(0xFFEC4899), // magenta for high amplitude
              colorLerp,
            )!
          : baseColor.withOpacity(0.2);

      // Animated height for playing state
      double displayAmplitude = amplitude;
      if (isPlaying && isPast && i == progressIndex) {
        // Current playing position gets a pulse
        displayAmplitude *= 1.0 + sin(pulsePhase * pi * 2) * 0.3;
      } else if (isPlaying && !isPast) {
        // Future bars gently breathe
        displayAmplitude *= 0.8 + sin(pulsePhase * pi * 2 + i * 0.3) * 0.1;
      }

      final barHeight = (displayAmplitude * size.height * 0.8).clamp(2.0, size.height * 0.9);

      // Main bar
      final barPaint = Paint()
        ..color = barColor
        ..maskFilter = isPast
            ? MaskFilter.blur(BlurStyle.normal, 1 + amplitude * 2)
            : null;

      final rrect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, centerY),
          width: barWidth * 0.6,
          height: barHeight,
        ),
        Radius.circular(barWidth * 0.3),
      );

      canvas.drawRRect(rrect, barPaint);

      // Glow layer for played bars
      if (isPast) {
        final glowPaint = Paint()
          ..color = barColor.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

        canvas.drawRRect(rrect, glowPaint);
      }

      // Particle spray for high-volume segments during playback
      if (isPlaying && isPast && amplitude > 0.6) {
        final particleCount = (amplitude * 3).round();
        for (int p = 0; p < particleCount; p++) {
          final px = x + (random.nextDouble() - 0.5) * 8;
          final py = centerY +
              (random.nextDouble() - 0.5) * barHeight * 1.5 +
              sin(pulsePhase * pi * 2 + p) * 4;

          final particlePaint = Paint()
            ..color = barColor.withOpacity(0.4 * (1 - (p / particleCount)))
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

          canvas.drawCircle(Offset(px, py), 1.5, particlePaint);
        }
      }
    }

    // Playback cursor line
    if (isPlaying && progress > 0) {
      final cursorX = progress * size.width;
      final cursorPaint = Paint()
        ..color = Colors.white.withOpacity(0.8)
        ..strokeWidth = 1.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

      canvas.drawLine(
        Offset(cursorX, 4),
        Offset(cursorX, size.height - 4),
        cursorPaint,
      );

      // Glowing dot at cursor
      final dotPaint = Paint()
        ..color = Colors.white
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(Offset(cursorX, centerY), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BioWaveformPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      isPlaying != oldDelegate.isPlaying ||
      pulsePhase != oldDelegate.pulsePhase;
}
