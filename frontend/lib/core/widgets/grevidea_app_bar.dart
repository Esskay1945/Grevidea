import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../../state/app_state.dart';
import '../../features/auth/login_screen.dart';
import '../../features/onboarding/baseline_setup_screen.dart';

class GrevideaAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final bool showBack;
  final VoidCallback? onBack;
  final AppState appState;
  final List<Widget>? extraActions;

  const GrevideaAppBar({
    super.key,
    this.title = 'Grevidea',
    this.subtitle = 'Live green. Lead change.',
    this.showBack = false,
    this.onBack,
    required this.appState,
    this.extraActions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(68.0);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      leading: showBack
          ? IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: primaryTextColor, size: 20),
              onPressed: onBack ?? () => Navigator.of(context).pop(),
            )
          : Builder(
              builder: (ctx) => IconButton(
                icon: Icon(Icons.menu_rounded, color: primaryTextColor, size: 26),
                tooltip: 'All 58 Features & Modules',
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
      titleSpacing: showBack ? 0 : 4,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: showBack ? 16 : 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: primaryTextColor,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.emerald,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: showBack ? 10 : 11,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
        ],
      ),
      actions: [
        if (extraActions != null) ...extraActions!,

        // ── Theme Toggle Button (Light / Dark) ───────────────────────────────
        IconButton(
          icon: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            color: AppColors.champagneGold,
            size: 21,
          ),
          tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
          onPressed: () => appState.toggleTheme(),
        ),

        // Show full chips only on main dashboard without back button
        if (!showBack) ...[

          // ── Green Points Badge Chip ────────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.champagneGold.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.eco_rounded, color: AppColors.emerald, size: 13),
                const SizedBox(width: 3),
                Text(
                  '${appState.greenPoints}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.champagneGold,
                  ),
                ),
              ],
            ),
          ),
        ],

        // ── Profile Avatar & Interactive Logout Modal ────────────────────────
        GesturefulProfileAvatar(appState: appState),
        const SizedBox(width: 8),
      ],
    );
  }
}

class GesturefulProfileAvatar extends StatelessWidget {
  final AppState appState;
  const GesturefulProfileAvatar({super.key, required this.appState});

  void _openProfileModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),

              // Profile Header Card
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.champagneGold, width: 2),
                      color: AppColors.royalForest,
                    ),
                    child: Center(
                      child: Text(
                        appState.userName.isNotEmpty ? appState.userName[0].toUpperCase() : 'U',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.champagneGold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appState.userName,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          appState.userEmail,
                          style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.emerald.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            appState.baseline.cityWard,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.emerald),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 10),

              // Theme Switch Tile
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: AppColors.champagneGold,
                ),
                title: Text(isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                trailing: Switch(
                  value: isDark,
                  activeThumbColor: AppColors.champagneGold,
                  activeTrackColor: AppColors.royalForest,
                  onChanged: (_) {
                    appState.toggleTheme();
                    Navigator.pop(ctx);
                  },
                ),
              ),

              // Edit Baseline Setup Tile
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.tune_rounded, color: AppColors.emerald),
                title: const Text('Edit Baseline & Commute Settings', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('Update wards, multi-commute, and clean energy', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BaselineSetupScreen(appState: appState, isInitialSetup: false),
                    ),
                  );
                },
              ),

              const SizedBox(height: 14),

              // Explicit Red Logout Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 18),
                  label: const Text(
                    'Log Out of Grevidea',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.coral,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    appState.logout();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => LoginScreen(appState: appState)),
                      (route) => false,
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openProfileModal(context),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 14),
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.champagneGold, width: 1.5),
        ),
        child: CircleAvatar(
          radius: 14,
          backgroundColor: AppColors.royalForest,
          child: Text(
            appState.userName.isNotEmpty ? appState.userName[0].toUpperCase() : 'U',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.champagneGold,
            ),
          ),
        ),
      ),
    );
  }
}
