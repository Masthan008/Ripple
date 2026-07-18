import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/env.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../shared/widgets/floating_particles.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/gift_card_model.dart';
import '../services/gift_service.dart';
import '../providers/gift_provider.dart';

/// Themed Gift Cards Screen - Digital gifts with glass-themed packaging and Razorpay checkouts
class GiftCardsScreen extends ConsumerStatefulWidget {
  const GiftCardsScreen({super.key});

  @override
  ConsumerState<GiftCardsScreen> createState() => _GiftCardsScreenState();
}

class _GiftCardsScreenState extends ConsumerState<GiftCardsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Razorpay _razorpay;
  
  String _selectedTheme = 'friendship';
  int _customAmount = 100;
  
  GiftCardModel? _purchasingCard;
  int _purchasingAmount = 100;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Initialize Razorpay SDK
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleGiftPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleGiftPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleGiftExternalWallet);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _razorpay.clear();
    super.dispose();
  }

  void _handleGiftPaymentSuccess(PaymentSuccessResponse response) async {
    if (_purchasingCard == null) return;
    
    setState(() => _isLoading = true);
    try {
      await GiftService.buyGiftCard(
        giftCardId: _purchasingCard!.id,
        title: _purchasingCard!.title,
        category: _purchasingCard!.theme,
        amount: _purchasingAmount,
        paymentId: response.paymentId ?? '',
        orderId: response.orderId ?? '',
        signature: response.signature ?? '',
      );
      
      AppHaptics.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gift Card "${_purchasingCard!.title}" purchased successfully! 🎁'),
            backgroundColor: AppColors.onlineGreen,
          ),
        );
        // Switch to My Inventory tab
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record purchase: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _purchasingCard = null;
        });
      }
    }
  }

  void _handleGiftPaymentError(PaymentFailureResponse response) {
    AppHaptics.heavyTap();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment Failed: ${response.message} (Code: ${response.code})'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
    setState(() {
      _purchasingCard = null;
    });
  }

  void _handleGiftExternalWallet(ExternalWalletResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('External Wallet Selected: ${response.walletName}'),
          backgroundColor: AppColors.aquaCore,
        ),
      );
    }
  }

  void _startGiftPurchaseFlow(GiftCardModel card, int amount) {
    _purchasingCard = card;
    _purchasingAmount = amount;
    
    final email = ref.read(currentUserProvider).value?.email ?? 'user@ripple.com';

    // Fetch Razorpay credentials
    final keyId = Env.razorpayKeyId;

    // Trigger simulator if key is missing/placeholder
    if (keyId.isEmpty || keyId.startsWith('YOUR_') || keyId == 'null') {
      _showMockPaymentDialog();
      return;
    }

    final options = {
      'key': keyId,
      'amount': amount * 100, // in paise
      'name': 'Ripple Gift Cards',
      'description': 'Purchase: ${card.title}',
      'prefill': {
        'contact': '9999999999',
        'email': email,
      },
      'external': {
        'wallets': ['paytm']
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Razorpay launch error: $e');
    }
  }

  void _showMockPaymentDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A1628),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Razorpay Simulator (Sandbox)', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Card: ${_purchasingCard!.title}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text('Amount: ₹$_purchasingAmount', style: const TextStyle(color: AppColors.aquaCore, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text(
              'Your Razorpay configuration key is not set in .env. We have activated sandbox simulation mode.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _purchasingCard = null;
              });
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.onlineGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _handleGiftPaymentSuccess(
                PaymentSuccessResponse(
                  'pay_mock_${DateTime.now().millisecondsSinceEpoch}',
                  'order_mock_${DateTime.now().millisecondsSinceEpoch}',
                  'sig_mock_${DateTime.now().millisecondsSinceEpoch}',
                  const {},
                ),
              );
            },
            child: const Text('Simulate Success', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      appBar: AppBar(
        title: Text('Digital Gift Cards', style: AppTextStyles.heading),
        backgroundColor: const Color(0xFF0A1628),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.aquaCore,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white30,
          tabs: const [
            Tab(text: 'Shop Cards'),
            Tab(text: 'My Inventory'),
            Tab(text: 'Activity'),
          ],
        ),
      ),
      body: Stack(
        children: [
          const FloatingParticles(particleCount: 2),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppColors.aquaCore),
              ),
            )
          else
            TabBarView(
              controller: _tabController,
              children: [
                _buildShopTab(),
                _buildInventoryTab(),
                _buildHistoryTab(),
              ],
            ),
        ],
      ),
    );
  }

  // ─── Tab 1: Shop View ────────────────────────────────────
  Widget _buildShopTab() {
    final giftCards = GiftCardThemes.defaultCards;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select Card Theme', style: AppTextStyles.headingSmall.copyWith(color: AppColors.aquaCore)),
          const SizedBox(height: 12),
          _ThemeSelector(
            selectedTheme: _selectedTheme,
            onThemeChanged: (theme) {
              setState(() => _selectedTheme = theme);
            },
          ),
          const SizedBox(height: 24),
          
          Text('Select Purchase Value', style: AppTextStyles.headingSmall.copyWith(color: AppColors.aquaCore)),
          const SizedBox(height: 12),
          _AmountSelector(
            amount: _customAmount,
            onAmountChanged: (amount) {
              setState(() => _customAmount = amount);
            },
          ),
          const SizedBox(height: 24),
          
          Text('Choose Designs', style: AppTextStyles.headingSmall.copyWith(color: AppColors.aquaCore)),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: giftCards.length,
            itemBuilder: (context, i) {
              final card = giftCards[i];
              // Overwrite default card values with chosen category/amount for customizable feel
              final currentCard = GiftCardModel(
                id: card.id,
                title: '${_selectedTheme.toUpperCase()} Gift',
                description: card.description,
                theme: _selectedTheme,
                amount: _customAmount,
              );
              
              return AnimationConfiguration.staggeredList(
                position: i,
                duration: const Duration(milliseconds: 300),
                child: SlideAnimation(
                  verticalOffset: 40,
                  child: FadeInAnimation(
                    child: _GiftCardCard(
                      giftCard: currentCard,
                      onTap: () => _showGiftPreview(currentCard),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── Tab 2: User Inventory ──────────────────────────────
  Widget _buildInventoryTab() {
    final ownedCardsAsync = ref.watch(purchasedGiftCardsProvider);
    return ownedCardsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.aquaCore)),
      ),
      error: (err, _) => Center(
        child: Text('Error loading inventory: $err', style: AppTextStyles.caption),
      ),
      data: (cards) {
        final filterCards = cards; // Show all for full visibility of status
        
        if (filterCards.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, color: Colors.white24, size: 64),
                const SizedBox(height: 16),
                Text('No gift cards in inventory', style: AppTextStyles.body.copyWith(color: Colors.white54)),
                const SizedBox(height: 8),
                Text('Buy cards in the shop tab to see them here.', style: AppTextStyles.caption.copyWith(color: Colors.white30)),
              ],
            ),
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: filterCards.length,
          itemBuilder: (context, index) {
            final card = filterCards[index];
            final themeStyle = GiftCardThemes.themeStyles[card.theme] ?? GiftCardThemes.themeStyles['custom']!;
            final colors = themeStyle['gradient'] as List<int>;
            
            // Checking fields in data map
            final isRedeemed = card.isRedeemed;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(colors[0]).withOpacity(0.25),
                    Color(colors[1]).withOpacity(0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Color(colors[0]).withOpacity(isRedeemed ? 0.1 : 0.4),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(themeStyle['emoji'], style: const TextStyle(fontSize: 28)),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(card.title, style: AppTextStyles.headingSmall.copyWith(fontSize: 16)),
                              const SizedBox(height: 2),
                              Text('Code: ${card.description}', style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'monospace')),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isRedeemed ? Colors.red.withOpacity(0.15) : AppColors.aquaCore.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isRedeemed ? 'Redeemed' : '₹${card.amount}',
                          style: TextStyle(
                            color: isRedeemed ? Colors.redAccent : AppColors.aquaCore,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  if (!isRedeemed) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white10,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: () => _redeemCard(card.id),
                            child: const Text('Redeem Code', style: TextStyle(fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.aquaCore,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: () => _showSendFriendSelector(card),
                            child: const Text('Send to Friend', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Redeem Action Helper
  void _redeemCard(String cardId) async {
    AppHaptics.selectionTick();
    setState(() => _isLoading = true);
    try {
      await GiftService.redeemPurchasedGiftCard(cardId);
      AppHaptics.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gift card claimed successfully! Points added to score.'), backgroundColor: AppColors.onlineGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Claim failed: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Friend Selector Bottom Sheet for Sending
  void _showSendFriendSelector(GiftCardModel card) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A1628),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final friendsAsync = ref.watch(giftFriendsProvider);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Send Gift Card to Friend', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const Divider(color: Colors.white12),
              Expanded(
                child: friendsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white54))),
                  data: (friends) {
                    if (friends.isEmpty) {
                      return const Center(child: Text('No active chat friends found.', style: TextStyle(color: Colors.white30)));
                    }
                    return ListView.builder(
                      itemCount: friends.length,
                      itemBuilder: (context, i) {
                        final friend = friends[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.aquaCore.withOpacity(0.2),
                            child: Text((friend['name'] as String)[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                          ),
                          title: Text(friend['name'] as String, style: const TextStyle(color: Colors.white)),
                          onTap: () async {
                            Navigator.pop(context);
                            _sendGiftToFriend(card.id, friend['uid'] as String, friend['name'] as String);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _sendGiftToFriend(String cardId, String friendId, String friendName) async {
    setState(() => _isLoading = true);
    try {
      await GiftService.sendPurchasedGiftCard(
        cardId: cardId,
        recipientId: friendId,
        recipientName: friendName,
      );
      AppHaptics.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gift Card sent to $friendName! 🎁'), backgroundColor: AppColors.onlineGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send card: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Tab 3: History View ──────────────────────────────────
  Widget _buildHistoryTab() {
    final sentAsync = ref.watch(sentGiftsProvider);
    final receivedAsync = ref.watch(receivedGiftsProvider);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Received Gifts
          Text('Received Gifts', style: AppTextStyles.headingSmall.copyWith(color: AppColors.aquaCore)),
          const SizedBox(height: 12),
          receivedAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e', style: AppTextStyles.caption),
            data: (gifts) {
              if (gifts.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('No gifts received yet.', style: TextStyle(color: Colors.white30, fontSize: 13)),
                );
              }
              return Column(
                children: gifts.map((gift) {
                  final themeStyle = GiftCardThemes.themeStyles[gift.theme] ?? GiftCardThemes.themeStyles['custom']!;
                  final isPending = gift.status == 'pending';
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(themeStyle['emoji'], style: const TextStyle(fontSize: 24)),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('From: ${gift.senderName}', style: const TextStyle(color: Colors.white, fontSize: 14)),
                                const SizedBox(height: 2),
                                Text('Value: ₹${gift.amount}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                        if (isPending)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.aquaCore,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () async {
                              AppHaptics.selectionTick();
                              await GiftService.claimGift(gift.giftId);
                              AppHaptics.success();
                            },
                            child: const Text('Claim', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          )
                        else
                          const Text('Claimed', style: TextStyle(color: Colors.white24, fontSize: 12)),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          
          const SizedBox(height: 24),
          
          // Sent Gifts
          Text('Sent Gifts', style: AppTextStyles.headingSmall.copyWith(color: AppColors.aquaCore)),
          const SizedBox(height: 12),
          sentAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e', style: AppTextStyles.caption),
            data: (gifts) {
              if (gifts.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('No gifts sent yet.', style: TextStyle(color: Colors.white30, fontSize: 13)),
                );
              }
              return Column(
                children: gifts.map((gift) {
                  final themeStyle = GiftCardThemes.themeStyles[gift.theme] ?? GiftCardThemes.themeStyles['custom']!;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(themeStyle['emoji'], style: const TextStyle(fontSize: 24)),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('To: ${gift.recipientName}', style: const TextStyle(color: Colors.white, fontSize: 14)),
                                const SizedBox(height: 2),
                                Text('Value: ₹${gift.amount}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                        Text(
                          gift.status.toUpperCase(),
                          style: TextStyle(
                            color: gift.status == 'claimed' ? AppColors.onlineGreen : Colors.amber,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showGiftPreview(GiftCardModel giftCard) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _GiftPreviewSheet(
        giftCard: giftCard,
        onBuyPressed: (card, amt) {
          Navigator.pop(context);
          _startGiftPurchaseFlow(card, amt);
        },
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────

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
                    Color(theme['gradient'][0]).withOpacity(0.3),
                    Color(theme['gradient'][1]).withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.white24,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(theme['emoji'], style: const TextStyle(fontSize: 20)),
                  const SizedBox(height: 4),
                  Text(
                    themeKey.toUpperCase(),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white54,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
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
              color: isSelected ? AppColors.aquaCore : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.aquaCore : Colors.white12,
              ),
            ),
            child: Text(
              '₹$amt',
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white70,
                fontSize: 14,
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
    final themeStyle = GiftCardThemes.themeStyles[giftCard.theme] ?? GiftCardThemes.themeStyles['custom']!;
    final colors = themeStyle['gradient'] as List<int>;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 100,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(colors[0]).withOpacity(0.3),
              Color(colors[1]).withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Color(colors[0]).withOpacity(0.4),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
              child: Center(
                child: Text(themeStyle['emoji'], style: const TextStyle(fontSize: 36)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(giftCard.title, style: AppTextStyles.headingSmall.copyWith(fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(giftCard.description, style: AppTextStyles.caption.copyWith(color: Colors.white38), maxLines: 1),
                    const SizedBox(height: 6),
                    Text(
                      '₹${giftCard.amount}',
                      style: const TextStyle(color: AppColors.aquaCore, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white24),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _GiftPreviewSheet extends StatelessWidget {
  final GiftCardModel giftCard;
  final Function(GiftCardModel, int) onBuyPressed;

  const _GiftPreviewSheet({
    required this.giftCard,
    required this.onBuyPressed,
  });

  @override
  Widget build(BuildContext context) {
    final themeStyle = GiftCardThemes.themeStyles[giftCard.theme] ?? GiftCardThemes.themeStyles['custom']!;
    final colors = themeStyle['gradient'] as List<int>;

    return Container(
      height: 380,
      decoration: BoxDecoration(
        color: const Color(0xFF0A1628).withOpacity(0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.aquaCyan.withOpacity(0.3), width: 1)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(colors[0]).withOpacity(0.4),
                    Color(colors[1]).withOpacity(0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Color(colors[0]).withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(themeStyle['emoji'], style: const TextStyle(fontSize: 48)),
                  const SizedBox(height: 8),
                  Text(giftCard.title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('₹${giftCard.amount}', style: const TextStyle(color: AppColors.aquaCore, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white30, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => onBuyPressed(giftCard, giftCard.amount),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Buy Gift Card', style: TextStyle(fontWeight: FontWeight.bold)),
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
