import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_provider.dart';

class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key});

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();

  static const _faqs = [
    {
      'q': 'How does end-to-end encryption work in Ripple?',
      'a': 'Every chat session uses the Signal Double Ratchet protocol with ephemeral Curve25519 keys. Only you and your recipient possess the keys; no servers or intermediaries can decrypt messages or media.',
      'category': 'Security & Keys',
    },
    {
      'q': 'How do I add friends on Ripple?',
      'a': 'Navigate to Discover People from the home screen and tap "Add Friend" on any user. You can also share your personal username or invite link.',
      'category': 'Chat & Media',
    },
    {
      'q': 'Can I use Ripple without cellular or internet data?',
      'a': 'Yes! Ripple includes an Offline Mesh Protocol. If both devices are nearby, Ripple automatically establishes peer-to-peer Bluetooth LE and Wi-Fi Direct hops to deliver encrypted messages with zero internet.',
      'category': 'Devices & Sync',
    },
    {
      'q': 'How do I link Ripple Web on my computer?',
      'a': 'Open Ripple Web on your browser (or desktop). On your phone, go to Settings → Linked Devices → Link New Device and scan the displayed QR code.',
      'category': 'Devices & Sync',
    },
    {
      'q': 'How do I create an encrypted group or channel?',
      'a': 'From the Chats tab, tap the "+" button and select "Create Group". Choose participants from your friends list and assign a group title. All group messages are end-to-end encrypted.',
      'category': 'Groups & Calls',
    },
    {
      'q': 'How do I make secure voice and video calls?',
      'a': 'Open any direct conversation and tap the Phone or Video Camera icon in the header. Calls use WebRTC peer-to-peer transport with HD audio and noise suppression.',
      'category': 'Groups & Calls',
    },
    {
      'q': 'How do I switch between multiple accounts?',
      'a': 'Open your Profile tab and tap the chevron next to your name or tap "Switch Account". You can add multiple accounts and toggle between them instantly without logging out.',
      'category': 'Account & Plan',
    },
    {
      'q': 'How do I permanently delete my Ripple account?',
      'a': 'Go to Profile → Account Security → Delete Account. All cryptographic identity keys, cloud backups, and profile data will be permanently wiped across our servers.',
      'category': 'Account & Plan',
    },
  ];

  final List<String> _categories = [
    'All',
    'Chat & Media',
    'Security & Keys',
    'Groups & Calls',
    'Devices & Sync',
    'Account & Plan',
  ];

  List<Map<String, String>> get _filteredFaqs {
    return _faqs.where((faq) {
      final matchesCategory = _selectedCategory == 'All' || faq['category'] == _selectedCategory;
      final qMatches = faq['q']!.toLowerCase().contains(_searchQuery.toLowerCase());
      final aMatches = faq['a']!.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && (qMatches || aMatches);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _contactSupport() async {
    final uri = Uri.parse('mailto:support@ripple.app?subject=Ripple%20Support%20Request&body=Please%20describe%20your%20issue:');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Support contact: support@ripple.app')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(rippleThemeProvider);
    final isDark = theme.isDark;

    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? Colors.white60 : const Color(0xFF64748B);
    final cardBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.85);
    final cardBorder = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFE2E8F0);

    final filtered = _filteredFaqs;

    return Scaffold(
      backgroundColor: theme.colors.background,
      appBar: AppBar(
        title: Text(
          'Help & FAQ',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Input Field
            Container(
              height: 46,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cardBorder, width: 1),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: textColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search answers, security, mesh...',
                  hintStyle: TextStyle(color: textMuted, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.aquaCore, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, color: textMuted, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),
            ),
            const SizedBox(height: 14),

            // Horizontal Category Filter Chips
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _categories.length,
                itemBuilder: (context, idx) {
                  final cat = _categories[idx];
                  final isSel = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel ? AppColors.aquaCore : cardBg,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSel ? AppColors.aquaCore : cardBorder,
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            cat,
                            style: TextStyle(
                              color: isSel ? Colors.black : textColor,
                              fontSize: 12,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 22),

            // Section Title
            Text(
              'FREQUENTLY ASKED QUESTIONS',
              style: TextStyle(
                color: AppColors.aquaCore,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),

            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.search_off_rounded, color: textMuted, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'No matching questions found',
                        style: TextStyle(color: textMuted, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            else
              AnimationLimiter(
                key: ValueKey('$_selectedCategory-$_searchQuery'),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final faq = filtered[index];
                    return AnimationConfiguration.staggeredList(
                      position: index,
                      duration: const Duration(milliseconds: 350),
                      child: SlideAnimation(
                        verticalOffset: 30,
                        curve: Curves.easeOutCubic,
                        child: FadeInAnimation(
                          child: Container(
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: cardBorder, width: 0.8),
                            ),
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                dividerColor: Colors.transparent,
                              ),
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                iconColor: AppColors.aquaCore,
                                collapsedIconColor: textMuted,
                                title: Text(
                                  faq['q']!,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                children: [
                                  Text(
                                    faq['a']!,
                                    style: TextStyle(
                                      color: textMuted,
                                      fontSize: 12.5,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 24),

            // Still need help card
            Text(
              'CONTACT & SUPPORT',
              style: TextStyle(
                color: const Color(0xFF38BDF8),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),

            InkWell(
              onTap: _contactSupport,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: cardBorder, width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.aquaCore.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.mail_outline_rounded, color: AppColors.aquaCore, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Email Direct Support',
                            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Reach our security and protocol engineering team',
                            style: TextStyle(color: textMuted, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, color: textMuted, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
