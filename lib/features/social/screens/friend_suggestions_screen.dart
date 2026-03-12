import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/aqua_avatar.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../friends/providers/friends_provider.dart';
import '../services/social_service.dart';
import 'package:go_router/go_router.dart';

class FriendSuggestionsScreen extends ConsumerStatefulWidget {
  const FriendSuggestionsScreen({super.key});

  @override
  ConsumerState<FriendSuggestionsScreen> createState() => _FriendSuggestionsScreenState();
}

class _FriendSuggestionsScreenState extends ConsumerState<FriendSuggestionsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    try {
      _suggestions = await SocialService.getFriendSuggestions();
    } catch (e) {
      debugPrint('Suggestions error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addFriend(String targetUid) async {
    try {
      await ref.read(friendsServiceProvider).sendFriendRequest(targetUid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request sent!'), backgroundColor: AppColors.aquaCore),
        );
        setState(() {
          _suggestions.removeWhere((s) => s['uid'] == targetUid);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      appBar: AppBar(
        title: Text('People You May Know', style: AppTextStyles.headingSmall),
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.aquaCore))
          : _suggestions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline_rounded, size: 60, color: Colors.white24),
                      const SizedBox(height: 16),
                      Text('No suggestions right now.', style: AppTextStyles.body),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final user = _suggestions[index];
                    final mutualCount = user['mutualCount'] as int? ?? 0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassCard(
                        borderRadius: 16,
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => context.push('/other-profile?uid=${user['uid']}'),
                              child: AquaAvatar(
                                imageUrl: user['photoUrl'] as String?,
                                name: user['name'] as String? ?? 'User',
                                size: 50,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user['name'] as String? ?? 'User',
                                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  if (mutualCount > 0)
                                    Text(
                                      '$mutualCount mutual friends',
                                      style: AppTextStyles.caption.copyWith(color: AppColors.aquaCore),
                                    )
                                  else
                                    Text(
                                      'Suggested for you',
                                      style: AppTextStyles.caption,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _addFriend(user['uid']),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: AppColors.buttonGradient,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Add Friend',
                                  style: AppTextStyles.caption.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
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
}
