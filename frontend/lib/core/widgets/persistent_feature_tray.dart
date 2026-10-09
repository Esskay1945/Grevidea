import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../theme/app_colors.dart';
import 'feature_directory_drawer.dart';

/// The same five actions stay available while feature routes are open.
class PersistentFeatureTray extends StatelessWidget {
  final AppState appState;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  const PersistentFeatureTray({
    super.key,
    required this.appState,
    required this.navigatorKey,
    required this.child,
  });
  void _tab(int index) {
    appState.setMainTab(index);
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  void _wheel() {
    final context = navigatorKey.currentState?.overlay?.context;
    if (context == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: FeatureDirectoryDrawer(appState: appState),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget item(int index, IconData icon, String label) => InkWell(
      onTap: () => _tab(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.accentOf(context), size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: AppColors.inkOf(context)),
            ),
          ],
        ),
      ),
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: child,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: dark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 12,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              item(0, Icons.home_rounded, 'Home'),
              item(1, Icons.show_chart_rounded, 'Tracker'),
              const SizedBox(width: 48),
              item(2, Icons.people_outline_rounded, 'Community'),
              item(3, Icons.leaderboard_rounded, 'Ranks'),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.royalForest,
        onPressed: _wheel,
        child: Icon(
          Icons.energy_savings_leaf_rounded,
          color: AppColors.champagneGold,
        ),
      ),
    );
  }
}
