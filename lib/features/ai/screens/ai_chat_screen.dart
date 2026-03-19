import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/floating_particles.dart';
import '../../chat/widgets/glass_input_bar.dart';
import '../services/ai_bot_service.dart';
import '../../chat/models/message_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  final String botId;

  const AiChatScreen({super.key, required this.botId});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isTyping = false;

  // Local ephemeral state for the bot conversation
  // (In a real app, this might be saved to SQLite/Firestore)
  final List<MessageModel> _messages = [];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final bot = ref.read(aiBotServiceProvider).getBotById(widget.botId);
    if (bot == null) return;

    _messageController.clear();

    // Add user message
    final userMsg = MessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: 'user123', // hardcoded 'me' for this local view
      text: text,
      createdAt: DateTime.now(),
      type: 'text',
      seenBy: [],
      deletedFor: [],
      starredBy: [],
    );

    setState(() {
      _messages.add(userMsg);
      _isTyping = true;
    });
    _scrollToBottom();

    // Fetch bot response
    try {
      final responseText = await ref.read(aiBotServiceProvider).sendMessageToBot(
            bot: bot,
            prompt: text,
            chatHistory: List.from(_messages), // Pass history
          );

      final botMsg = MessageModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: bot.id,
        text: responseText,
        createdAt: DateTime.now(),
        type: 'text',
        seenBy: [],
        deletedFor: [],
        starredBy: [],
      );

      if (mounted) {
        setState(() {
          _messages.add(botMsg);
          _isTyping = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTyping = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bot failed to respond: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bot = ref.read(aiBotServiceProvider).getBotById(widget.botId);
    if (bot == null) return const Scaffold(body: Center(child: Text('Bot not found')));

    final color = Color(int.parse(bot.colorHex));

    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              alignment: Alignment.center,
              child: Text(bot.emoji, style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bot.name, style: AppTextStyles.heading),
                const Text('AI Companion', style: TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          const FloatingParticles(particleCount: 2),
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == _messages.length && _isTyping) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const SizedBox(
                            width: 30,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      );
                    }

                    final msg = _messages[i];
                    final isMe = msg.senderId != bot.id;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isMe
                              ? AppColors.aquaCore.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20).copyWith(
                            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(20),
                            bottomLeft: !isMe ? const Radius.circular(0) : const Radius.circular(20),
                          ),
                          border: Border.all(
                            color: isMe
                                ? AppColors.aquaCore.withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Text(
                          msg.text ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.3),
                        ),
                      ),
                    );
                  },
                ),
              ),
              GlassInputBar(
                controller: _messageController,
                onSend: _sendMessage,
                onAttach: () {},
                onEmoji: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}
