import '../../features/profile/profile_screen.dart';
import '../../features/civic/civic_screen.dart';
import '../../features/tracker/tracker_screen.dart';
import '../../features/community/community_screen.dart';
import '../../features/insights/insights_screen.dart';
import '../../features/insights/impact_breakdown_screen.dart';

import 'package:flutter/material.dart';

import '../../features/integrations/delivery_center_screen.dart';
import '../../features/profile/ecosystem_catalog_screen.dart';
import '../../features/community/nearby_board_screen.dart';
import '../theme/app_colors.dart';
import '../../state/app_state.dart';
import '../../features/tracker/green_commute_screen.dart';
import '../../features/tracker/log_activity_screen.dart';
import '../../features/civic/disaster_alerts_screen.dart';
import '../../features/civic/report_waste_screen.dart';
import '../../features/civic/aqi_map_screen.dart';
import '../../features/marketplace/scan_product_screen.dart';
import '../../features/marketplace/rewards_shop_screen.dart';
import '../../features/climategpt/climategpt_screen.dart';
import '../../features/gamification/challenges_screen.dart';
import '../../features/gamification/achievements_screen.dart';
import '../../features/leaderboard/leaderboard_screen.dart';
import '../../features/learning/learning_screen.dart';
import '../../features/profile/settings_screen.dart';

/// All Features & Quick Actions Drawer
class FeatureDirectoryDrawer extends StatelessWidget {
  final AppState appState;

  const FeatureDirectoryDrawer({super.key, required this.appState});

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.of(context).pop(); // Close drawer
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkCanvas : AppColors.lightCanvas;

