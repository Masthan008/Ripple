import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class RippleDocScanner extends StatefulWidget {
  final String imagePath;

  const RippleDocScanner({super.key, required this.imagePath});

  @override
  State<RippleDocScanner> createState() => _RippleDocScannerState();
}

class _RippleDocScannerState extends State<RippleDocScanner> {
  final _boundaryKey = GlobalKey();
  
  // Crop points (normalized 0.0 to 1.0 coordinates)
  Offset _topLeft = const Offset(0.05, 0.05);
  Offset _topRight = const Offset(0.95, 0.05);
  Offset _bottomLeft = const Offset(0.05, 0.95);
  Offset _bottomRight = const Offset(0.95, 0.95);

  String _currentFilter = 'original'; // 'original', 'grayscale', 'monochrome'

  // Color matrices for filters
  static const List<double> _grayscaleMatrix = [
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0,      0,      0,      1, 0,
  ];

  static const List<double> _monochromeMatrix = [
    3.0 * 0.2126, 3.0 * 0.7152, 3.0 * 0.0722, 0, -255,
    3.0 * 0.2126, 3.0 * 0.7152, 3.0 * 0.0722, 0, -255,
    3.0 * 0.2126, 3.0 * 0.7152, 3.0 * 0.0722, 0, -255,
    0,            0,            0,            1, 0,
  ];

  Future<void> _saveScan() async {
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      // Capture filtered and cropped view
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();

      if (pngBytes == null) throw 'Failed to encode image';

      final tempDir = await getTemporaryDirectory();
      final scanFile = File('${tempDir.path}/scan_${DateTime.now().millisecondsSinceEpoch}.png');
      await scanFile.writeAsBytes(pngBytes);

      if (mounted) {
        Navigator.pop(context, scanFile.path);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save scan: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Adjust & Filter Document', style: AppTextStyles.headingSmall),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded, color: AppColors.aquaCore),
            onPressed: _saveScan,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;

                return Stack(
                  children: [
                    // Filtered image inside repaint boundary
                    Center(
                      child: RepaintBoundary(
                        key: _boundaryKey,
                        child: ClipPath(
                          clipper: _QuadClipper(
                            _topLeft,
                            _topRight,
                            _bottomLeft,
                            _bottomRight,
                            width,
                            height,
                          ),
                          child: ColorFiltered(
                            colorFilter: _currentFilter == 'grayscale'
                                ? const ColorFilter.matrix(_grayscaleMatrix)
                                : _currentFilter == 'monochrome'
                                    ? const ColorFilter.matrix(_monochromeMatrix)
                                    : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                            child: Image.file(
                              File(widget.imagePath),
                              fit: BoxFit.contain,
                              width: width,
                              height: height,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Interactive Crop handles
                    _buildHandle(
                      _topLeft,
                      width,
                      height,
                      (newOffset) => setState(() => _topLeft = newOffset),
                    ),
                    _buildHandle(
                      _topRight,
                      width,
                      height,
                      (newOffset) => setState(() => _topRight = newOffset),
                    ),
                    _buildHandle(
                      _bottomLeft,
                      width,
                      height,
                      (newOffset) => setState(() => _bottomLeft = newOffset),
                    ),
                    _buildHandle(
                      _bottomRight,
                      width,
                      height,
                      (newOffset) => setState(() => _bottomRight = newOffset),
                    ),
                  ],
                );
              },
            ),
          ),

          // Filters selector bottom bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            color: const Color(0xFF070E17),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildFilterButton('original', 'Original', Icons.photo_outlined),
                _buildFilterButton('grayscale', 'Grayscale', Icons.filter_b_and_w_outlined),
                _buildFilterButton('monochrome', 'Monochrome Scan', Icons.document_scanner_outlined),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String type, String label, IconData icon) {
    final active = _currentFilter == type;
    return GestureDetector(
      onTap: () => setState(() => _currentFilter = type),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: active ? AppColors.aquaCore.withOpacity(0.15) : Colors.transparent,
              border: Border.all(
                color: active ? AppColors.aquaCore : Colors.white10,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: active ? AppColors.aquaCore : Colors.white54, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: active ? AppColors.aquaCore : Colors.white54,
              fontSize: 11,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle(Offset position, double width, double height, Function(Offset) onUpdate) {
    return Positioned(
      left: position.dx * width - 18,
      top: position.dy * height - 18,
      child: GestureDetector(
        onPanUpdate: (details) {
          final x = (position.dx + details.delta.dx / width).clamp(0.0, 1.0);
          final y = (position.dy + details.delta.dy / height).clamp(0.0, 1.0);
          onUpdate(Offset(x, y));
        },
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.aquaCore.withOpacity(0.3),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.aquaCore, width: 2),
          ),
          child: const Center(
            child: Icon(Icons.crop_free_rounded, color: Colors.white, size: 14),
          ),
        ),
      ),
    );
  }
}

class _QuadClipper extends CustomClipper<Path> {
  final Offset tl;
  final Offset tr;
  final Offset bl;
  final Offset br;
  final double width;
  final double height;

  _QuadClipper(this.tl, this.tr, this.bl, this.br, this.width, this.height);

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(tl.dx * width, tl.dy * height);
    path.lineTo(tr.dx * width, tr.dy * height);
    path.lineTo(br.dx * width, br.dy * height);
    path.lineTo(bl.dx * width, bl.dy * height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_QuadClipper oldClipper) => true;
}
