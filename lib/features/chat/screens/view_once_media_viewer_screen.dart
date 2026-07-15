import 'package:flutter/material.dart';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

/// Full-screen viewer for View-Once media items.
/// Automatically applies screenshot blocking while open.
class ViewOnceMediaViewerScreen extends StatefulWidget {
  final String mediaUrl;
  final String type; // 'image' | 'video'

  const ViewOnceMediaViewerScreen({
    super.key,
    required this.mediaUrl,
    required this.type,
  });

  @override
  State<ViewOnceMediaViewerScreen> createState() => _ViewOnceMediaViewerScreenState();
}

class _ViewOnceMediaViewerScreenState extends State<ViewOnceMediaViewerScreen> {
  VideoPlayerController? _videoController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _enableSecureWindow();
    if (widget.type == 'video') {
      _initVideo();
    }
  }

  Future<void> _enableSecureWindow() async {
    try {
      if (Platform.isAndroid) {
        await FlutterWindowManagerPlus.addFlags(FlutterWindowManagerPlus.FLAG_SECURE);
      }
    } catch (_) {}
  }

  Future<void> _disableSecureWindow() async {
    try {
      if (Platform.isAndroid) {
        await FlutterWindowManagerPlus.clearFlags(FlutterWindowManagerPlus.FLAG_SECURE);
      }
    } catch (_) {}
  }

  Future<void> _initVideo() async {
    _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.mediaUrl));
    try {
      await _videoController!.initialize();
      _videoController!.setLooping(false);
      _videoController!.play();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint('❌ Video player initialization error: $e');
    }
  }

  @override
  void dispose() {
    _disableSecureWindow();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Content
          Center(
            child: widget.type == 'video'
                ? (_isInitialized
                    ? AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!),
                      )
                    : const CircularProgressIndicator(color: AppColors.aquaCore))
                : InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.network(
                      widget.mediaUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(child: CircularProgressIndicator(color: AppColors.aquaCore));
                      },
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image_rounded, color: Colors.white24, size: 64),
                      ),
                    ),
                  ),
          ),

          // Header with back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.remove_red_eye_rounded, color: AppColors.aquaCore, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'View Once',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Floating video controls
          if (widget.type == 'video' && _isInitialized)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: FloatingActionButton(
                  backgroundColor: AppColors.aquaCore.withOpacity(0.8),
                  foregroundColor: Colors.black,
                  onPressed: () {
                    setState(() {
                      if (_videoController!.value.isPlaying) {
                        _videoController!.pause();
                      } else {
                        _videoController!.play();
                      }
                    });
                  },
                  child: Icon(
                    _videoController!.value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
