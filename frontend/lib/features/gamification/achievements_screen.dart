import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/grevidea_app_bar.dart';
import '../../core/widgets/feature_directory_drawer.dart';
import '../../state/app_state.dart';

class AchievementsScreen extends StatefulWidget {
  final AppState appState;
  const AchievementsScreen({super.key, required this.appState});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class AchievementDefinition {
  final String id;
  final String title;
  final String desc;
  final IconData icon;
  final Color color;
  final bool Function(AppState) isUnlocked;

  const AchievementDefinition({
    required this.id,
    required this.title,
    required this.desc,
    required this.icon,
    required this.color,
    required this.isUnlocked,
  });
}

class _AchievementsScreenState extends State<AchievementsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<AchievementDefinition> _achievementDefinitions = [
    AchievementDefinition(
      id: 'starter',
      title: 'Green Starter',
      desc: 'First 5 eco actions completed',
      icon: Icons.eco_rounded,
      color: AppColors.emerald,
      isUnlocked: (s) => s.recentActivities.length >= 5,
    ),
    AchievementDefinition(
      id: 'carbon_25',
      title: 'Carbon Sentinel',
      desc: 'Saved 25 kg of CO₂ emissions',
      icon: Icons.cloud_done_rounded,
      color: AppColors.sapphire,
      isUnlocked: (s) => s.totalCo2Saved >= 25.0,
    ),
    AchievementDefinition(
      id: 'carbon_100',
      title: 'CO₂ Titan',
      desc: 'Saved 100 kg of CO₂ emissions',
      icon: Icons.speed_rounded,
      color: AppColors.royalForest,
      isUnlocked: (s) => s.totalCo2Saved >= 100.0,
    ),
    AchievementDefinition(
      id: 'carbon_500',
      title: 'Planet Protector',
      desc: 'Saved 500 kg of lifetime CO₂',
      icon: Icons.public_rounded,
      color: AppColors.champagneGold,
      isUnlocked: (s) => s.totalCo2Saved >= 500.0,
    ),
    AchievementDefinition(
      id: 'tree_1',
      title: 'Tree Ambassador',
      desc: '1.0 mature tree absorption equivalent',
      icon: Icons.park_rounded,
      color: AppColors.emerald,
      isUnlocked: (s) => s.treesEquivalent >= 1.0,
    ),
    AchievementDefinition(
      id: 'tree_5',
      title: 'Forest Guardian',
      desc: '5.0 mature tree absorption equivalent',
      icon: Icons.nature_people_rounded,
      color: AppColors.deepForest,
      isUnlocked: (s) => s.treesEquivalent >= 5.0,
    ),
    AchievementDefinition(
      id: 'waste_pioneer',
      title: 'Zero Waste Pioneer',
      desc: 'Logged 5 verified recycling drops',
      icon: Icons.recycling_rounded,
      color: Colors.teal,
      isUnlocked: (s) => s.recentActivities.where((a) => a.category == 'Waste').length >= 5,
    ),
    AchievementDefinition(
      id: 'circular_master',
      title: 'Circular Master',
      desc: 'Logged 15 verified recycling drops',
      icon: Icons.change_circle_rounded,
      color: Colors.teal.shade700,
      isUnlocked: (s) => s.recentActivities.where((a) => a.category == 'Waste').length >= 15,
    ),
    AchievementDefinition(
      id: 'habit_3',
      title: 'Habit Starter',
      desc: 'Maintained a 3-day streak',
      icon: Icons.local_fire_department_outlined,
      color: Colors.orange,
      isUnlocked: (s) => s.streakDays >= 3,
    ),
    AchievementDefinition(
      id: 'streak_7',
      title: 'Streak Champion',
      desc: 'Maintained a 7-day consecutive streak',
      icon: Icons.local_fire_department_rounded,
      color: AppColors.amber,
      isUnlocked: (s) => s.streakDays >= 7,
    ),
    AchievementDefinition(
      id: 'streak_30',
      title: 'Legendary Steward',
      desc: 'Maintained a 30-day consecutive streak',
      icon: Icons.whatshot_rounded,
      color: AppColors.coral,
      isUnlocked: (s) => s.streakDays >= 30,
    ),
    AchievementDefinition(
      id: 'pts_100',
      title: 'Century Club',
      desc: 'Earned your first 100 Green Points',
      icon: Icons.stars_rounded,
      color: AppColors.champagneGold,
      isUnlocked: (s) => s.greenPoints >= 100,
    ),
    AchievementDefinition(
      id: 'pts_500',
      title: 'Eco Warrior',
      desc: 'Earned more than 500 Green Points',
      icon: Icons.shield_rounded,
      color: AppColors.champagneGold,
      isUnlocked: (s) => s.greenPoints >= 500,
    ),
    AchievementDefinition(
      id: 'pts_1000',
      title: 'Sustainability Titan',
      desc: 'Earned 1,000 lifetime points',
      icon: Icons.military_tech_rounded,
      color: AppColors.champagneGold,
      isUnlocked: (s) => s.greenPoints >= 1000,
    ),
    AchievementDefinition(
      id: 'clean_commuter',
      title: 'Clean Commuter',
      desc: 'Logged 10 public transit commutes',
      icon: Icons.directions_subway_rounded,
      color: AppColors.sapphire,
      isUnlocked: (s) => s.recentActivities.where((a) => a.category == 'Transport').length >= 10,
    ),
    AchievementDefinition(
      id: 'solar_sentinel',
      title: 'Solar Sentinel',
      desc: 'Dwelling with clean energy or solar',
      icon: Icons.solar_power_rounded,
      color: Colors.amber.shade700,
      isUnlocked: (s) => s.baseline.hasRooftopSolar && s.recentActivities.any((a) => a.category == 'Energy'),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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

    final unlockedCount = _achievementDefinitions.where((a) => a.isUnlocked(widget.appState)).length;

    return Scaffold(
      backgroundColor: bg,
      drawer: FeatureDirectoryDrawer(appState: widget.appState),
      appBar: GrevideaAppBar(
        title: 'My Achievements',
        subtitle: '$unlockedCount / ${_achievementDefinitions.length} Badges Unlocked',
        showBack: Navigator.of(context).canPop(),
        appState: widget.appState,
      ),
      body: Column(
        children: [
          // Segmented Tabs: Badges / Milestones (Matching Screen 12)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: 'Badges'),
                Tab(text: 'Milestones'),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 3xN Badges Grid with Responsive Aspect Ratio (0.72) to Prevent Bottom Overflows
                GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _achievementDefinitions.length,
                  itemBuilder: (context, index) {
                    final badge = _achievementDefinitions[index];
                    final isUnlocked = badge.isUnlocked(widget.appState);
                    final color = badge.color;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isUnlocked
                              ? color.withValues(alpha: 0.5)
                              : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                          width: isUnlocked ? 1.5 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isUnlocked ? color.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1),
                              border: Border.all(
                                color: isUnlocked ? color : Colors.grey.shade400,
                                width: 1.2,
                              ),
                            ),
                            child: Icon(
                              badge.icon,
                              color: isUnlocked ? color : Colors.grey,
                              size: 22,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            badge.title,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isUnlocked ? textColor : Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isUnlocked ? 'Unlocked ✓' : 'Locked',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: isUnlocked ? AppColors.emerald : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Milestones Tab (Pure Dynamic Calculation from AppState)
                ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildMilestoneCard(
                      'Carbon Reduction Titan',
                      '${widget.appState.totalCo2Saved.toStringAsFixed(1)} / 100 kg CO₂',
                      (widget.appState.totalCo2Saved / 100.0).clamp(0.0, 1.0),
                      AppColors.sapphire,
                      cardBg,
                      textColor,
                    ),
                    _buildMilestoneCard(
                      'Tree Absorption Equivalent',
                      '${widget.appState.treesEquivalent.toStringAsFixed(1)} / 5.0 Trees Equiv.',
                      (widget.appState.treesEquivalent / 5.0).clamp(0.0, 1.0),
                      AppColors.emerald,
                      cardBg,
                      textColor,
                    ),
                    _buildMilestoneCard(
                      'Consistent Habit Champion',
                      '${widget.appState.streakDays} / 30 Days Streak',
                      (widget.appState.streakDays / 30.0).clamp(0.0, 1.0),
                      AppColors.amber,
                      cardBg,
                      textColor,
                    ),
                    _buildMilestoneCard(
                      'Green Points Century',
                      '${widget.appState.greenPoints} / 500 Points',
                      (widget.appState.greenPoints / 500.0).clamp(0.0, 1.0),
                      AppColors.champagneGold,
                      cardBg,
                      textColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneCard(String title, String progress, double pct, Color color, Color cardBg, Color textColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: textColor),
                ),
              ),
              const SizedBox(width: 8),
              Text(progress, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: color)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
