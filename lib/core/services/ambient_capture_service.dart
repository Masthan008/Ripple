import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import 'supabase_service.dart';

/// Ambient Capture Service — Ambient Sonic Footprints™
///
/// Records a very short (2-second) snippet of the sender's ambient
/// background noise when they tap send. The audio is:
/// 1. Recorded at low quality (mono, 32kbps AAC) for minimal file size
/// 2. Uploaded to Supabase Storage (voice-messages bucket)
/// 3. Stored as `ambientAudioUrl` on the message document
/// 4. Auto-played at very low volume (0.1) when the recipient scrolls
///    past the message
///
/// All audio is ephemeral — the recording is deleted from local
/// storage after upload.
class AmbientCaptureService {
  AmbientCaptureService._();
  static final AmbientCaptureService instance = AmbientCaptureService._();

  final AudioRecorder _recorder = AudioRecorder();
  static const _uuid = Uuid();

  bool _isCapturing = false;
  bool get isCapturing => _isCapturing;

  /// Capture a 2-second ambient audio snippet.
  /// Returns the public URL of the uploaded audio, or null on failure.
  Future<String?> captureAndUpload() async {
    if (_isCapturing) return null;
    _isCapturing = true;

    try {
      // Check microphone permission
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        debugPrint('🎧 Ambient: Microphone permission denied');
        return null;
      }

      // Prepare temp file
      final tempDir = await getTemporaryDirectory();
      final fileName = 'ambient_${_uuid.v4()}.m4a';
      final filePath = '${tempDir.path}/$fileName';

      // Record at very low quality — minimal battery + storage impact
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          numChannels: 1,
          bitRate: 32000, // 32kbps — very compressed
          sampleRate: 22050, // Half of standard — sufficient for ambient
        ),
        path: filePath,
      );

      // Wait 2 seconds
      await Future.delayed(const Duration(seconds: 2));

      // Stop recording
      final path = await _recorder.stop();
      if (path == null) return null;

      final file = File(path);
      if (!file.existsSync()) return null;

      // Upload to Supabase Storage
      final publicUrl = await SupabaseService.uploadFile(file, fileName);

      // Clean up local file
      try {
        await file.delete();
      } catch (_) {}

      debugPrint('🎧 Ambient captured: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('🎧 Ambient capture error: $e');
      return null;
    } finally {
      _isCapturing = false;
    }
  }

  /// Dispose the recorder.
  void dispose() {
    _recorder.dispose();
  }
}