    return Drawer(
      backgroundColor: bg,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.royalForest,
                border: Border(
                  bottom: BorderSide(color: AppColors.goldBorder, width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.champagneGold.withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.champagneGold),
                        ),
                        child: const Icon(
                          Icons.energy_savings_leaf_rounded,
                          color: AppColors.champagneGold,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Grevidea Menu',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.champagneGold,
                              ),
                            ),
                            Text(
                              'All features & preferences',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // User Status Pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            appState.userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.eco_rounded,
                              color: AppColors.leafOf(context),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${appState.greenPoints} pts',
                              style: const TextStyle(
                                color: AppColors.champagneGold,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Complete Quick Actions and Feature List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 12,
                ),
                children: [
                  _buildSectionHeader(context, 'YOUR ENVIRONMENT'),
                  _buildNavTile(
                    context: context,
                    icon: Icons.show_chart_rounded,
                    title: 'Tracker',
                    subtitle: 'Explore tracker',
                    color: AppColors.accentOf(context),
                    onTap: () =>
                        _navigateTo(context, TrackerScreen(appState: appState)),
                  ),
                  _buildNavTile(
                    context: context,
                    icon: Icons.people_outline_rounded,
                    title: 'Community',
                    subtitle: 'Explore community',
                    color: AppColors.accentOf(context),
                    onTap: () => _navigateTo(
                      context,
                      CommunityScreen(appState: appState),
                    ),
                  ),
                  _buildNavTile(
                    context: context,
                    icon: Icons.insights_rounded,
                    title: 'Insights',
                    subtitle: 'Explore insights',
                    color: AppColors.accentOf(context),
                    onTap: () => _navigateTo(
                      context,
                      InsightsScreen(appState: appState),
                    ),
                  ),
                  _buildNavTile(
                    context: context,
                    icon: Icons.pie_chart_rounded,
                    title: 'Impact Breakdown',
                    subtitle: 'Explore impact breakdown',
                    color: AppColors.accentOf(context),
                    onTap: () => _navigateTo(
                      context,
                      ImpactBreakdownScreen(appState: appState),
                    ),
                  ),
                  _buildNavTile(
                    context: context,
                    icon: Icons.account_circle_outlined,
                    title: 'Profile & Account',
                    subtitle: 'Personal details, baseline and sign out',
                    color: AppColors.accentOf(context),
                    onTap: () =>
                        _navigateTo(context, ProfileScreen(appState: appState)),
                  ),
                  _buildNavTile(
                    context: context,
                    icon: Icons.location_city_rounded,
                    title: 'Civic Hub',
                    subtitle: 'Explore civic reports and actions',
                    color: AppColors.accentOf(context),
                    onTap: () =>
                        _navigateTo(context, CivicScreen(appState: appState)),
                  ),
                  _buildSectionHeader(context, 'QUICK ACTIONS'),
                  _buildNavTile(
                    context: context,
                    icon: Icons.add_circle_outline_rounded,
                    title: 'Log Daily Activity',
                    subtitle:
                        'Record your travel, plant-based meals, or home energy',
                    color: AppColors.accentOf(context),
                    onTap: () => _navigateTo(
                      context,
                      LogActivityScreen(appState: appState),
                    ),
                  ),
                  _buildNavTile(
                    context: context,
                    icon: Icons.qr_code_scanner_rounded,
                    title: 'Scan Product (EcoLens)',
                    subtitle: 'Scan barcodes to see packaging and sustainability ratings',
                    color: AppColors.accentOf(context),
                    onTap: () => _navigateTo(
                      context,
                      ScanProductScreen(appState: appState),
                    ),
                  ),
                  _buildNavTile(
                    context: context,
                    icon: Icons.delete_sweep_rounded,
                    title: 'Report Pollution & Waste',
                    subtitle: 'Snap a photo and report trash dumping or smoke to the city',
                    color: AppColors.coral,
                    onTap: () => _navigateTo(
                      context,
                      ReportWasteScreen(appState: appState),
                    ),
                  ),
                  _buildNavTile(
                    context: context,
                    icon: Icons.psychology_rounded,
                    title: 'Ask Climate Assistant',
                    subtitle: 'Get instant, friendly answers to any sustainability question',
                    color: AppColors.leafOf(context),
                    onTap: () => _navigateTo(
                      context,
                      ClimateGptScreen(appState: appState),
                    ),
                  ),
                  _buildNavTile(
                    context: context,
                    icon: Icons.map_rounded,
                    title: 'City Air Quality Map',
                    subtitle: 'Check live AQI and smog levels across your neighborhood',
                    color: AppColors.leafOf(context),
                    onTap: () =>
                        _navigateTo(context, AqiMapScreen(appState: appState)),
                  ),
                  _buildNavTile(
                    context: context,
                    icon: Icons.flag_rounded,
                    title: 'Eco Challenges',
                    subtitle: 'Join weekly challenges and build green habits with friends',
                    color: AppColors.amber,
                    onTap: () => _navigateTo(
                      context,
                      ChallengesScreen(appState: appState),
                    ),
                  ),
                  _buildNavTile(
                    context: context,
                    icon: Icons.storefront_rounded,
                    title: 'Rewards Shop',
                    subtitle: 'Redeem your earned green points for local sustainable rewards',
                    color: AppColors.accentOf(context),
                    onTap: () => _navigateTo(
                      context,
                      RewardsShopScreen(appState: appState),
                    ),
                  ),
                  _buildSectionHeader(context, 'TRAVEL & WEATHER'),
                  _buildNavTile(
                    context: context,
                    icon: Icons.alt_route_rounded,
                    title: 'Clean Air Commute',
                    subtitle: 'Find the least polluted travel routes: Metro, Bus, or EV',
                    color: AppColors.leafOf(context),
                    onTap: () => _navigateTo(
                      context,
                      GreenCommuteScreen(appState: appState),
                    ),
                  ),
                  _buildNavTile(
                    context: context,
                    icon: Icons.warning_amber_rounded,
                    title: 'Weather & Disaster Alerts',
                    subtitle: 'Severe storm warnings, flood advisories, and emergency help',
                    color: AppColors.coral,
                    onTap: () => _navigateTo(
                      context,
                      DisasterAlertsScreen(appState: appState),
                    ),
                  ),
                  _buildNavTile(
                    context: context,
                    icon: Icons.directions_car,
                    title: 'Nearby Carpooling',
                    subtitle: 'Real rides and available seats within 5 km',
                    color: AppColors.leafOf(context),
                    onTap: () => _navigateTo(
                      context,
                      NearbyBoardScreen(appState: appState, carpools: true),
                    ),
                  ),
                  _buildNavTile(
                    context: context,
                    icon: Icons.volunteer_activism,
                    title: 'Community Mutual Aid',
                    subtitle:
                        'Water, power, shelter and medical requests nearby',
                    color: AppColors.leafOf(context),
                    onTap: () => _navigateTo(
                      context,
                      NearbyBoardScreen(appState: appState),
                    ),
                  ),
                  _buildNavTile(
                    context: context,
                    icon: Icons.apps_rounded,
                    title: 'All 58 Ecosystem Features',
                    subtitle: 'Climate, travel, shopping, city, community and account',
                    color: AppColors.leafOf(context),
                    onTap: () => _navigateTo(
                      context,
                      EcosystemCatalogScreen(appState: appState),
                    ),
                  ),
                  _buildSectionHeader(context, 'LEARNING & ACHIEVEMENTS'),
                  _buildNavTile(
                    context: context,
                    icon: Icons.school_rounded,
                    title: 'Daily Learning Cards',
                    subtitle:
                        'Quick 2-minute green facts, tips, and mini quizzes',
                    color: AppColors.accentOf(context),
                    onTap: () => _navigateTo(
                      context,
                      LearningScreen(appState: appState),
                    ),
                  ),
                  _buildNavTile(
                    context: context,
                    icon: Icons.military_tech_rounded,
                    title: 'Achievements & Badges',
                    subtitle: 'See your trophies and unlocked eco milestones',
                    color: AppColors.accentOf(context),
                    onTap: () => _navigateTo(
                      context,
                      AchievementsScreen(appState: appState),
                    ),
                  ),
                  _buildNavTile(
                    context: context,
                    icon: Icons.leaderboard_rounded,
                    title: 'Community Leaderboard',
                    subtitle:
                        'See who is leading the green impact in your city',
                    color: AppColors.amber,
                    onTap: () => _navigateTo(
                      context,
                      LeaderboardScreen(appState: appState),
                    ),
                  ),
                  _buildSectionHeader(context, 'ACCOUNT & PREFERENCES'),
                  _buildNavTile(
                    context: context,
                    icon: Icons.brightness_6_rounded,
                    title: 'Switch appearance',
                    subtitle: isDark ? 'Use light mode' : 'Use dark mode',
                    color: AppColors.accentOf(context),
                    onTap: appState.toggleTheme,
                  ),

                  _buildNavTile(
                    context: context,
                    icon: Icons.settings_rounded,
                    title: 'Settings',
                    subtitle:
                        'Notification preferences, units, and account details',
                    color: AppColors.accentOf(context),
                    onTap: () => _navigateTo(
                      context,
                      SettingsScreen(appState: appState),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      leading: const Icon(Icons.local_shipping_outlined),
                      title: const Text('Deliveries & emergency contacts'),
                      onTap: () => _navigateTo(
                        context,
                        DeliveryCenterScreen(appState: appState),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Footer note explaining primary navigation
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceAlt
                    : AppColors.lightSurfaceAlt,
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? AppColors.darkCardBorder
                        : AppColors.lightCardBorder,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: AppColors.accentOf(context),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All features and quick actions are in this menu. Home, Tracker, Community and Ranks stay in the footer.',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.mutedOf(context),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6, left: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: AppColors.accentOf(context),
        ),
      ),
    );
  }

  Widget _buildNavTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.inkOf(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 2,
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          subtitle: Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              height: 1.3,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.mutedOf(context),
            ),
          ),
          trailing:  Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppColors.mutedOf(context),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
