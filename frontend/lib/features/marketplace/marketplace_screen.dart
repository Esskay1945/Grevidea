import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/responsive_wrapper.dart';
import '../../state/app_state.dart';

class MarketplaceScreen extends StatefulWidget {
  final AppState appState;

  const MarketplaceScreen({super.key, required this.appState});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  void _redeemReward(String title, int cost) {
    if (widget.appState.greenPoints >= cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.royalForest,
          content: Text(
            '✓ Successfully redeemed "$title" for $cost Green Points!',
            style: const TextStyle(color: AppColors.champagneGold, fontWeight: FontWeight.w600),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.coral,
          content: Text(
            'Insufficient Green Points. Complete daily challenges to earn more!',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rewards & Eco-Market'),
      ),
      body: ResponsiveWrapper(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Points Vault Hero Card ───────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: AppColors.royalForest,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.goldBorder, width: 1.2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Green Points Vault',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.champagneGold,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.stars_rounded, color: AppColors.champagneGold, size: 32),
                            const SizedBox(width: 8),
                            Text(
                              '${widget.appState.greenPoints}',
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Verified impact credits ready to redeem',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.champagneGold.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.champagneGold, width: 1),
                      ),
                      child: const Icon(Icons.redeem_rounded, color: AppColors.champagneGold, size: 28),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              Text(
                'Featured Impact Redemptions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.royalForest,
                ),
              ),
              const SizedBox(height: 14),

              _RewardCard(
                title: 'Plant a Native Neem Tree',
                partner: 'Grow-Trees Mumbai Urban Project',
                cost: 200,
                icon: Icons.park_rounded,
                onRedeem: () => _redeemReward('Plant a Native Neem Tree', 200),
              ),
              _RewardCard(
                title: '₹150 Organic Store Voucher',
                partner: 'Nature’s Basket Eco Partner',
                cost: 300,
                icon: Icons.storefront_rounded,
                onRedeem: () => _redeemReward('₹150 Organic Store Voucher', 300),
              ),
              _RewardCard(
                title: 'Recycled Hemp & Cotton Tote',
                partner: 'EcoVeda Circular Goods',
                cost: 450,
                icon: Icons.shopping_bag_outlined,
                onRedeem: () => _redeemReward('Recycled Hemp & Cotton Tote', 450),
              ),
              _RewardCard(
                title: 'Clean Energy Community Donation',
                partner: 'Solar For Wards Initiative',
                cost: 500,
                icon: Icons.solar_power_rounded,
                onRedeem: () => _redeemReward('Clean Energy Community Donation', 500),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  final String title;
  final String partner;
  final int cost;
  final IconData icon;
  final VoidCallback onRedeem;

  const _RewardCard({
    required this.title,
    required this.partner,
    required this.cost,
    required this.icon,
    required this.onRedeem,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.royalForest.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.champagneGold.withOpacity(0.5)),
            ),
            child: Icon(icon, color: AppColors.champagneGold, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(partner, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.stars_rounded, color: AppColors.champagneGold, size: 14),
                    const SizedBox(width: 4),
                    Text('$cost pts', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.champagneGold)),
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
            ),
            onPressed: onRedeem,
            child: const Text('Redeem', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
