import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/word_thread_service.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../models/word_thread.dart';

/// Word Thread Overlay — Holographic Word-Threads™
///
/// A futuristic mini-chat overlay that spawns from a tapped word.
/// Features:
/// - 3D parallax "rift" effect with glowing border
/// - Mini message list with tiny bubbles
/// - Inline text input to reply
/// - "Dissolving into digital dust" countdown timer (24h)
/// - Auto-closes when user taps outside
class WordThreadOverlay extends StatefulWidget {
  final String chatId;
  final String messageId;
  final int wordIndex;
  final String word;
  final Offset anchorPosition; // Where the word is on screen
  final bool isGroup;
  final String currentUid;
  final String currentUserName;
  final VoidCallback onClose;

  const WordThreadOverlay({
    super.key,
    required this.chatId,
    required this.messageId,
    required this.wordIndex,
    required this.word,
    required this.anchorPosition,
    this.isGroup = false,
    required this.currentUid,
    required this.currentUserName,
    required this.onClose,
  });

  @override
  State<WordThreadOverlay> createState() => _WordThreadOverlayState();
}

class _WordThreadOverlayState extends State<WordThreadOverlay>
    with TickerProviderStateMixin {
  final _inputController = TextEditingController();
  late AnimationController _entryController;
  late AnimationController _glowController;

  WordThread? _thread;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _loadThread();
  }

  Future<void> _loadThread() async {
    try {
      final thread = await WordThreadService.instance.openThread(
        chatId: widget.chatId,
        messageId: widget.messageId,
        wordIndex: widget.wordIndex,
        word: widget.word,
        isGroup: widget.isGroup,
      );

      if (mounted) {
        setState(() {
          _thread = thread;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('🌌 Word thread load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendReply() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _thread == null) return;

    _inputController.clear();
    AppHaptics.lightTap();

    final miniMsg = MiniMessage(
      senderId: widget.currentUid,
      senderName: widget.currentUserName,
      text: text,
      createdAt: DateTime.now(),
    );

    setState(() {
      _thread = _thread!.addMessage(miniMsg);
    });

    await WordThreadService.instance.addMessage(
      chatId: widget.chatId,
      messageId: widget.messageId,
      wordIndex: widget.wordIndex,
      message: miniMsg,
      isGroup: widget.isGroup,
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _entryController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_entryController, _glowController]),
      builder: (context, _) {
        final entry = CurvedAnimation(
          parent: _entryController,
          curve: Curves.easeOutBack,
        ).value;
        final glow = _glowController.value;

        // Calculate overlay position near the tapped word
        final screenSize = MediaQuery.of(context).size;
        final overlayWidth = screenSize.width * 0.65;
        final overlayHeight = 280.0;

        double left = widget.anchorPosition.dx - overlayWidth / 2;
        left = left.clamp(12.0, screenSize.width - overlayWidth - 12);

        double top = widget.anchorPosition.dy - overlayHeight - 20;
        if (top < 80) top = widget.anchorPosition.dy + 30;

        return Stack(
          children: [
            // Backdrop (tap to close)
            GestureDetector(
              onTap: widget.onClose,
              child: Container(
                color: Colors.black.withOpacity(0.3 * entry),
              ),
            ),

            // Thread overlay
            Positioned(
              left: left,
              top: top,
              child: Transform.scale(
                scale: 0.5 + entry * 0.5,
                child: Opacity(
                  opacity: entry,
                  child: Container(
                    width: overlayWidth,
                    constraints: BoxConstraints(maxHeight: overlayHeight),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.aquaCore.withOpacity(0.2 + glow * 0.15),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.aquaCore.withOpacity(0.08 + glow * 0.06),
                          blurRadius: 20 + glow * 8,
                          spreadRadius: glow * 2,
                        ),
                        BoxShadow(
                          color: const Color(0xFF6366F1).withOpacity(0.05),
                          blurRadius: 30,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          color: const Color(0xFF0A1628).withOpacity(0.92),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildHeader(),
                              if (_isLoading)
                                const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.aquaCore,
                                    ),
                                  ),
                                )
                              else ...[
                                _buildMessageList(),
                                _buildInput(),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.aquaCore.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.word,
              style: const TextStyle(
                color: AppColors.aquaCore,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Word Thread',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          // Expiry timer
          if (_thread != null)
            Text(
              _formatTimeLeft(),
              style: TextStyle(
                color: Colors.white.withOpacity(0.25),
                fontSize: 9,
              ),
            ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: widget.onClose,
            child: Icon(
              Icons.close_rounded,
              size: 16,
              color: Colors.white.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    final messages = _thread?.messages ?? [];

    if (messages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Start a thread on "${widget.word}"',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 150),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        itemCount: messages.length,
        itemBuilder: (context, i) {
          final msg = messages[i];
          final isMe = msg.senderId == widget.currentUid;

          return Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isMe
                    ? AppColors.aquaCore.withOpacity(0.12)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isMe)
                    Text(
                      msg.senderName,
                      style: TextStyle(
                        fontSize: 8,
                        color: AppColors.aquaCore.withOpacity(0.6),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  Text(
                    msg.text,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Reply to "${widget.word}"...',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.2),
                  fontSize: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                isDense: true,
              ),
              onSubmitted: (_) => _sendReply(),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _sendReply,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.aquaCore.withOpacity(0.15),
              ),
              child: Icon(
                Icons.send_rounded,
                size: 14,
                color: AppColors.aquaCore,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeLeft() {
    if (_thread == null) return '';
    final diff = _thread!.expiresAt.difference(DateTime.now());
    if (diff.isNegative) return 'dissolving...';
    final hours = diff.inHours;
    final mins = diff.inMinutes % 60;
    return '${hours}h ${mins}m left';
  }
}
