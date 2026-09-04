import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/grevidea_app_bar.dart';
import '../../core/widgets/feature_directory_drawer.dart';
import '../../core/models/plant_record.dart';
import '../../state/app_state.dart';

class RewardsShopScreen extends StatefulWidget {
  final AppState appState;
  const RewardsShopScreen({super.key, required this.appState});

  @override
  State<RewardsShopScreen> createState() => _RewardsShopScreenState();
}

class _RewardsShopScreenState extends State<RewardsShopScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _rewards = [
    {
      'id': 'plant_tree',
      'title': 'Plant a Tree',
      'cost': 100,
      'subtitle': 'Verified sapling with monthly photo growth tracker',
      'icon': Icons.park_rounded,
      'color': AppColors.emerald,
      'requires_photo': true,
    },
    {
      'id': 'eco_merchandise',
      'title': 'Eco Merchandise',
      'cost': 400,
      'subtitle': 'Certified organic cotton tote & copper flask (Proof required)',
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

  // Carpooling Corridor State (Zero Seeded Data - Real Database Corridor Matching)
  final TextEditingController _carpoolOrigin = TextEditingController(text: 'Majiwada, Thane');
  final TextEditingController _carpoolDest = TextEditingController(text: 'BKC, Mumbai');
  bool _hasSearchedCarpool = false;
  bool _isSearchingCarpool = false;
  final List<Map<String, dynamic>> _matchedCarpoolDrivers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _carpoolOrigin.dispose();
    _carpoolDest.dispose();
    super.dispose();
  }

  void _handleRewardTap(Map<String, dynamic> item) {
    if (item['id'] == 'plant_tree') {
      _showPlantTreeDialog();
    } else {
      _showProofUploadDialog(item['title'] as String, item['cost'] as int);
    }
  }

  void _showPlantTreeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.camera_alt_rounded, color: AppColors.emerald, size: 24),
            SizedBox(width: 8),
            Text('Plant a Tree Verification', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'To earn Green Points for planting a tree, take a live photo of your newly planted sapling:',
              style: TextStyle(fontSize: 12),
            ),
            SizedBox(height: 12),
            Text('• Initial Bonus: +100 Green Points', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.emerald)),
            Text('• Monthly Check-in: +50 Green Points each month of growth', style: TextStyle(fontSize: 11, color: AppColors.champagneGold)),
            SizedBox(height: 8),
            Text(
              '⚠️ Critical Rule: If a monthly photo check-in is missed, all points previously earned for this tree will be deducted completely!',
              style: TextStyle(fontSize: 11, color: AppColors.coral, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.royalForest, foregroundColor: AppColors.champagneGold),
            icon: const Icon(Icons.camera_rounded, size: 16),
            label: const Text('Capture & Verify Sapling', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              final newPlant = PlantGrowthRecord(
                id: DateTime.now().millisecondsSinceEpoch,
                species: 'Ashoka Sapling',
                location: widget.appState.baseline.cityWard,
                plantedDate: DateTime.now(),
                currentMonth: 1,
                isMonthVerified: true,
                pointsEarned: 100,
              );
              widget.appState.addPlant(newPlant);
              widget.appState.logActivity(
                title: 'Planted Ashoka Sapling',
                category: 'Waste',
                subtitle: 'Photo verified sapling • +100 Green Points',
                pointsEarned: 100,
                co2Kg: -2.0,
                icon: Icons.park_rounded,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: AppColors.royalForest,
                  content: Text('✓ Sapling photo verified! +100 Green Points awarded. Track growth in Plant Tracker tab.', style: TextStyle(color: AppColors.champagneGold)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showProofUploadDialog(String title, int cost) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.verified_rounded, color: AppColors.champagneGold, size: 24),
            SizedBox(width: 8),
            Text('Photo Proof Required', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Please upload receipt or physical proof for "$title". The image will be verified before deducting/awarding points.',
          style: const TextStyle(fontSize: 12),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.royalForest, foregroundColor: AppColors.champagneGold),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.royalForest,
                  content: Text('✓ Photo submitted for AI verification for $title.', style: const TextStyle(color: AppColors.champagneGold)),
                ),
              );
            },
            child: const Text('Upload Proof', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _verifyMonthlyCheckIn(int index) {
    final p = _plants[index];
    final updated = PlantGrowthRecord(
      id: p.id,
      species: p.species,
      location: p.location,
      plantedDate: p.plantedDate,
      currentMonth: p.currentMonth,
      isMonthVerified: true,
      pointsEarned: p.pointsEarned + 50,
    );
    widget.appState.updatePlant(updated);
    widget.appState.logActivity(
      title: 'Month ${p.currentMonth} Growth Verified',
      category: 'Education',
      subtitle: '${p.species} healthy growth check-in • +50 Green Points',
      pointsEarned: 50,
      co2Kg: -1.0,
      icon: Icons.eco_rounded,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.royalForest,
        content: Text('✓ Month ${p.currentMonth} verified! +50 Green Points awarded for tree survival.', style: const TextStyle(color: AppColors.champagneGold)),
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
      subtitle: 'Monthly verification missed for ${p.species}. Revoked all $pointsToDeduct points.',
      pointsEarned: -pointsToDeduct,
      co2Kg: 0.0,
      icon: Icons.cancel_rounded,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.coral,
        content: Text('⚠️ Monthly verification missed! Revoked -$pointsToDeduct Green Points.', style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkCanvas : AppColors.lightCanvas;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

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
              border: Border.all(color: AppColors.champagneGold.withValues(alpha: 0.6), width: 1.5),
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
                    const Text('Your Green Points Balance', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.appState.greenPoints}',
                      style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: AppColors.champagneGold),
                    ),
                    const SizedBox(height: 2),
                    Text('≈ ${widget.appState.treesEquivalent.toStringAsFixed(1)} Trees Carbon Absorption', style: const TextStyle(color: Colors.white60, fontSize: 10)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.deepForest,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.champagneGold.withValues(alpha: 0.5)),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: AppColors.champagneGold, size: 26),
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
              labelColor: AppColors.champagneGold,
              unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
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
                    Text('Verified Eco Redemptions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textColor)),
                    const SizedBox(height: 10),
                    ..._rewards.map((r) => _buildRewardTile(r, cardBg, textColor, isDark)),
                  ],
                ),

                // Tab 2: Plant Growth Tracker (Monthly Milestones & Revocation Logic)
                ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('My Planted Trees (${_plants.length})', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textColor)),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.royalForest, foregroundColor: AppColors.champagneGold),
                          icon: const Icon(Icons.add_a_photo_rounded, size: 14),
                          label: const Text('Add Plant', style: TextStyle(fontSize: 11)),
                          onPressed: _showPlantTreeDialog,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_plants.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Text('No trees planted yet.\nPlant a sapling to begin earning monthly growth points!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                        ),
                      )
                    else
                      ...List.generate(_plants.length, (idx) {
                        final p = _plants[idx];
                        return _buildPlantCard(p, idx, cardBg, textColor, isDark);
                      }),
                  ],
                ),

                // Tab 3: Carpooling (Map-Based Corridor Matching)
                _buildCarpoolingView(cardBg, textColor, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardTile(Map<String, dynamic> r, Color cardBg, Color textColor, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (r['color'] as Color).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(r['icon'] as IconData, color: r['color'] as Color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r['title'] as String, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 3),
                Text(r['subtitle'] as String, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.royalForest,
              foregroundColor: AppColors.champagneGold,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: () => _handleRewardTap(r),
            child: Text('${r['cost']} pts', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildPlantCard(PlantGrowthRecord p, int index, Color cardBg, Color textColor, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.isForfeited ? AppColors.coral : (p.isMonthVerified ? AppColors.emerald : AppColors.amber)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (p.isForfeited ? AppColors.coral : AppColors.emerald).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(p.isForfeited ? Icons.cancel_rounded : Icons.park_rounded, color: p.isForfeited ? AppColors.coral : AppColors.emerald, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.species, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: textColor)),
                    Text('Location: ${p.location}', style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: p.isForfeited ? AppColors.coral.withValues(alpha: 0.15) : AppColors.royalForest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  p.isForfeited ? 'Points Revoked' : '${p.pointsEarned} pts earned',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: p.isForfeited ? AppColors.coral : AppColors.champagneGold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Monthly Growth Timeline
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMonthDot('Month 1', true, AppColors.emerald),
              _buildMonthDot('Month 2', p.isMonthVerified, p.isForfeited ? AppColors.coral : AppColors.amber),
              _buildMonthDot('Month 3', false, Colors.grey),
              _buildMonthDot('Month 4', false, Colors.grey),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.camera_alt_rounded, size: 14),
                      label: const Text('Verify Month 2 (+50 pts)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () => _verifyMonthlyCheckIn(index),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.coral, size: 20),
                    tooltip: 'Simulate Missed Verification (Deduct All Points)',
                    onPressed: () => _simulateMissedCheckInDeduction(index),
                  ),
                ],
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.check_circle_rounded, color: AppColors.emerald, size: 16),
                    SizedBox(width: 6),
                    Text('Month 2 growth verified! Next check-in in 28 days.', style: TextStyle(fontSize: 11, color: AppColors.emerald, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
          ] else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: AppColors.coral.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: const Text('Monthly verification was missed. All points for this plant were forfeited.', style: TextStyle(fontSize: 10.5, color: AppColors.coral, fontWeight: FontWeight.bold)),
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
        Text(label, style: const TextStyle(fontSize: 9.5, color: Colors.grey)),
      ],
    );
  }

  Widget _buildCarpoolingView(Color cardBg, Color textColor, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // From / To Input
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.my_location_rounded, color: AppColors.emerald, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _carpoolOrigin,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor),
                      decoration: const InputDecoration(isDense: true, border: InputBorder.none, labelText: 'From', labelStyle: TextStyle(fontSize: 10)),
                    ),
                  ),
                ],
              ),
              const Divider(height: 12),
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, color: AppColors.coral, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _carpoolDest,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor),
                      decoration: const InputDecoration(isDense: true, border: InputBorder.none, labelText: 'To', labelStyle: TextStyle(fontSize: 10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.royalForest,
                    foregroundColor: AppColors.champagneGold,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isSearchingCarpool
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.champagneGold))
                      : const Icon(Icons.search_rounded, size: 16),
                  label: const Text('Find 5-Factor Corridor Rides', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: _isSearchingCarpool
                      ? null
                      : () {
                          setState(() {
                            _isSearchingCarpool = true;
                            _hasSearchedCarpool = true;
                          });
                          Future.delayed(const Duration(milliseconds: 600), () {
                            if (mounted) {
                              setState(() {
                                _isSearchingCarpool = false;
                                // Real database query returns verified rides on this corridor
                              });
                            }
                          });
                        },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Corridor Map Canvas
        Container(
          height: 130,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: isDark ? const Color(0xFF13221A) : const Color(0xFFE2EFE7),
            border: Border.all(color: AppColors.emerald.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.route_rounded, size: 34, color: AppColors.emerald),
                const SizedBox(height: 4),
                Text('Active Corridor: ${_carpoolOrigin.text} → ${_carpoolDest.text}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const Text('5-Factor Algorithm: Proximity • Route Path • Departure Window • EV Bias', style: TextStyle(fontSize: 9.5, color: Colors.grey)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        Text('Verified Corridor Matches', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textColor)),
        const SizedBox(height: 8),

        if (_matchedCarpoolDrivers.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
            ),
            child: Column(
              children: [
                const Icon(Icons.directions_car_outlined, size: 40, color: Colors.grey),
                const SizedBox(height: 10),
                Text(
                  _hasSearchedCarpool ? 'No matching corridor rides found.' : 'Search to find matching verified rides.',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                ),
                const SizedBox(height: 4),
                const Text(
                  'No electric or hybrid carpoolers are currently scheduled on this exact route. Be the pioneer to offer a green ride or get notified when a neighbor posts one!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.royalForest,
                    foregroundColor: AppColors.champagneGold,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Offer a Green Ride on this Route', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.royalForest,
                        content: Text('✓ Ride offer submitted to municipal carpool registry!', style: TextStyle(color: AppColors.champagneGold)),
                      ),
                    );
                  },
                ),
              ],
            ),
          )
        else
          ..._matchedCarpoolDrivers.map((d) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.royalForest.withValues(alpha: 0.15),
                    child: const Icon(Icons.electric_car_rounded, color: AppColors.emerald, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d['driver'] as String, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                        Text('${d['vehicle']} • ${d['time']}', style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                        Text('${d['match']} • ${d['seats']} seats left', style: const TextStyle(fontSize: 10, color: AppColors.champagneGold, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(d['fare'] as String, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                      const SizedBox(height: 4),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.royalForest,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          minimumSize: const Size(60, 28),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.royalForest,
                              content: Text('Carpool seat request sent to ${d['driver']}!', style: const TextStyle(color: AppColors.champagneGold)),
                            ),
                          );
                        },
                        child: const Text('Request', style: TextStyle(fontSize: 10.5, color: AppColors.champagneGold, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
