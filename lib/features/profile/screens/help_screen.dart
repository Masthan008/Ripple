import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/glass_card.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';

  static const _faqs = [
    {
      'q': 'How do I add friends?',
      'a': 'Go to Discover People from the home screen and tap "Add Friend" on any user. They will receive a friend request that they can accept.',
      'category': 'Social',
    },
    {
      'q': 'How do I create a group?',
      'a': 'Tap the group icon on the home screen and select "Create Group". Add members from your friends list and give your group a name.',
      'category': 'Groups',
    },
    {
      'q': 'How do I make a video call?',
      'a': 'Open a chat with a friend and tap the video camera icon in the top right. Both users need an active internet connection for video calls.',
      'category': 'Chat',
    },
    {
      'q': 'How do I send files and documents?',
      'a': 'In any chat, tap the attachment icon (📎) next to the message input. You can share photos, videos, and documents from your device.',
      'category': 'Chat',
    },
    {
      'q': 'How do I block someone?',
      'a': 'Go to the user\'s profile or find them in Discover People. Tap the three-dot menu and select "Block". They won\'t be able to message you.',
      'category': 'Security',
    },
    {
      'q': 'How do I delete my account?',
      'a': 'Go to Profile → Account Security. Scroll to the bottom and tap "Delete Account". This action is permanent and cannot be undone.',
      'category': 'Security',
    },
  ];

  final List<String> _categories = ['All', 'Chat', 'Social', 'Groups', 'Security'];

  List<Map<String, String>> get _filteredFaqs {
    return _faqs.where((faq) {
      final matchesCategory = _selectedCategory == 'All' || faq['category'] == _selectedCategory;
      final matchesSearch = faq['q']!.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          faq['a']!.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredFaqs;

    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      appBar: AppBar(
        title: Text('Help & FAQ', style: AppTextStyles.heading),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.aquaCore),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Input Field
            TextField(
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search FAQ...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                prefixIcon: const Icon(Icons.search, color: AppColors.aquaCore),
                fillColor: Colors.white.withOpacity(0.04),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.aquaCore),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
            const SizedBox(height: 16),

            // Category filter chips list
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, idx) {
                  final cat = _categories[idx];
                  final isSel = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSel,
                      label: Text(
                        cat,
                        style: TextStyle(
                          color: isSel ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = cat;
                        });
                      },
                      selectedColor: AppColors.aquaCore,
                      backgroundColor: Colors.white.withOpacity(0.04),
                      checkmarkColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSel ? AppColors.aquaCore : Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            _sectionHeader('Frequently Asked Questions'),
            const SizedBox(height: 8),

            if (filtered.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.help_outline_outlined, color: AppColors.textMuted, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'No FAQs found matching your criteria.',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              )
            else
              AnimationLimiter(
                key: ValueKey('$_selectedCategory-$_searchQuery'),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final faq = filtered[index];
                    return AnimationConfiguration.staggeredList(
                      position: index,
                      duration: const Duration(milliseconds: 375),
                      child: SlideAnimation(
                        verticalOffset: 50.0,
                        child: FadeInAnimation(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: GlassCard(
                              borderRadius: 14,
                              padding: EdgeInsets.zero,
                              child: Theme(
                                data: ThemeData(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  iconColor: AppColors.aquaCore,
                                  collapsedIconColor: AppColors.textMuted,
                                  title: Text(
                                    faq['q']!,
                                    style: AppTextStyles.body.copyWith(fontSize: 14),
                                  ),
                                  children: [
                                    Text(
                                      faq['a']!,
                                      style: AppTextStyles.caption.copyWith(
                                        fontSize: 12,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 20),

            _sectionHeader('Need More Help?'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final uri = Uri.parse(
                  'mailto:support@ripple.app?subject=Bug%20Report&body=Describe%20your%20issue%20here',
                );
                try {
                  await launchUrl(uri);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Could not open email app'),
                        backgroundColor: AppColors.errorRed,
                      ),
                    );
                  }
                }
              },
              child: GlassCard(
                borderRadius: 14,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    Icon(Icons.email_outlined, color: AppColors.aquaCore, size: 22),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Report an Issue',
                              style: AppTextStyles.body.copyWith(fontSize: 14)),
                          Text('Send us an email',
                              style: AppTextStyles.caption.copyWith(fontSize: 11)),
                        ],
                      ),
                    ),
                    Icon(Icons.open_in_new_rounded,
                        color: AppColors.textMuted, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) => Text(
        title.toUpperCase(),
        style: AppTextStyles.caption.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: AppColors.aquaCore.withValues(alpha: 0.7),
        ),
      );
}
