import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/haptic_feedback.dart';

class CircularVideoRecorder extends StatefulWidget {
  final Function(String filePath, Duration duration) onVideoRecorded;
  final VoidCallback onCancelled;

  const CircularVideoRecorder({
    super.key,
    required this.onVideoRecorded,
    required this.onCancelled,
  });

  @override
  State<CircularVideoRecorder> createState() => _CircularVideoRecorderState();
}

class _CircularVideoRecorderState extends State<CircularVideoRecorder> with SingleTickerProviderStateMixin {
  CameraController? _controller;
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _durationTimer;
  late AnimationController _pulseController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final status = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();

    if (!status.isGranted || !micStatus.isGranted) {
      widget.onCancelled();
      return;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      widget.onCancelled();
      return;
    }

    // Prefer front camera for circular video messages
    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
        _startRecording();
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      widget.onCancelled();
    }
  }

  Future<void> _startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      await _controller!.startVideoRecording();
      AppHaptics.mediumTap();
      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });

      _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordingDuration += const Duration(seconds: 1);
          });
          if (_recordingDuration.inSeconds >= 60) {
            _stopAndSend();
          }
        }
      });
    } catch (e) {
      debugPrint('Start recording error: $e');
      widget.onCancelled();
    }
  }

  Future<void> _stopAndSend() async {
    if (!_isRecording || _controller == null) return;

    _durationTimer?.cancel();
    _isRecording = false;
    AppHaptics.success();

    try {
      final file = await _controller!.stopVideoRecording();
      if (_recordingDuration.inSeconds >= 1) {
        widget.onVideoRecorded(file.path, _recordingDuration);
      } else {
        widget.onCancelled();
      }
    } catch (e) {
      debugPrint('Stop recording error: $e');
      widget.onCancelled();
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _pulseController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(child: CircularProgressIndicator(color: AppColors.aquaCore)),
      );
    }

    return Container(
      height: 250,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.abyssBackground.withOpacity(0.9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red.withOpacity(0.3 + (_pulseController.value * 0.7)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.4),
                          blurRadius: 4 * _pulseController.value,
                          spreadRadius: 2 * _pulseController.value,
                        )
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              Text(
                '${_recordingDuration.inMinutes}:${(_recordingDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              const Text(
                'Swipe left to cancel',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: ClipOval(
                child: SizedBox(
                  width: 180,
                  height: 180,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: CameraPreview(_controller!),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: () {
                  AppHaptics.heavyTap();
                  widget.onCancelled();
                },
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.white54),
              ),
              GestureDetector(
                onTap: _stopAndSend,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.aquaCore,
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
