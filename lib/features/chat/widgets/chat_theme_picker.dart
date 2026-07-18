import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/services/cloudinary_service.dart';
import '../services/chat_theme_service.dart';

/// Bottom sheet for selecting a per-chat background theme
class ChatThemePicker extends StatefulWidget {
  final String chatId;
  final ValueChanged<List<Color>?>? onThemeChanged;

  const ChatThemePicker({
    super.key,
    required this.chatId,
    this.onThemeChanged,
  });

  @override
  State<ChatThemePicker> createState() => _ChatThemePickerState();
}

class _ChatThemePickerState extends State<ChatThemePicker> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedGradientIndex = 0;
  int _selectedSolidIndex = -1;
  File? _pickedImageFile;
  String? _uploadedImageUrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCurrentTheme();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentTheme() async {
    final theme = await ChatThemeService.getTheme(widget.chatId);
    if (theme != null && mounted) {
      setState(() {
        if (theme.containsKey('imageUrl')) {
          _uploadedImageUrl = theme['imageUrl'] as String?;
          _tabController.index = 2;
        } else if (theme.containsKey('solidColor')) {
          final solidColor = theme['solidColor'] as String?;
          _selectedSolidIndex = ChatThemeService.solidColors.indexWhere((c) => c['color'] == solidColor);
          if (_selectedSolidIndex != -1) {
            _tabController.index = 1;
          }
        } else {
          final gradientColors = theme['gradientColors'] as List? ?? [];
          if (gradientColors.isNotEmpty) {
            final firstColor = gradientColors.first as String;
            _selectedGradientIndex = ChatThemeService.presets.indexWhere(
              (p) => (p['colors'] as List).first == firstColor,
            );
            if (_selectedGradientIndex == -1) _selectedGradientIndex = 0;
          }
        }
      });
    }
  }

  Future<void> _pickImage() async {
    AppHaptics.selectionTick();
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image != null) {
      setState(() {
        _pickedImageFile = File(image.path);
        _uploadedImageUrl = null;
      });
    }
  }

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

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text('Chat Wallpaper', style: AppTextStyles.heading.copyWith(fontSize: 18)),
                const Spacer(),
                if (_isSaving)
                  const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.aquaCore),
                  )
                else
                  GestureDetector(
                    onTap: _applyTheme,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: AppColors.buttonGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('Apply', style: AppTextStyles.label),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tab Bar
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.aquaCore,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            tabs: const [
              Tab(text: 'Gradients'),
              Tab(text: 'Solid Colors'),
              Tab(text: 'Custom Photo'),
            ],
          ),
          const SizedBox(height: 16),

          // Tab views
          SizedBox(
            height: 280,
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. Gradients Grid
                _buildGradientsGrid(),

                // 2. Solid Colors Grid
                _buildSolidsGrid(),

                // 3. Custom Photo Selector
                _buildCustomPhotoSelector(),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
        ],
      ),
    );
  }

  Widget _buildGradientsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.75,
        ),
        itemCount: ChatThemeService.presets.length,
        itemBuilder: (_, i) {
          final preset = ChatThemeService.presets[i];
          final colors = (preset['colors'] as List<String>)
              .map((c) => Color(int.parse('FF$c', radix: 16)))
              .toList();
          final accent = Color(int.parse('FF${preset['accent']}', radix: 16));
          final isSelected = _selectedGradientIndex == i;

          return GestureDetector(
            onTap: () {
              AppHaptics.selectionTick();
              setState(() {
                _selectedGradientIndex = i;
                _selectedSolidIndex = -1;
                _pickedImageFile = null;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: colors,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? accent : Colors.white12,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withOpacity(0.3),
                      border: Border.all(color: accent, width: 1.5),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    preset['name'] as String,
                    style: AppTextStyles.caption.copyWith(fontSize: 10, color: Colors.white70),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSolidsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.75,
        ),
        itemCount: ChatThemeService.solidColors.length,
        itemBuilder: (_, i) {
          final preset = ChatThemeService.solidColors[i];
          final color = Color(int.parse('FF${preset['color']}', radix: 16));
          final accent = Color(int.parse('FF${preset['accent']}', radix: 16));
          final isSelected = _selectedSolidIndex == i;

          return GestureDetector(
            onTap: () {
              AppHaptics.selectionTick();
              setState(() {
                _selectedSolidIndex = i;
                _selectedGradientIndex = -1;
                _pickedImageFile = null;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? accent : Colors.white12,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withOpacity(0.3),
                      border: Border.all(color: accent, width: 1.5),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    preset['name'] as String,
                    style: AppTextStyles.caption.copyWith(fontSize: 10, color: Colors.white70),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCustomPhotoSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Center(
        child: GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.glassBorder, width: 1),
            ),
            child: _pickedImageFile != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.file(
                      _pickedImageFile!,
                      fit: BoxFit.cover,
                    ),
                  )
                : _uploadedImageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.network(
                          _uploadedImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(),
                        ),
                      )
                    : _buildPlaceholder(),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.add_photo_alternate_outlined, color: AppColors.aquaCore, size: 40),
        const SizedBox(height: 12),
        Text('Choose photo from gallery', style: AppTextStyles.body.copyWith(color: Colors.white70)),
        const SizedBox(height: 4),
        Text('PNG/JPG backgrounds supported', style: AppTextStyles.caption.copyWith(color: Colors.white38)),
      ],
    );
  }

  Future<void> _applyTheme() async {
    setState(() => _isSaving = true);
    try {
      if (_tabController.index == 0) {
        // Gradient Theme
        final preset = ChatThemeService.presets[_selectedGradientIndex];
        final gradientStrs = List<String>.from(preset['colors'] as List);
        final appliedColors = gradientStrs
            .map((c) => Color(int.parse('FF$c', radix: 16)))
            .toList();

        await ChatThemeService.setTheme(
          chatId: widget.chatId,
          gradientColors: gradientStrs,
          accentColor: preset['accent'] as String,
          themePresetName: preset['name'] as String,
        );

        widget.onThemeChanged?.call(appliedColors);
      } else if (_tabController.index == 1) {
        // Solid Color Theme
        if (_selectedSolidIndex == -1) {
          throw 'Please select a solid color first';
        }
        final preset = ChatThemeService.solidColors[_selectedSolidIndex];
        final colorStr = preset['color'] as String;
        final appliedColors = [
          Color(int.parse('FF$colorStr', radix: 16)),
          Color(int.parse('FF$colorStr', radix: 16)),
        ];

        await ChatThemeService.setTheme(
          chatId: widget.chatId,
          gradientColors: [colorStr, colorStr],
          accentColor: preset['accent'] as String,
          solidColor: colorStr,
          themePresetName: preset['name'] as String,
        );

        widget.onThemeChanged?.call(appliedColors);
      } else if (_tabController.index == 2) {
        // Custom Image Theme
        String? finalImageUrl = _uploadedImageUrl;
        if (_pickedImageFile != null) {
          // Upload picked file to Cloudinary
          finalImageUrl = await CloudinaryService.uploadImage(_pickedImageFile!);
          if (finalImageUrl == null) throw 'Failed to upload image';
        }

        if (finalImageUrl == null) {
          throw 'Please choose a photo first';
        }

        await ChatThemeService.setTheme(
          chatId: widget.chatId,
          gradientColors: ['060D1A', '060D1A'], // Fallback dark gradient
          accentColor: '0EA5E9',
          imageUrl: finalImageUrl,
          themePresetName: 'Custom Photo',
        );

        widget.onThemeChanged?.call(null);
      }

      AppHaptics.success();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
