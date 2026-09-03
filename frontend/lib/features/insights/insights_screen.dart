import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/grevidea_app_bar.dart';
import '../../core/widgets/feature_directory_drawer.dart';
import '../../state/app_state.dart';

class InsightsScreen extends StatefulWidget {
  final AppState appState;
  const InsightsScreen({super.key, required this.appState});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
        title: 'Insights',
        subtitle: 'Behavioral Science & Spillover',
        showBack: Navigator.of(context).canPop(),
        appState: widget.appState,
      ),
      body: Column(
        children: [
          // Segmented Tabs: Overview / Comparison / Impact
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurfaceAlt,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: AppColors.royalForest,
                borderRadius: BorderRadius.circular(20),
              ),
              labelColor: AppColors.champagneGold,
              unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Comparison'),
                Tab(text: 'Impact'),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(cardBg, textColor, isDark),
                _buildComparisonTab(cardBg, textColor, isDark),
                _buildImpactTab(cardBg, textColor, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(Color cardBg, Color textColor, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Environmental Score Card (Matching Screen 03)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.royalForest,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.champagneGold, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.royalForest.withValues(alpha: 0.3),
                blurRadius: 12,
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
                    'Environmental Score',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${widget.appState.score}',
                        style: const TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          color: AppColors.champagneGold,
                          letterSpacing: -1,
                        ),
                      ),
                      const Text(
                        ' /100',
                        style: TextStyle(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Great!',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.emerald),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "You're doing better than 78% of users.",
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8)),
                  ),
                ],
              ),
              // Circular progress leaf badge
              Container(
                width: 76,
                height: 76,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.deepForest,
                  border: Border.all(color: AppColors.emerald, width: 3),
                ),
                child: const Icon(Icons.energy_savings_leaf_rounded, color: AppColors.emerald, size: 36),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Score Breakdown (Matching Screen 03)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Score Breakdown',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textColor),
              ),
              const SizedBox(height: 16),
              _buildCategoryProgressBar('Transport', 70, 100, Icons.directions_car_rounded, AppColors.sapphire, textColor),
              _buildCategoryProgressBar('Energy', 85, 100, Icons.bolt_rounded, AppColors.amber, textColor),
              _buildCategoryProgressBar('Food', 75, 100, Icons.restaurant_rounded, AppColors.emerald, textColor),
              _buildCategoryProgressBar('Waste', 80, 100, Icons.recycling_rounded, Colors.teal, textColor),
              _buildCategoryProgressBar('Lifestyle', 90, 100, Icons.spa_rounded, AppColors.champagneGold, textColor),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Achievements Mini Row (Matching Screen 03)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Achievements',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textColor),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildAchievementBadge('Green Streak', '14 Days', Icons.local_fire_department_rounded, AppColors.amber),
                  _buildAchievementBadge('Tree Saver', '10 Trees', Icons.forest_rounded, AppColors.emerald),
                  _buildAchievementBadge('CO₂ Saver', '50 kg', Icons.cloud_done_rounded, AppColors.sapphire),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Spillover Engine Insight (Core Research Contribution)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.royalForest.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.emerald.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_graph_rounded, color: AppColors.emerald, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Spillover Effect Detected',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.emerald),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Adopting plant-based lunches triggered a 14% reduction in transport emissions within 14 days.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCategoryProgressBar(String label, int value, int max, IconData icon, Color color, Color textColor) {
    final pct = value / max;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
              const Spacer(),
              Text('$value/$max', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 7,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementBadge(String title, String val, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 6),
        Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        Text(val, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildComparisonTab(Color cardBg, Color textColor, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildComparisonCard('Your Footprint', '12.4 kg CO₂/wk', AppColors.emerald, '36% lower than Thane average'),
        _buildComparisonCard('Thane West Average', '19.8 kg CO₂/wk', AppColors.amber, 'Based on 4,820 citizen baselines'),
        _buildComparisonCard('National Urban Benchmark', '26.4 kg CO₂/wk', AppColors.coral, 'CPCB / MoEFCC 2026 urban standard'),
      ],
    );
  }

  Widget _buildComparisonCard(String title, String stat, Color color, String subtitle) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.royalForest.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 6, backgroundColor: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Text(stat, style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildImpactTab(Color cardBg, Color textColor, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.royalForest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.champagneGold),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Cumulative Lifetime Impact', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              const Text('148.6 kg CO₂ Avoided', style: TextStyle(color: AppColors.champagneGold, fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Equivalent to 6.2 Neem Trees', style: TextStyle(color: Colors.white, fontSize: 12)),
                  Text('₹4,820 Fuel Saved', style: TextStyle(color: AppColors.emerald, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
