import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../models/mood_config.dart';
import '../services/status_service.dart';

/// Bottom sheet for creating a new status — offers Photo, Video, Text, Mood.
class CreateStatusSheet extends StatelessWidget {
  const CreateStatusSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A1628),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Create Status',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          _OptionTile(
            icon: Icons.photo_camera_rounded,
            title: 'Photo',
            subtitle: 'Share a photo from your gallery',
            onTap: () {
              final nav = Navigator.of(context, rootNavigator: true);
              final scaffold = ScaffoldMessenger.of(context);
              nav.pop();
              _pickAndPostPhoto(nav.context, scaffold);
            },
          ),
          _OptionTile(
            icon: Icons.videocam_rounded,
            title: 'Video',
            subtitle: 'Share a short video clip',
            onTap: () {
              final nav = Navigator.of(context, rootNavigator: true);
              final scaffold = ScaffoldMessenger.of(context);
              nav.pop();
              _pickAndPostVideo(nav.context, scaffold);
            },
          ),
          _OptionTile(
            icon: Icons.text_fields_rounded,
            title: 'Text',
            subtitle: 'Write something with a gradient background',
            onTap: () {
              final nav = Navigator.of(context, rootNavigator: true);
              nav.pop();
              nav.push(MaterialPageRoute(
                builder: (_) => const _TextStatusEditor(),
              ));
            },
          ),
          _OptionTile(
            icon: Icons.mood_rounded,
            emoji: '🎭',
            title: 'Mood',
            subtitle: 'Set your mood aura',
            onTap: () {
              final nav = Navigator.of(context, rootNavigator: true);
              final parentContext = nav.context;
              nav.pop();
              showModalBottomSheet(
                context: parentContext,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (_) => const _MoodPickerSheet(),
              );
            },
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  static Future<void> _pickAndPostPhoto(
      BuildContext context, ScaffoldMessengerState scaffold) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1920,
        imageQuality: 80,
      );
      if (picked == null) return;

      // Show upload progress
      scaffold.showSnackBar(
        const SnackBar(
          content: Text('Uploading photo status...'),
          duration: Duration(seconds: 5),
          backgroundColor: Color(0xFF1A2A40),
        ),
      );

      // Compress
      final dir = await getTemporaryDirectory();
      final targetPath =
          '${dir.path}/status_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final compressed = await FlutterImageCompress.compressAndGetFile(
        picked.path,
        targetPath,
        quality: 75,
        minWidth: 720,
        minHeight: 1280,
      );

      final filePath = compressed?.path ?? picked.path;

      // Upload to Cloudinary
      final url = await CloudinaryService.uploadImage(File(filePath));
      if (url == null) throw Exception('Upload failed');

      scaffold.hideCurrentSnackBar();

      // Navigate to Caption Editor
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _StatusCaptionEditor(
              mediaUrl: url,
              type: 'photo',
            ),
          ),
        );
      }
    } catch (e) {
      scaffold.hideCurrentSnackBar();
      scaffold.showSnackBar(
        SnackBar(
          content: Text('Failed to process photo: $e'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  static Future<void> _pickAndPostVideo(
      BuildContext context, ScaffoldMessengerState scaffold) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 30),
      );
      if (picked == null) return;

      scaffold.showSnackBar(
        const SnackBar(
          content: Text('Uploading video status...'),
          duration: Duration(seconds: 15),
          backgroundColor: Color(0xFF1A2A40),
        ),
      );

      // Upload to Cloudinary
      final url = await CloudinaryService.uploadVideo(File(picked.path));
      if (url == null) throw Exception('Upload failed');

      scaffold.hideCurrentSnackBar();

      // Navigate to Caption Editor
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _StatusCaptionEditor(
              mediaUrl: url,
              type: 'video',
            ),
          ),
        );
      }
    } catch (e) {
      scaffold.hideCurrentSnackBar();
      scaffold.showSnackBar(
        SnackBar(
          content: Text('Failed to process video: $e'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }
}

// ─── Status Caption Editor ────────────────────────────────

class _StatusCaptionEditor extends StatefulWidget {
  final String mediaUrl;
  final String type; // 'photo' or 'video'

  const _StatusCaptionEditor({
    required this.mediaUrl,
    required this.type,
  });

  @override
  State<_StatusCaptionEditor> createState() => _StatusCaptionEditorState();
}

class _StatusCaptionEditorState extends State<_StatusCaptionEditor> {
  final _captionCtrl = TextEditingController();
  bool _isGenerating = false;
  bool _isPosting = false;

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateAiCaption() async {
    setState(() => _isGenerating = true);
    AppHaptics.lightTap();
    
    try {
      final caption = await AiService.generateCaption(
        context: 'A ${widget.type} shared as a status update',
        mood: 'fun and casual',
      );
      
      if (mounted) {
        _captionCtrl.text = caption;
        AppHaptics.success();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI Error: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _postStatus() async {
    setState(() => _isPosting = true);
    try {
      // NOTE: StatusService.postStatus method signature needs to be verified/updated
      // to accept a 'text' or 'caption' parameter if it doesn't already.
      // Currently, it accepts type, mediaUrl, auth, background gradient, etc.
      // the existing method only has type, mediaUrl, text, backgroundGradient, mood, moodAura
      await StatusService.postStatus(
        type: widget.type,
        mediaUrl: widget.mediaUrl,
        text: _captionCtrl.text.trim().isNotEmpty ? _captionCtrl.text.trim() : null,
      );

      if (mounted) {
        Navigator.pop(context); // Close editor
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status posted! 🎉'),
            backgroundColor: Color(0xFF1A2A40),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                if (_isPosting)
                  const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(color: AppColors.aquaCore, strokeWidth: 2),
                    ),
                  )
                else
                  TextButton(
                    onPressed: _postStatus,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.aquaCore,
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    child: const Text('Post'),
                  ),
              ],
            ),
            
            // Media Preview
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: widget.type == 'photo'
                      ? Image.network(widget.mediaUrl, fit: BoxFit.contain)
                      // A real app would use a video player here, but for simplicity we show a placeholder
                      : Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(color: Colors.white10),
                            const Icon(Icons.play_circle_fill, size: 64, color: Colors.white54),
                          ],
                        ),
                ),
              ),
            ),
            
            // Caption Input
            Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1628),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _captionCtrl,
                          style: const TextStyle(color: Colors.white),
                          maxLines: 4,
                          minLines: 1,
                          decoration: const InputDecoration(
                            hintText: 'Add a caption...',
                            hintStyle: TextStyle(color: Colors.white38),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      
                      // AI Generate Button
                      GestureDetector(
                        onTap: _isGenerating ? null : _generateAiCaption,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(left: 8, bottom: 4),
                          decoration: BoxDecoration(
                            gradient: AppColors.buttonGradient,
                            shape: BoxShape.circle,
                          ),
                          child: _isGenerating
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ─── Option Tile ──────────────────────────────────────────

class _OptionTile extends StatelessWidget {
  final IconData? icon;
  final String? emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionTile({
    this.icon,
    this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: emoji != null
          ? Text(emoji!, style: const TextStyle(fontSize: 24))
          : Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.aquaCore.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.aquaCore, size: 22),
            ),
      title: Text(title,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
      onTap: onTap,
    );
  }
}

// ─── Text Status Editor ───────────────────────────────────

class _TextStatusEditor extends StatefulWidget {
  const _TextStatusEditor();

  @override
  State<_TextStatusEditor> createState() => _TextStatusEditorState();
}

class _TextStatusEditorState extends State<_TextStatusEditor> {
  final _textController = TextEditingController();
  int _gradientIndex = 0;
  bool _isPosting = false;

  static const gradientPresets = [
    ['0EA5E9', '6366F1'], // Blue-Purple
    ['F59E0B', 'EF4444'], // Orange-Red
    ['10B981', '0EA5E9'], // Green-Blue
    ['8B5CF6', 'EC4899'], // Purple-Pink
    ['EF4444', 'F97316'], // Red-Orange
    ['0EA5E9', '22D3EE'], // Cyan-Teal
    ['6366F1', '8B5CF6'], // Indigo-Purple
    ['F59E0B', '10B981'], // Amber-Green
  ];

  @override
  Widget build(BuildContext context) {
    final colors = gradientPresets[_gradientIndex];
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors:
          colors.map((c) => Color(int.parse('FF$c', radix: 16))).toList(),
    );

    return Scaffold(
      body: GestureDetector(
        // Tap background to cycle gradient
        onTap: () {
          setState(() {
            _gradientIndex =
                (_gradientIndex + 1) % gradientPresets.length;
          });
        },
        child: Container(
          decoration: BoxDecoration(gradient: gradient),
          child: SafeArea(
            child: Stack(
              children: [
                // Text input centered
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: TextField(
                      controller: _textController,
                      textAlign: TextAlign.center,
                      maxLines: null,
                      maxLength: 500,
                      autofocus: true,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: _textController.text.length > 100
                            ? 20
                            : 28,
                        fontWeight: FontWeight.bold,
                        shadows: const [
                          Shadow(blurRadius: 8, color: Colors.black45),
                        ],
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Type a status...',
                        hintStyle: TextStyle(color: Colors.white60),
                        border: InputBorder.none,
                        counterStyle: TextStyle(color: Colors.white54),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),

                // Top bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        // Gradient indicator dots
                        Row(
                          children: List.generate(
                            gradientPresets.length,
                            (i) => Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 2),
                              width: i == _gradientIndex ? 10 : 6,
                              height: i == _gradientIndex ? 10 : 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == _gradientIndex
                                    ? Colors.white
                                    : Colors.white38,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Post button
                        TextButton(
                          onPressed: _textController.text.trim().isEmpty ||
                                  _isPosting
                              ? null
                              : _postTextStatus,
                          child: _isPosting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Post',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom hint
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      'Tap background to change color',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _postTextStatus() async {
    if (_textController.text.trim().isEmpty) return;

    setState(() => _isPosting = true);
    try {
      await StatusService.postStatus(
        type: 'text',
        text: _textController.text.trim(),
        gradientColors: gradientPresets[_gradientIndex],
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}

// ─── Mood Picker Sheet ────────────────────────────────────

class _MoodPickerSheet extends StatefulWidget {
  const _MoodPickerSheet();

  @override
  State<_MoodPickerSheet> createState() => _MoodPickerSheetState();
}

class _MoodPickerSheetState extends State<_MoodPickerSheet> {
  String? _selectedMood;
  final _textController = TextEditingController();
  bool _isPosting = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0A1628),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Set Your Mood',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Mood grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: MoodConfig.moods.entries.map((entry) {
                final key = entry.key;
                final config = entry.value;
                final isSelected = _selectedMood == key;
                final colors = MoodConfig.getColors(key);

                return GestureDetector(
                  onTap: () => setState(() => _selectedMood = key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: (MediaQuery.of(context).size.width - 56) / 3,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors[0].withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? Border.all(color: colors[0], width: 2)
                          : Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(config['emoji'] as String,
                            style: const TextStyle(fontSize: 36)),
                        const SizedBox(height: 8),
                        Text(
                          config['label'] as String,
                          style: TextStyle(
                            color: isSelected ? colors[0] : Colors.white70,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w400,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Optional text input (shows when mood selected)
          if (_selectedMood != null) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _textController,
                maxLength: 100,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "What's on your mind?",
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  counterStyle: const TextStyle(color: Colors.white38),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isPosting ? null : _postMoodStatus,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.aquaCore,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isPosting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Set ${MoodConfig.getLabel(_selectedMood!)} Mood',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ),
          ],

          SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
        ],
      ),
    );
  }

  Future<void> _postMoodStatus() async {
    if (_selectedMood == null) return;

    setState(() => _isPosting = true);
    try {
      await StatusService.postStatus(
        type: 'mood',
        mood: _selectedMood!,
        text: _textController.text.trim().isEmpty
            ? null
            : _textController.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set mood: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}
