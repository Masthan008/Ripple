import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

/// Typographic Decryption™ — Proposal #4
/// Text appears as scrambled alien glyphs/matrix characters before
/// "decrypting" into readable text, character by character.
/// Used for Quantum Vault reveals and dramatic text entries.

class DecryptingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration decryptDuration;
  final bool autoStart;
  final VoidCallback? onComplete;

  const DecryptingText({
    super.key,
    required this.text,
    this.style,
    this.decryptDuration = const Duration(milliseconds: 1200),
    this.autoStart = true,
    this.onComplete,
  });

  @override
  State<DecryptingText> createState() => DecryptingTextState();
}

class DecryptingTextState extends State<DecryptingText> {
  final _random = Random();
  late List<_CharState> _chars;
  Timer? _timer;
  bool _isComplete = false;

  static const _cryptoGlyphs =
      'ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩαβγδεζηθ'
      '₿∆∑∏∫∂√∞≈≠≤≥±×÷'
      '░▒▓█▀▄▌▐╬╠╣╦╩║═'
      '01001101・゜ ゚・';

  @override
  void initState() {
    super.initState();
    _chars = widget.text.split('').map((ch) {
      return _CharState(
        target: ch,
        current: ch == ' ' ? ' ' : _randomGlyph(),
        isDecrypted: ch == ' ', // spaces decrypt instantly
        scrambleCount: 3 + _random.nextInt(6), // 3–8 scrambles before settling
      );
    }).toList();

    if (widget.autoStart) {
      // Small delay so the scrambled text is visible first
      Future.delayed(const Duration(milliseconds: 200), startDecryption);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _randomGlyph() {
    return String.fromCharCode(
      _cryptoGlyphs.codeUnitAt(_random.nextInt(_cryptoGlyphs.length)),
    );
  }

  void startDecryption() {
    final msPerChar = widget.decryptDuration.inMilliseconds ~/ widget.text.length;
    final interval = Duration(milliseconds: (msPerChar * 0.3).round().clamp(16, 80));
    int currentIndex = 0;

    _timer = Timer.periodic(interval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        // Scramble all undecrypted characters
        for (int i = currentIndex; i < _chars.length; i++) {
          if (!_chars[i].isDecrypted) {
            _chars[i].scrambleCount--;
            if (_chars[i].scrambleCount <= 0) {
              // This char settles
              _chars[i].current = _chars[i].target;
              _chars[i].isDecrypted = true;
              if (i == currentIndex) currentIndex++;
            } else {
              _chars[i].current = _randomGlyph();
            }
          }
        }

        // Move the decrypt frontier forward
        if (currentIndex < _chars.length && !_chars[currentIndex].isDecrypted) {
          _chars[currentIndex].scrambleCount =
              (_chars[currentIndex].scrambleCount - 1).clamp(0, 99);
        }
      });

      // Check completion
      if (_chars.every((c) => c.isDecrypted)) {
        timer.cancel();
        _isComplete = true;
        widget.onComplete?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final defaultStyle = widget.style ?? const TextStyle(
      fontSize: 15,
      color: Colors.white,
      height: 1.4,
    );

    return RichText(
      text: TextSpan(
        children: _chars.map((charState) {
          if (charState.isDecrypted) {
            return TextSpan(
              text: charState.current,
              style: defaultStyle,
            );
          } else {
            // Undecrypted characters glow green like the Matrix
            return TextSpan(
              text: charState.current,
              style: defaultStyle.copyWith(
                color: const Color(0xFF00FF41).withOpacity(0.8),
                fontFamily: 'monospace',
                letterSpacing: 1.5,
                shadows: [
                  Shadow(
                    color: const Color(0xFF00FF41).withOpacity(0.4),
                    blurRadius: 6,
                  ),
                ],
              ),
            );
          }
        }).toList(),
      ),
    );
  }
}

class _CharState {
  final String target;
  String current;
  bool isDecrypted;
  int scrambleCount;

  _CharState({
    required this.target,
    required this.current,
    required this.isDecrypted,
    required this.scrambleCount,
  });
}

/// A cascade decryption overlay used specifically by QuantumVault
/// to create the full-bubble decrypt reveal effect.
class QuantumDecryptCascade extends StatefulWidget {
  final String plainText;
  final VoidCallback? onDecryptComplete;

  const QuantumDecryptCascade({
    super.key,
    required this.plainText,
    this.onDecryptComplete,
  });

  @override
  State<QuantumDecryptCascade> createState() => _QuantumDecryptCascadeState();
}

class _QuantumDecryptCascadeState extends State<QuantumDecryptCascade>
    with SingleTickerProviderStateMixin {
  late AnimationController _sweepController;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward().then((_) {
        widget.onDecryptComplete?.call();
      });
  }

  @override
  void dispose() {
    _sweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _sweepController,
      builder: (context, _) {
        final progress = _sweepController.value;
        final chars = widget.plainText.split('');
        final decryptedCount = (progress * chars.length).round();

        return RichText(
          text: TextSpan(
            children: List.generate(chars.length, (i) {
              if (i < decryptedCount) {
                return TextSpan(
                  text: chars[i],
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.white,
                    height: 1.4,
                  ),
                );
              } else {
                // Still encrypted
                final glyph = DecryptingTextState._cryptoGlyphs;
                final randomChar = String.fromCharCode(
                  glyph.codeUnitAt(_random.nextInt(glyph.length)),
                );
                return TextSpan(
                  text: randomChar,
                  style: TextStyle(
                    fontSize: 15,
                    color: const Color(0xFF00FF41).withOpacity(0.8),
                    fontFamily: 'monospace',
                    letterSpacing: 1.5,
                    height: 1.4,
                    shadows: [
                      Shadow(
                        color: const Color(0xFF00FF41).withOpacity(0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                );
              }
            }),
          ),
        );
      },
    );
  }
}
