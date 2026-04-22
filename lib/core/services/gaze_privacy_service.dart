import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Gaze Privacy Service — Ripple Telepathy™
///
/// Uses the front-facing camera and on-device ML Kit face detection
/// to power two revolutionary privacy features:
///
/// 1. **Gaze Lock** — Messages stay frosted/blurred until the user's
///    face is detected looking at the screen. Only the message area
///    the user focuses on "unfreezes."
///
/// 2. **Anti-Shoulder Surfing** — If a second face is detected in the
///    camera frame, the entire chat instantly blurs and a haptic
///    warning fires.
///
/// All processing is done 100% on-device. No facial data is ever
/// transmitted to the cloud.
class GazePrivacyService {
  GazePrivacyService._();
  static final GazePrivacyService instance = GazePrivacyService._();

  // Camera
  CameraController? _cameraController;
  bool _isInitialized = false;
  bool _isProcessing = false;

  // ML Kit
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true, // for eye open probability
      enableTracking: true,
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.15,
    ),
  );

  // State streams
  final _stateController = StreamController<GazePrivacyState>.broadcast();
  Stream<GazePrivacyState> get stateStream => _stateController.stream;

  GazePrivacyState _currentState = const GazePrivacyState();
  GazePrivacyState get currentState => _currentState;

  // Timing: avoid spamming state changes
  DateTime _lastUpdate = DateTime.now();
  static const _updateInterval = Duration(milliseconds: 150);

  // Consecutive frame counters for stability
  int _consecutiveNoFace = 0;
  int _consecutiveMultiFace = 0;
  int _consecutiveSingleFace = 0;
  static const _stabilityThreshold = 3; // frames before state change

  /// Initialize the camera + face detector pipeline.
  /// Call once when the chat screen mounts and telepathy is enabled.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.low, // minimal battery impact
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();
      _isInitialized = true;

      // Start processing frames
      _cameraController!.startImageStream(_processFrame);

      debugPrint('🔮 GazePrivacyService initialized');
    } catch (e) {
      debugPrint('❌ GazePrivacyService init failed: $e');
      // Graceful degradation — unlock everything if camera fails
      _emitState(const GazePrivacyState(
        isUserPresent: true,
        isShoulderSurferDetected: false,
        eyeOpenProbability: 1.0,
      ));
    }
  }

  /// Process a single camera frame through ML Kit.
  Future<void> _processFrame(CameraImage image) async {
    if (_isProcessing) return;

    // Throttle
    final now = DateTime.now();
    if (now.difference(_lastUpdate) < _updateInterval) return;
    _lastUpdate = now;

    _isProcessing = true;

    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        // No face detected
        _consecutiveNoFace++;
        _consecutiveSingleFace = 0;
        _consecutiveMultiFace = 0;

        if (_consecutiveNoFace >= _stabilityThreshold) {
          _emitState(const GazePrivacyState(
            isUserPresent: false,
            isShoulderSurferDetected: false,
            eyeOpenProbability: 0.0,
          ));
        }
      } else if (faces.length == 1) {
        // Single face — the user
        _consecutiveSingleFace++;
        _consecutiveNoFace = 0;
        _consecutiveMultiFace = 0;

        if (_consecutiveSingleFace >= _stabilityThreshold) {
          final face = faces.first;
          final leftEye = face.leftEyeOpenProbability ?? 0.5;
          final rightEye = face.rightEyeOpenProbability ?? 0.5;
          final avgEye = (leftEye + rightEye) / 2;

          // Determine if user is looking at the screen
          // Head euler Y close to 0 means looking straight ahead
          final headY = face.headEulerAngleY ?? 0;
          final isLookingAtScreen = headY.abs() < 30 && avgEye > 0.3;

          _emitState(GazePrivacyState(
            isUserPresent: isLookingAtScreen,
            isShoulderSurferDetected: false,
            eyeOpenProbability: avgEye,
            headAngleY: headY,
          ));
        }
      } else {
        // Multiple faces — shoulder surfer detected!
        _consecutiveMultiFace++;
        _consecutiveNoFace = 0;
        _consecutiveSingleFace = 0;

        if (_consecutiveMultiFace >= _stabilityThreshold) {
          _emitState(const GazePrivacyState(
            isUserPresent: true,
            isShoulderSurferDetected: true,
            eyeOpenProbability: 1.0,
          ));
        }
      }
    } catch (e) {
      debugPrint('⚠️ Frame processing error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  /// Convert CameraImage to InputImage for ML Kit.
  InputImage? _convertCameraImage(CameraImage image) {
    try {
      final plane = image.planes.first;

      final inputImageData = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: _getRotation(),
        format: InputImageFormat.nv21,
        bytesPerRow: plane.bytesPerRow,
      );

      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: inputImageData,
      );
    } catch (e) {
      debugPrint('⚠️ Image conversion error: $e');
      return null;
    }
  }

  InputImageRotation _getRotation() {
    final sensorOrientation = _cameraController?.description.sensorOrientation ?? 0;
    switch (sensorOrientation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  void _emitState(GazePrivacyState state) {
    if (state == _currentState) return; // No change
    _currentState = state;
    _stateController.add(state);
  }

  /// Tear down camera and detector.
  Future<void> dispose() async {
    if (_cameraController != null) {
      if (_cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }
      await _cameraController!.dispose();
      _cameraController = null;
    }
    await _faceDetector.close();
    _isInitialized = false;
    debugPrint('🔮 GazePrivacyService disposed');
  }

  bool get isInitialized => _isInitialized;
}

/// Immutable state snapshot for the gaze privacy system.
class GazePrivacyState {
  /// Whether the user's face is present and looking at the screen.
  final bool isUserPresent;

  /// Whether a second face (shoulder surfer) has been detected.
  final bool isShoulderSurferDetected;

  /// Average probability that the user's eyes are open (0.0–1.0).
  final double eyeOpenProbability;

  /// Head euler angle Y — how far the user's head is turned left/right.
  final double headAngleY;

  const GazePrivacyState({
    this.isUserPresent = false,
    this.isShoulderSurferDetected = false,
    this.eyeOpenProbability = 0.0,
    this.headAngleY = 0.0,
  });

  /// Whether messages should be visible (user present, no surfer).
  bool get shouldShowMessages => isUserPresent && !isShoulderSurferDetected;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GazePrivacyState &&
          runtimeType == other.runtimeType &&
          isUserPresent == other.isUserPresent &&
          isShoulderSurferDetected == other.isShoulderSurferDetected;

  @override
  int get hashCode => isUserPresent.hashCode ^ isShoulderSurferDetected.hashCode;
}
