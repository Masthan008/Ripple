import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/floating_particles.dart';
import '../models/gift_card_model.dart';

/// Themed Gift Cards Screen - Digital gifts with glass-themed packaging
class GiftCardsScreen extends StatefulWidget {
  const GiftCardsScreen({super.key});

  @override
  State<GiftCardsScreen> createState() => _GiftCardsScreenState();
}

class _GiftCardsScreenState extends State<GiftCardsScreen> {
  String _selectedTheme = 'friendship';
  int _customAmount = 100;

  @override
  Widget build(BuildContext context) {
    final giftCards = GiftCardThemes.defaultCards;

    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      body: Stack(
        children: [
          const FloatingParticles(particleCount: 2),
          CustomScrollView(
            slivers: [
              // Header
              SliverAppBar(
                backgroundColor: const Color(0xFF0A1628),
                expandedHeight: 180,
                floating: false,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: const Text(
                    'Gift Cards',
                    style: TextStyle(color: Colors.white),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.aquaCore.withValues(alpha: 0.3),
                          AppColors.aquaCyan.withValues(alpha: 0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.card_giftcard,
                            color: Colors.pinkAccent,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Send Digital Gifts',
                            style: AppTextStyles.body.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Theme Selection
                      _sectionHeader('Choose Theme'),
                      const SizedBox(height: 12),
                      _ThemeSelector(
                        selectedTheme: _selectedTheme,
                        onThemeChanged: (theme) {
                          setState(() => _selectedTheme = theme);
                        },
                      ),
                      const SizedBox(height: 24),

                      // Custom Amount
                      _sectionHeader('Custom Amount'),
                      const SizedBox(height: 12),
                      _AmountSelector(
                        amount: _customAmount,
                        onAmountChanged: (amount) {
                          setState(() => _customAmount = amount);
                        },
                      ),
                      const SizedBox(height: 24),

                      // Available Gift Cards
                      _sectionHeader('Available Gift Cards'),
                      const SizedBox(height: 12),
                      ...giftCards.asMap().entries.map((entry) {
                        return AnimationConfiguration.staggeredList(
                          position: entry.key,
                          duration: const Duration(milliseconds: 300),
                          child: SlideAnimation(
                            verticalOffset: 50,
                            child: FadeInAnimation(
                              child: _GiftCardCard(
                                giftCard: entry.value,
                                onTap: () => _showGiftPreview(entry.value),
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Text(
        title,
        style: TextStyle(
          color: AppColors.aquaCore,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      );

  void _showGiftPreview(GiftCardModel giftCard) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _GiftPreviewSheet(giftCard: giftCard),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  final String selectedTheme;
  final Function(String) onThemeChanged;

  const _ThemeSelector({
    required this.selectedTheme,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final themes = GiftCardThemes.themeStyles;

    return Container(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: themes.length,
        itemBuilder: (context, index) {
          final themeKey = themes.keys.elementAt(index);
          final theme = themes[themeKey]!;
          final isSelected = selectedTheme == themeKey;

          return GestureDetector(
            onTap: () => onThemeChanged(themeKey),
            child: Container(
              width: 80,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(theme['gradient'][0]).withValues(alpha: 0.3),
                    Color(theme['gradient'][1]).withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.2),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    theme['emoji'],
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    themeKey,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white54,
                      fontSize: 10,
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

class _AmountSelector extends StatelessWidget {
  final int amount;
  final Function(int) onAmountChanged;

  const _AmountSelector({
    required this.amount,
    required this.onAmountChanged,
  });

  @override
  Widget build(BuildContext context) {
    final amounts = [50, 100, 150, 200, 500];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: amounts.map((amt) {
        final isSelected = amount == amt;
        return GestureDetector(
          onTap: () => onAmountChanged(amt),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.aquaCore
                  : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.aquaCore
                    : Colors.white.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              '$amt',
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _GiftCardCard extends StatelessWidget {
  final GiftCardModel giftCard;
  final VoidCallback onTap;

  const _GiftCardCard({
    required this.giftCard,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeStyle = GiftCardThemes.themeStyles[giftCard.theme]!;
    final gradientColors = themeStyle['gradient'] as List<int>;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 120,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(gradientColors[0]).withValues(alpha: 0.4),
              Color(gradientColors[1]).withValues(alpha: 0.2),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Color(gradientColors[0]).withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Color(gradientColors[0]).withValues(alpha: 0.2),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
              child: Center(
                child: Text(
                  themeStyle['emoji'],
                  style: const TextStyle(fontSize: 40),
                ),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      giftCard.title,
                      style: AppTextStyles.headingSmall.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      giftCard.description,
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white.withOpacity(0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${giftCard.amount} RP',
                        style: const TextStyle(
                          color: AppColors.aquaCore,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
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
  }
}

class _GiftPreviewSheet extends StatelessWidget {
  final GiftCardModel giftCard;

  const _GiftPreviewSheet({required this.giftCard});

  @override
  Widget build(BuildContext context) {
    final themeStyle = GiftCardThemes.themeStyles[giftCard.theme]!;
    final gradientColors = themeStyle['gradient'] as List<int>;

    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: const Color(0xFF0A1628).withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: AppColors.aquaCyan.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Preview Card
          Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(gradientColors[0]).withValues(alpha: 0.5),
                    Color(gradientColors[1]).withValues(alpha: 0.3),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Color(gradientColors[0]).withValues(alpha: 0.6),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    themeStyle['emoji'],
                    style: const TextStyle(fontSize: 64),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    giftCard.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${giftCard.amount} RP',
                    style: const TextStyle(
                      color: AppColors.aquaCore,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(
                        color: Colors.white38,
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final upiUrl = Uri.parse(
                        'upi://pay?pa=valli.ripple@okaxis'
                        '&pn=Ripple%20Chat'
                        '&am=${giftCard.amount}'
                        '&cu=INR'
                        '&tn=Ripple%20Gift%20Card%20-%20${Uri.encodeComponent(giftCard.title)}'
                      );
                      try {
                        if (await canLaunchUrl(upiUrl)) {
                          await launchUrl(upiUrl, mode: LaunchMode.externalApplication);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('UPI payment launched! 🎁'),
                                backgroundColor: AppColors.aquaCore,
                              ),
                            );
                          }
                        } else {
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Gift sent successfully! (Sandbox Simulation) 🎁'),
                                backgroundColor: AppColors.aquaCore,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Gift sent successfully! (Sandbox Simulation) 🎁'),
                              backgroundColor: AppColors.aquaCore,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Send Gift'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
