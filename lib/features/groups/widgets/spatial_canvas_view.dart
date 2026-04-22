import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/firebase_service.dart';
import '../../../shared/widgets/aqua_avatar.dart';
import '../../chat/models/message_model.dart';

/// Spatial Threads™ — Infinite Canvas Mode for Group Chats
/// Breaks the vertical list paradigm. Users can drag and drop message
/// bubbles onto a 2D canvas for brainstorming and non-linear conversation.

class SpatialCanvasView extends ConsumerStatefulWidget {
  final String groupId;
  final List<MessageModel> messages;
  final String currentUid;
  final Map<String, String> memberNames;
  final Map<String, String> memberPhotos;

  const SpatialCanvasView({
    super.key,
    required this.groupId,
    required this.messages,
    required this.currentUid,
    required this.memberNames,
    required this.memberPhotos,
  });

  @override
  ConsumerState<SpatialCanvasView> createState() => _SpatialCanvasViewState();
}

class _SpatialCanvasViewState extends ConsumerState<SpatialCanvasView> {
  final TransformationController _transformController = TransformationController();
  final Map<String, Offset> _positions = {};
  final _random = Random();
  String? _draggingId;

  @override
  void initState() {
    super.initState();
    _initializePositions();
  }

  void _initializePositions() {
    for (int i = 0; i < widget.messages.length; i++) {
      final msg = widget.messages[i];
      if (!_positions.containsKey(msg.id)) {
        // Arrange in a spiral pattern by default
        final angle = i * 0.8;
        final radius = 80.0 + i * 35.0;
        _positions[msg.id] = Offset(
          400 + radius * cos(angle),
          400 + radius * sin(angle),
        );
      }
    }
  }

  @override
  void didUpdateWidget(SpatialCanvasView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != oldWidget.messages.length) {
      _initializePositions();
    }
  }

  void _savePosition(String messageId, Offset position) {
    // Save canvas position to Firestore so other members see the same layout
    FirebaseService.firestore
        .collection('groups')
        .doc(widget.groupId)
        .collection('messages')
        .doc(messageId)
        .update({
      'canvasX': position.dx,
      'canvasY': position.dy,
    }).catchError((_) {});
  }

  Color _getSenderColor(String senderId) {
    final hash = senderId.hashCode;
    final colors = [
      const Color(0xFF0EA5E9),
      const Color(0xFF6366F1),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF14B8A6),
    ];
    return colors[hash.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Canvas with pan & zoom
        InteractiveViewer(
          transformationController: _transformController,
          boundaryMargin: const EdgeInsets.all(2000),
          minScale: 0.3,
          maxScale: 3.0,
          child: SizedBox(
            width: 3000,
            height: 3000,
            child: CustomPaint(
              painter: _GridPainter(),
              child: Stack(
                children: [
                  // Connection lines between sequential messages
                  ...List.generate(
                    widget.messages.length > 1 ? widget.messages.length - 1 : 0,
                    (i) {
                      final from = _positions[widget.messages[i].id];
                      final to = _positions[widget.messages[i + 1].id];
                      if (from == null || to == null) return const SizedBox.shrink();
                      return CustomPaint(
                        painter: _LinePainter(from: from, to: to),
                        size: const Size(3000, 3000),
                      );
                    },
                  ),

                  // Message nodes
                  ...widget.messages.map((msg) {
                    final pos = _positions[msg.id] ?? Offset.zero;
                    final senderColor = _getSenderColor(msg.senderId);
                    final isMe = msg.senderId == widget.currentUid;

                    return Positioned(
                      left: pos.dx,
                      top: pos.dy,
                      child: GestureDetector(
                        onPanStart: (_) => _draggingId = msg.id,
                        onPanUpdate: (details) {
                          if (_draggingId == msg.id) {
                            final scale = _transformController.value.getMaxScaleOnAxis();
                            setState(() {
                              _positions[msg.id] = Offset(
                                pos.dx + details.delta.dx / scale,
                                pos.dy + details.delta.dy / scale,
                              );
                            });
                          }
                        },
                        onPanEnd: (_) {
                          _savePosition(msg.id, _positions[msg.id]!);
                          _draggingId = null;
                        },
                        child: _CanvasNode(
                          message: msg,
                          senderColor: senderColor,
                          isMe: isMe,
                          senderName: widget.memberNames[msg.senderId] ?? 'Unknown',
                          senderPhoto: widget.memberPhotos[msg.senderId],
                          isDragging: _draggingId == msg.id,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),

        // Canvas controls overlay
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CanvasControl(
                icon: Icons.center_focus_strong_rounded,
                onTap: () {
                  _transformController.value = Matrix4.identity();
                },
              ),
              const SizedBox(height: 8),
              _CanvasControl(
                icon: Icons.zoom_in_rounded,
                onTap: () {
                  final current = _transformController.value.clone();
                  current.scale(1.2);
                  _transformController.value = current;
                },
              ),
              const SizedBox(height: 8),
              _CanvasControl(
                icon: Icons.zoom_out_rounded,
                onTap: () {
                  final current = _transformController.value.clone();
                  current.scale(0.8);
                  _transformController.value = current;
                },
              ),
            ],
          ),
        ),

        // Canvas mode indicator
        Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.dashboard_rounded, size: 14, color: Color(0xFF6366F1)),
                  SizedBox(width: 6),
                  Text(
                    'SPATIAL THREADS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }
}

class _CanvasNode extends StatelessWidget {
  final MessageModel message;
  final Color senderColor;
  final bool isMe;
  final String senderName;
  final String? senderPhoto;
  final bool isDragging;

  const _CanvasNode({
    required this.message,
    required this.senderColor,
    required this.isMe,
    required this.senderName,
    this.senderPhoto,
    this.isDragging = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isDragging ? 1.1 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220, minWidth: 80),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: senderColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: senderColor.withOpacity(isDragging ? 0.8 : 0.3),
            width: isDragging ? 2 : 1,
          ),
          boxShadow: [
            if (isDragging)
              BoxShadow(
                color: senderColor.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sender row
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AquaAvatar(
                  imageUrl: senderPhoto,
                  name: senderName,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    senderName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: senderColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Message content
            if (message.text != null && message.text!.isNotEmpty)
              Text(
                message.text!,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  height: 1.3,
                ),
              )
            else if (message.type == 'image')
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.image_rounded, size: 16, color: senderColor),
                  const SizedBox(width: 4),
                  const Text('Photo', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.attachment_rounded, size: 16, color: senderColor),
                  const SizedBox(width: 4),
                  Text(message.type, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _CanvasControl extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CanvasControl({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white70, size: 20),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 0.5;

    const step = 60.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LinePainter extends CustomPainter {
  final Offset from;
  final Offset to;

  _LinePainter({required this.from, required this.to});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Offset to center of node (approximate)
    final fromCenter = from + const Offset(110, 30);
    final toCenter = to + const Offset(110, 30);

    canvas.drawLine(fromCenter, toCenter, paint);
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) =>
      from != oldDelegate.from || to != oldDelegate.to;
}
