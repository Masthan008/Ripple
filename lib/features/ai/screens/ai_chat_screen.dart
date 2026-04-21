import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../shared/widgets/floating_particles.dart';
import '../../chat/widgets/glass_input_bar.dart';
import '../services/ai_bot_service.dart';
import '../../chat/models/message_model.dart';

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
        final theme = ref.read(rippleThemeProvider);
        setState(() => _isTyping = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bot failed to respond: $e'),
            backgroundColor: theme.colors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(rippleThemeProvider);
    final bot = ref.read(aiBotServiceProvider).getBotById(widget.botId);
    if (bot == null) return const Scaffold(body: Center(child: Text('Bot not found')));

    final color = Color(int.parse(bot.colorHex));

    return Scaffold(
      backgroundColor: theme.colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
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
                Text(bot.name, style: AppTextStyles.heading.copyWith(
                  color: theme.colors.textPrimary,
                )),
                Text('AI Companion', style: TextStyle(
                  color: theme.colors.textMuted, fontSize: 11,
                )),
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
                            color: theme.colors.glassSurface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: theme.colors.glassBorder),
                          ),
                          child: SizedBox(
                            width: 30,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colors.textMuted,
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
                              ? theme.colors.primary.withValues(alpha: 0.2)
                              : theme.colors.glassSurface,
                          borderRadius: BorderRadius.circular(20).copyWith(
                            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(20),
                            bottomLeft: !isMe ? const Radius.circular(0) : const Radius.circular(20),
                          ),
                          border: Border.all(
                            color: isMe
                                ? theme.colors.primary.withValues(alpha: 0.3)
                                : theme.colors.glassBorder,
                          ),
                        ),
                        child: Text(
                          msg.text ?? '',
                          style: TextStyle(
                            color: theme.colors.textPrimary,
                            fontSize: 15,
                            height: 1.3,
                          ),
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
