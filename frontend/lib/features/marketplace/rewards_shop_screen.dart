import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/grevidea_app_bar.dart';
import '../../core/widgets/feature_directory_drawer.dart';
import '../../core/models/plant_record.dart';
import '../../state/app_state.dart';
import '../community/nearby_board_screen.dart';

class RewardsShopScreen extends StatefulWidget {
  final AppState appState;
  const RewardsShopScreen({super.key, required this.appState});

  @override
  State<RewardsShopScreen> createState() => _RewardsShopScreenState();
}

class _RewardsShopScreenState extends State<RewardsShopScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> get _rewards => [
    {
      'id': 'plant_tree',
      'title': 'Plant a Tree',
      'cost': 100,
      'subtitle': 'Sapling redemption · fulfillment pending',
      'icon': Icons.park_rounded,
      'color': AppColors.leafOf(context),
      'requires_photo': true,
    },
    {
      'id': 'eco_merchandise',
      'title': 'Eco Merchandise',
      'cost': 400,
      'subtitle':
          'Certified organic cotton tote & copper flask (Proof required)',
      'icon': Icons.checkroom_rounded,
      'color': AppColors.sapphire,
      'requires_photo': true,
    },
    {
      'id': 'donate_ngo',
      'title': 'Donate to NGO',
      'cost': 250,
      'subtitle': 'Green Yatra Thane urban afforestation fund (Receipt proof)',
      'icon': Icons.volunteer_activism_rounded,
      'color': AppColors.coral,
      'requires_photo': true,
    },
  ];

  // Plant Growth Tracker Records (Dynamic, user-persisted, completely empty [] for new users)
  List<PlantGrowthRecord> get _plants => widget.appState.plants;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _redeeming = false;
  Future<void> _handleRewardTap(Map<String, dynamic> item) async {
    if (_redeeming) return;
    final address = TextEditingController(), phone = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item['title']),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Redeem for ${item['cost']} Green Points? Confirmation depends on the fulfillment provider.',
              ),
              if (item['id'] == 'eco_merchandise') ...[
                TextField(
                  controller: address,
                  decoration: const InputDecoration(
                    labelText: 'Delivery address',
                  ),
                ),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone with country code (optional)',
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Redeem'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      address.dispose();
      phone.dispose();
      return;
    }
    _redeeming = true;
    final result = await widget.appState.api.request(
      '/api/v1/rewards/redeem',
      data: {
        'reward_id': item['id'],
        if (address.text.trim().isNotEmpty)
          'delivery_address': address.text.trim(),
        if (phone.text.trim().isNotEmpty) 'phone': phone.text.trim(),
      },
    );
    address.dispose();
    phone.dispose();
    _redeeming = false;
    if (!mounted) return;
    if (result != null) {
      widget.appState.setVerifiedPoints((result['balance'] as num).toInt());
      setState(() {});
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == null
              ? 'Reward not redeemed. Check your connection, sign-in and verified point balance.'
              : 'Redemption recorded: ${result['id']}. Fulfillment pending.',
        ),
      ),
    );
  }

  void _showPlantTreeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.camera_alt_rounded,
              color: AppColors.leafOf(context),
              size: 24,
            ),
            SizedBox(width: 8),
            Text(
              'Plant a Tree Verification',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Record a sapling for your personal journal. Photo verification requires a partner integration.',
              style: TextStyle(fontSize: 12),
            ),
            SizedBox(height: 12),
            Text(
              '• No points awarded until verification',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: AppColors.leafOf(context),
              ),
            ),
            Text(
              '• Growth check-ins require verified evidence',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.accentOf(context),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Self-reported records do not establish tree survival or carbon credits.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.coral,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.royalForest,
              foregroundColor: AppColors.champagneGold,
            ),
            icon: const Icon(Icons.camera_rounded, size: 16),
            label: const Text(
              'Record Sapling',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              final newPlant = PlantGrowthRecord(
                id: DateTime.now().millisecondsSinceEpoch,
                species: 'Ashoka Sapling',
                location: widget.appState.baseline.cityWard,
                plantedDate: DateTime.now(),
                currentMonth: 1,
                isMonthVerified: false,
                pointsEarned: 0,
              );
              widget.appState.addPlant(newPlant);
              widget.appState.logActivity(
                title: 'Planted Ashoka Sapling',
                category: 'Waste',
                subtitle: 'Self-reported sapling · verification pending',
                pointsEarned: 0,
                co2Kg: 0.0,
                icon: Icons.park_rounded,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: AppColors.royalForest,
                  content: Text(
                    'Sapling record saved. Photo verification and points are pending.',
                    style: TextStyle(color: AppColors.champagneGold),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _verifyMonthlyCheckIn(int index) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Tree survival requires verified photo evidence. A verification provider is not configured; no points were awarded.',
        ),
      ),
    );
  }

  void _simulateMissedCheckInDeduction(int index) {
    final p = _plants[index];
    final pointsToDeduct = p.pointsEarned;
    widget.appState.forfeitPlant(p.id);
    widget.appState.logActivity(
      title: 'Penalty: Missed Tree Check-in',
      category: 'Waste',
      subtitle:
          'Monthly verification missed for ${p.species}. Revoked all $pointsToDeduct points.',
      pointsEarned: -pointsToDeduct,
      co2Kg: 0.0,
      icon: Icons.cancel_rounded,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.coral,
        content: Text(
          '⚠️ Monthly verification missed! Revoked -$pointsToDeduct Green Points.',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkCanvas : AppColors.lightCanvas;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;

    return Scaffold(
      backgroundColor: bg,
      drawer: FeatureDirectoryDrawer(appState: widget.appState),
      appBar: GrevideaAppBar(
        title: 'Rewards Shop',
        subtitle: 'Plant Tracker & Verified Rewards',
        showBack: Navigator.of(context).canPop(),
        appState: widget.appState,
      ),
      body: Column(
        children: [
          // Points Balance Hero Card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.royalForest,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppColors.champagneGold.withValues(alpha: 0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.royalForest.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Green Points Balance',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.appState.greenPoints}',
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: AppColors.champagneGold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '≈ ${widget.appState.treesEquivalent.toStringAsFixed(1)} Trees Carbon Absorption',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.deepForest,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.champagneGold.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: AppColors.champagneGold,
                    size: 26,
                  ),
                ),
              ],
            ),
          ),

          // Sub-Tabs: Rewards Store / Plant Growth Tracker / Carpooling
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurfaceAlt,
              borderRadius: BorderRadius.circular(20),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: AppColors.royalForest,
                borderRadius: BorderRadius.circular(16),
              ),
              labelColor: AppColors.accentOf(context),
              unselectedLabelColor: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
              labelStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              tabs: const [
                Tab(text: 'Rewards Store'),
                Tab(text: 'Plant Tracker'),
                Tab(text: 'Carpooling'),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Rewards Store
                ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      'Verified Eco Redemptions',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._rewards.map(
                      (r) => _buildRewardTile(r, cardBg, textColor, isDark),
                    ),
                  ],
                ),

                // Tab 2: Plant Growth Tracker (Monthly Milestones & Revocation Logic)
                ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'My Planted Trees (${_plants.length})',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.royalForest,
                            foregroundColor: AppColors.champagneGold,
                          ),
                          icon: const Icon(Icons.add_a_photo_rounded, size: 14),
                          label: const Text(
                            'Add Plant',
                            style: TextStyle(fontSize: 11),
                          ),
                          onPressed: _showPlantTreeDialog,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_plants.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Text(
                            'No trees planted yet.\nRecord a sapling to track its growth.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.lightTextSecondary,
                            ),
                          ),
                        ),
                      )
                    else
                      ...List.generate(_plants.length, (idx) {
                        final p = _plants[idx];
                        return _buildPlantCard(
                          p,
                          idx,
                          cardBg,
                          textColor,
                          isDark,
                        );
                      }),
                  ],
                ),

                // Tab 3: Carpooling (Map-Based Corridor Matching)
                NearbyBoardScreen(appState: widget.appState, carpools: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardTile(
    Map<String, dynamic> r,
    Color cardBg,
    Color textColor,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (r['color'] as Color).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              r['icon'] as IconData,
              color: r['color'] as Color,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r['title'] as String,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  r['subtitle'] as String,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.royalForest,
              foregroundColor: AppColors.champagneGold,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: () => _handleRewardTap(r),
            child: Text(
              '${r['cost']} pts',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlantCard(
    PlantGrowthRecord p,
    int index,
    Color cardBg,
    Color textColor,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: p.isForfeited
              ? AppColors.coral
              : (p.isMonthVerified
                    ? AppColors.leafOf(context)
                    : AppColors.amber),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:
                      (p.isForfeited
                              ? AppColors.coral
                              : AppColors.leafOf(context))
                          .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  p.isForfeited ? Icons.cancel_rounded : Icons.park_rounded,
                  color: p.isForfeited
                      ? AppColors.coral
                      : AppColors.leafOf(context),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.species,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: textColor,
                      ),
                    ),
                    Text(
                      'Location: ${p.location}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: p.isForfeited
                      ? AppColors.coral.withValues(alpha: 0.15)
                      : AppColors.royalForest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  p.isForfeited
                      ? 'Points Revoked'
                      : '${p.pointsEarned} pts earned',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: p.isForfeited
                        ? AppColors.coral
                        : AppColors.accentOf(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Monthly Growth Timeline
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMonthDot(
                'Month 1',
                p.isMonthVerified,
                AppColors.leafOf(context),
              ),
              _buildMonthDot(
                'Month 2',
                p.isMonthVerified,
                p.isForfeited ? AppColors.coral : AppColors.amber,
              ),
              _buildMonthDot('Month 3', false, AppColors.lightTextSecondary),
              _buildMonthDot('Month 4', false, AppColors.lightTextSecondary),
            ],
          ),
          const SizedBox(height: 14),

          if (!p.isForfeited) ...[
            if (!p.isMonthVerified)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.royalForest,
                        foregroundColor: AppColors.champagneGold,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.camera_alt_rounded, size: 14),
                      label: const Text(
                        'Check verification status',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () => _verifyMonthlyCheckIn(index),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.coral,
                      size: 20,
                    ),
                    tooltip: 'Archive sapling record',
                    onPressed: () => _simulateMissedCheckInDeduction(index),
                  ),
                ],
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.leafOf(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.leafOf(context),
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Month 2 growth verified! Next check-in in 28 days.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.leafOf(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ] else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.coral.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Monthly verification was missed. All points for this plant were forfeited.',
                style: TextStyle(
                  fontSize: 10.5,
                  color: AppColors.coral,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMonthDot(String label, bool isDone, Color color) {
    return Column(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone ? color : Colors.transparent,
            border: Border.all(color: color, width: 2),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            color: AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }
}
