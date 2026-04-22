import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Keyword Particle System — Interactive Chat Background
///
/// Detects emotional keywords in sent messages and spawns themed
/// particles that float up from the bottom of the chat area,
/// interact with message bubbles, and gently fade away.
///
/// Keyword → Particle mapping:
/// - Love/heart words → 💖 pink hearts
/// - Happy/celebrate → ✨ golden sparkles
/// - Fire/hot → 🔥 orange embers
/// - Sad/miss → 💧 blue teardrops
/// - Music/dance → 🎵 note particles
class KeywordParticleOverlay extends StatefulWidget {
  /// The keyword that triggered the particle effect.
  final String? triggerKeyword;

  const KeywordParticleOverlay({super.key, this.triggerKeyword});

  @override
  State<KeywordParticleOverlay> createState() => _KeywordParticleOverlayState();
}

class _KeywordParticleOverlayState extends State<KeywordParticleOverlay>
    with TickerProviderStateMixin {
  final List<_FloatingParticle> _particles = [];
  final _random = Random();
  AnimationController? _tickController;

  static const _keywordThemes = <String, _ParticleTheme>{
    // Love / affection
    'love': _ParticleTheme(Icons.favorite_rounded, Color(0xFFEC4899), 15),
    'heart': _ParticleTheme(Icons.favorite_outline_rounded, Color(0xFFEC4899), 12),
    'miss': _ParticleTheme(Icons.auto_awesome_rounded, Color(0xFF8B5CF6), 10),
    'kiss': _ParticleTheme(Icons.favorite_rounded, Color(0xFFF43F5E), 8),
    'hug': _ParticleTheme(Icons.emoji_emotions_rounded, Color(0xFFFBBF24), 8),

    // Celebration
    'happy': _ParticleTheme(Icons.star_rounded, Color(0xFFFBBF24), 15),
    'congrats': _ParticleTheme(Icons.celebration_rounded, Color(0xFFFBBF24), 12),
    'birthday': _ParticleTheme(Icons.cake_rounded, Color(0xFFEC4899), 20),
    'win': _ParticleTheme(Icons.emoji_events_rounded, Color(0xFFFBBF24), 10),
    'yay': _ParticleTheme(Icons.celebration_rounded, Color(0xFF8B5CF6), 12),

    // Intensity
    'fire': _ParticleTheme(Icons.local_fire_department_rounded, Color(0xFFF97316), 15),
    'hot': _ParticleTheme(Icons.local_fire_department_rounded, Color(0xFFEF4444), 10),
    'amazing': _ParticleTheme(Icons.star_rounded, Color(0xFFFBBF24), 12),
    'wow': _ParticleTheme(Icons.bolt_rounded, Color(0xFF0EA5E9), 10),

    // Sadness
    'sad': _ParticleTheme(Icons.water_drop_rounded, Color(0xFF3B82F6), 10),
    'cry': _ParticleTheme(Icons.water_drop_rounded, Color(0xFF3B82F6), 8),
    'sorry': _ParticleTheme(Icons.favorite_rounded, Color(0xFF6366F1), 8),

    // Music / fun
    'music': _ParticleTheme(Icons.music_note_rounded, Color(0xFF8B5CF6), 12),
    'dance': _ParticleTheme(Icons.audiotrack_rounded, Color(0xFFEC4899), 10),
    'party': _ParticleTheme(Icons.celebration_rounded, Color(0xFF8B5CF6), 15),

    // Weather
    'rain': _ParticleTheme(Icons.water_drop_rounded, Color(0xFF3B82F6), 20),
    'snow': _ParticleTheme(Icons.ac_unit_rounded, Color(0xFFE0F2FE), 25),
    'sun': _ParticleTheme(Icons.wb_sunny_rounded, Color(0xFFFBBF24), 10),
  };

  @override
  void initState() {
    super.initState();
    _tickController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _tickController!.addListener(_updateParticles);
  }

  @override
  void didUpdateWidget(KeywordParticleOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.triggerKeyword != null &&
        widget.triggerKeyword != oldWidget.triggerKeyword) {
      _spawnParticles(widget.triggerKeyword!);
    }
  }

  void _spawnParticles(String keyword) {
    final words = keyword.toLowerCase().split(RegExp(r'[\s,.!?]+'));

    for (final word in words) {
      final theme = _keywordThemes[word];
      if (theme != null) {
        for (int i = 0; i < theme.count; i++) {
          _particles.add(_FloatingParticle(
            x: _random.nextDouble(),
            y: 1.0 + _random.nextDouble() * 0.2,
            icon: theme.icon,
            color: theme.color,
            speed: 0.3 + _random.nextDouble() * 0.4,
            wobble: _random.nextDouble() * 2 * pi,
            wobbleSpeed: 1 + _random.nextDouble() * 2,
            size: 14 + _random.nextDouble() * 10,
            opacity: 0.7 + _random.nextDouble() * 0.3,
            lifetime: 3.0 + _random.nextDouble() * 2,
            age: 0,
          ));
        }
        break; // Only trigger first matching keyword
      }
    }
  }

  void _updateParticles() {
    if (!mounted) return;

    setState(() {
      final dt = 1 / 60; // ~60fps
      _particles.removeWhere((p) {
        p.age += dt;
        p.y -= p.speed * dt * 0.15;
        p.x += sin(p.wobble + p.age * p.wobbleSpeed) * 0.002;
        p.opacity = ((1 - p.age / p.lifetime) * 0.8).clamp(0.0, 1.0);
        return p.age >= p.lifetime;
      });
    });
  }

  @override
  void dispose() {
    _tickController?.removeListener(_updateParticles);
    _tickController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_particles.isEmpty) return const SizedBox.shrink();

    final size = MediaQuery.of(context).size;

    return IgnorePointer(
      child: Stack(
        children: _particles.map((p) {
          return Positioned(
            left: p.x * size.width,
            top: p.y * size.height,
            child: Opacity(
              opacity: p.opacity,
              child: Icon(
                p.icon,
                color: p.color,
                size: p.size,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ParticleTheme {
  final IconData icon;
  final Color color;
  final int count;

  const _ParticleTheme(this.icon, this.color, this.count);
}

class _FloatingParticle {
  double x;
  double y;
  final IconData icon;
  final Color color;
  final double speed;
  double wobble;
  final double wobbleSpeed;
  final double size;
  double opacity;
  final double lifetime;
  double age;

  _FloatingParticle({
    required this.x,
    required this.y,
    required this.icon,
    required this.color,
    required this.speed,
    required this.wobble,
    required this.wobbleSpeed,
    required this.size,
    required this.opacity,
    required this.lifetime,
    required this.age,
  });
}
