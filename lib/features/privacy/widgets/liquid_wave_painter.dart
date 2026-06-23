import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Liquid Wave Painter — Visual E2E Key Vector Encoder
///
/// Mesmerizing, multi-layered liquid wave renderer. Translates Curve25519
/// public key handshake bytes into visible mathematical parameters:
/// - Wave 1 Frequency & Amplitude
/// - Wave 2 Phase Offsets
/// - Wave 3 Phase Cycle Offsets
/// - HSL Hue / Color Shift Cycles
class LiquidWavePainter extends CustomPainter {
  final double animationValue;
  final List<int> keyBytes;
  final bool isScanning; // Add subtle pulse scanner line if scanning

  LiquidWavePainter({
    required this.animationValue,
    required this.keyBytes,
    this.isScanning = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Decode keyBytes into distinct parameter controls (fallback to defaults if empty)
    final double paramFreq1 = _mapByte(keyBytes, 0, 0.5, 2.5);
    final double paramAmp1 = _mapByte(keyBytes, 1, 15.0, 45.0);
    final double paramFreq2 = _mapByte(keyBytes, 2, 1.0, 3.5);
    final double paramAmp2 = _mapByte(keyBytes, 3, 10.0, 35.0);
    final double paramPhaseShift = _mapByte(keyBytes, 4, 0.0, math.pi * 2);
    final double baseHue = _mapByte(keyBytes, 5, 170.0, 240.0); // Cyan/Aqua to Blue range

    final double width = size.width;
    final double height = size.height;
    final double centerY = height / 2;

    canvas.save();

    // Draw background grid/dots for an organic laboratory feel
    _paintBackgroundGrid(canvas, size);

    // 2. Render Layer 1 Wave (Deep Abyss Water - Dark Blue)
    final Path wavePath1 = Path();
    wavePath1.moveTo(0, height);

    for (double x = 0; x <= width; x += 3) {
      final double angle = (x / width) * paramFreq1 * math.pi * 2 + (animationValue * math.pi * 2);
      final double y = centerY + math.sin(angle) * paramAmp1;
      wavePath1.lineTo(x, y);
    }
    wavePath1.lineTo(width, height);
    wavePath1.close();

    final Paint wavePaint1 = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          HSLColor.fromAHSL(0.5, baseHue, 0.9, 0.4).toColor(),
          HSLColor.fromAHSL(0.8, baseHue + 15, 0.95, 0.15).toColor(),
        ],
      ).createShader(Rect.fromLTRB(0, centerY - paramAmp1, width, height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(wavePath1, wavePaint1);

    // 3. Render Layer 2 Wave (Aqua/Cyan Fluid - Polarized Core)
    final Path wavePath2 = Path();
    wavePath2.moveTo(0, height);

    for (double x = 0; x <= width; x += 3) {
      final double angle = (x / width) * paramFreq2 * math.pi * 2 -
          (animationValue * math.pi * 2) +
          paramPhaseShift;
      final double y = centerY + math.cos(angle) * paramAmp2 + 10;
      wavePath2.lineTo(x, y);
    }
    wavePath2.lineTo(width, height);
    wavePath2.close();

    final Paint wavePaint2 = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          HSLColor.fromAHSL(0.65, baseHue - 20, 0.95, 0.6).toColor(), // Bright cyan
          HSLColor.fromAHSL(0.9, baseHue, 0.9, 0.2).toColor(),
        ],
      ).createShader(Rect.fromLTRB(0, centerY - paramAmp2 - 10, width, height))
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.screen; // Creates stunning color highlights where waves overlap

    canvas.drawPath(wavePath2, wavePaint2);

    // 4. Render Layer 3 Wave (Top Highlight / Fluid Ripple Rim)
    final Path wavePath3 = Path();
    wavePath3.moveTo(0, height);

    for (double x = 0; x <= width; x += 4) {
      final double angle = (x / width) * (paramFreq1 + paramFreq2) * 0.7 * math.pi * 2 +
          (animationValue * math.pi * 1.5);
      final double y = centerY - 15 + math.sin(angle) * 8.0;
      wavePath3.lineTo(x, y);
    }
    wavePath3.lineTo(width, height);
    wavePath3.close();

    final Paint wavePaint3 = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.35),
          HSLColor.fromAHSL(0.1, baseHue - 30, 1.0, 0.5).toColor(),
        ],
      ).createShader(Rect.fromLTRB(0, centerY - 25, width, height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(wavePath3, wavePaint3);

    // 5. Draw center fingerprint ring
    final Paint ringPaint = Paint()
      ..color = HSLColor.fromAHSL(0.25, baseHue - 10, 0.9, 0.7).toColor()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(Offset(width / 2, centerY), 60.0 + math.sin(animationValue * math.pi * 2) * 5.0, ringPaint);
    canvas.drawCircle(Offset(width / 2, centerY), 35.0 - math.sin(animationValue * math.pi * 2) * 3.0, ringPaint);

    // 6. Optional Scanline laser bar
    if (isScanning) {
      final double scanY = centerY - 100 + (animationValue * 200);
      final Paint scanPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            HSLColor.fromAHSL(0.8, baseHue - 10, 1.0, 0.6).toColor(),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTRB(width * 0.1, scanY - 3, width * 0.9, scanY + 3))
        ..strokeWidth = 2.0;

      canvas.drawLine(Offset(width * 0.1, scanY), Offset(width * 0.9, scanY), scanPaint);
    }

    canvas.restore();
  }

  /// Maps a byte index of keyBytes to a double range
  double _mapByte(List<int> bytes, int byteIndex, double minVal, double maxVal) {
    if (bytes.isEmpty || byteIndex >= bytes.length) {
      return minVal + (maxVal - minVal) / 2; // Midpoint default
    }
    final int byteVal = bytes[byteIndex];
    return minVal + (byteVal / 255.0) * (maxVal - minVal);
  }

  void _paintBackgroundGrid(Canvas canvas, Size size) {
    final Paint gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1.0;

    final double step = 25.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant LiquidWavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.keyBytes != keyBytes ||
        oldDelegate.isScanning != isScanning;
  }
}
