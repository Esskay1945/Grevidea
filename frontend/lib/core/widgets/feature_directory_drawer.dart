import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../../state/app_state.dart';
import '../../features/tracker/green_commute_screen.dart';
import '../../features/civic/disaster_alerts_screen.dart';
import '../../features/gamification/achievements_screen.dart';
import '../../features/learning/learning_screen.dart';
import '../../features/profile/settings_screen.dart';

/// Extended Modules & Civic Tools Drawer
/// Contains specialized modules not directly present on the bottom navigation or main dashboard.
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
                border: Border(bottom: BorderSide(color: AppColors.goldBorder, width: 1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.champagneGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.champagneGold),
                        ),
                        child: const Icon(Icons.hub_rounded, color: AppColors.champagneGold, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Extended Tools',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.champagneGold,
                            ),
                          ),
                          Text(
                            'Civic, Hazard & Specialized Modules',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // User Status Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Rank #7 • ${appState.userName}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.eco_rounded, color: AppColors.emerald, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${appState.greenPoints} pts',
                              style: const TextStyle(color: AppColors.champagneGold, fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Filtered Non-Redundant Extended Features List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                children: [
                  _buildSectionHeader('CIVIC GOVERNANCE & RESILIENCE'),
                  _buildNavTile(
                    context: context,
                    icon: Icons.warning_amber_rounded,
                    title: 'Disaster Alerts & SOS',
                    subtitle: 'Thane flood hazard alerts, radar & emergency SOS beacon (T36, T37)',
                    color: AppColors.coral,
                    onTap: () => _navigateTo(context, DisasterAlertsScreen(appState: appState)),
                  ),

                  _buildSectionHeader('MOBILITY & EDUCATION'),
                  _buildNavTile(
                    context: context,
                    icon: Icons.alt_route_rounded,
                    title: 'Green Commute Route Advisor',
                    subtitle: 'Multi-modal route emissions comparison: Metro vs Bus vs EV vs Car (T12)',
                    color: AppColors.emerald,
                    onTap: () => _navigateTo(context, GreenCommuteScreen(appState: appState)),
                  ),
                  _buildNavTile(
                    context: context,
                    icon: Icons.school_rounded,
                    title: 'Climate Learn (Micro-Quizzes)',
                    subtitle: '2-minute daily bite-sized climate wisdom cards & quiz rewards (T57)',
                    color: AppColors.champagneGold,
                    onTap: () => _navigateTo(context, LearningScreen(appState: appState)),
                  ),

                  _buildSectionHeader('RECOGNITION & SYSTEM'),
                  _buildNavTile(
                    context: context,
                    icon: Icons.military_tech_rounded,
                    title: 'Achievements & Badges',
                    subtitle: 'Metallic trophies, milestone tracking & sustainability honors (T40)',
                    color: AppColors.champagneGold,
                    onTap: () => _navigateTo(context, AchievementsScreen(appState: appState)),
                  ),
                  _buildNavTile(
                    context: context,
                    icon: Icons.settings_rounded,
                    title: 'Settings',
                    subtitle: 'Notification preferences, units, connected apps & system controls',
                    color: AppColors.champagneGold,
                    onTap: () => _navigateTo(context, SettingsScreen(appState: appState)),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Footer note explaining primary navigation
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt,
                border: Border(top: BorderSide(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline_rounded, size: 14, color: AppColors.champagneGold),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Primary tools (Home, Tracker, Community, Leaderboard & Action Wheel) are directly on your bottom bar.',
                      style: TextStyle(fontSize: 10, color: Colors.grey, height: 1.3),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6, left: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: AppColors.champagneGold,
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
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
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
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
