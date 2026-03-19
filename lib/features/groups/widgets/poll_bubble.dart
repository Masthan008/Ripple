import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/glass_theme.dart';
import '../models/poll_model.dart';
import '../../chat/models/message_model.dart';

class PollBubble extends StatelessWidget {
  final MessageModel message;
  final PollModel poll;
  final String currentUid;
  final bool isMe;
  final Function(String optionIndex) onVote;

  const PollBubble({
    super.key,
    required this.message,
    required this.poll,
    required this.currentUid,
    required this.isMe,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    final totalVotes = poll.totalVotes;
    final hasVoted = poll.hasVoted(currentUid);

    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: isMe
          ? GlassTheme.outgoingBubbleDecoration()
          : GlassTheme.incomingBubbleDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poll Question
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.poll_rounded, color: AppColors.aquaCore, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  poll.question,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Poll Options
          ...List.generate(poll.options.length, (index) {
            final optionText = poll.options[index];
            final optionKey = index.toString();
            final voters = poll.votes[optionKey] ?? [];
            final voteCount = voters.length;
            final percentage = totalVotes > 0 ? (voteCount / totalVotes) : 0.0;
            final didIVoteForThis = voters.contains(currentUid);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () {
                  if (!hasVoted) onVote(optionKey);
                },
                child: Stack(
                  children: [
                    // Background & Progress bar
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: didIVoteForThis
                              ? AppColors.aquaCore
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.fastOutSlowIn,
                            width: hasVoted
                                ? 260 * percentage // Approximate full width
                                : 0,
                            height: 40,
                            color: didIVoteForThis
                                ? AppColors.aquaCore.withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                    ),

                    // Option Text and Percentage
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      optionText,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: didIVoteForThis
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (didIVoteForThis) ...[
                                    const SizedBox(width: 6),
                                    const Icon(Icons.check_circle_rounded,
                                        color: AppColors.aquaCore, size: 14),
                                  ]
                                ],
                              ),
                            ),
                            if (hasVoted)
                              Text(
                                '${(percentage * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          // Footer (Total Votes)
          const SizedBox(height: 4),
          Text(
            '$totalVotes ${totalVotes == 1 ? 'vote' : 'votes'}',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
