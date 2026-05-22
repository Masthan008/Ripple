import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Gyroscopic Parallax Depth™ — Proposal #6
/// Ties the device accelerometer/gyroscope to child widgets,
/// creating a 3D parallax depth effect when tilting the phone.
/// The content behind the glass shifts as if you're peering through
/// a window into another dimension.

class GyroscopicParallaxWrapper extends StatefulWidget {
  final Widget child;
  final double parallaxIntensity;
  final double maxOffset;

  const GyroscopicParallaxWrapper({
    super.key,
    required this.child,
    this.parallaxIntensity = 1.0,
    this.maxOffset = 15.0,
  });

  @override
  State<GyroscopicParallaxWrapper> createState() =>
      _GyroscopicParallaxWrapperState();
}

class _GyroscopicParallaxWrapperState extends State<GyroscopicParallaxWrapper> {
  double _xOffset = 0;
  double _yOffset = 0;
  StreamSubscription? _accelSubscription;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    try {
      _accelSubscription = accelerometerEventStream().listen(
        (AccelerometerEvent event) {
          if (!mounted) return;
          setState(() {
            // event.x = left-right tilt, event.y = forward-back tilt
            // Invert and scale for natural parallax feel
            _xOffset = (event.x * widget.parallaxIntensity * 3)
                .clamp(-widget.maxOffset, widget.maxOffset);
            _yOffset = ((event.y - 9.8) * widget.parallaxIntensity * 3)
                .clamp(-widget.maxOffset, widget.maxOffset);
          });
        },
        onError: (_) {
          // Sensor not available — graceful degradation
        },
        cancelOnError: false,
      );
    } catch (_) {
      // sensors_plus not supported on this platform
    }
  }

  @override
  void dispose() {
    _accelSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001) // Perspective
        ..rotateY(_xOffset * 0.003)
        ..rotateX(-_yOffset * 0.003),
      transformAlignment: Alignment.center,
      child: Transform.translate(
        offset: Offset(_xOffset, _yOffset),
        child: widget.child,
      ),
    );
  }
}

/// Lightweight version for background layers only (aurora, particles)
/// Applies pure translation parallax without 3D rotation.
class ParallaxLayer extends StatefulWidget {
  final Widget child;
  final double depthFactor; // Higher = more movement (far layer)

  const ParallaxLayer({
    super.key,
    required this.child,
    this.depthFactor = 1.0,
  });

  @override
  State<ParallaxLayer> createState() => _ParallaxLayerState();
}

class _ParallaxLayerState extends State<ParallaxLayer> {
  double _xOffset = 0;
  double _yOffset = 0;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    try {
      _subscription = accelerometerEventStream().listen(
        (event) {
          if (!mounted) return;
          setState(() {
            _xOffset = (event.x * widget.depthFactor * 2)
                .clamp(-20.0, 20.0);
            _yOffset = ((event.y - 9.8) * widget.depthFactor * 2)
                .clamp(-20.0, 20.0);
          });
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(_xOffset, _yOffset),
      child: widget.child,
    );
  }
}
