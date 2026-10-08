import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../theme/app_colors.dart';
import '../../features/tracker/log_activity_screen.dart';
import '../../features/marketplace/scan_product_screen.dart';
import '../../features/civic/report_waste_screen.dart';
import '../../features/climategpt/climategpt_screen.dart';

/// The same five actions stay available while feature routes are open.
class PersistentFeatureTray extends StatelessWidget {
  final AppState appState;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  const PersistentFeatureTray(
      {super.key,
      required this.appState,
      required this.navigatorKey,
      required this.child});
  void _tab(int index) {
    appState.setMainTab(index);
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  void _wheel() {
    final context = navigatorKey.currentState?.overlay?.context;
    if (context == null) return;
    showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              const ListTile(title: Text('Quick Actions')),
              for (final action in <(String, IconData, Widget)>[
                (
                  'Log Daily Activity',
                  Icons.add_circle_outline,
                  LogActivityScreen(appState: appState)
                ),
                (
                  'Scan Product',
                  Icons.qr_code_scanner,
                  ScanProductScreen(appState: appState)
                ),
                (
                  'Report Pollution & Waste',
                  Icons.campaign_outlined,
                  ReportWasteScreen(appState: appState)
                ),
                (
                  'Ask Climate Assistant',
                  Icons.psychology_outlined,
                  ClimateGptScreen(appState: appState)
                ),
              ])
                ListTile(
                    leading: Icon(action.$2),
                    title: Text(action.$1),
                    onTap: () {
                      Navigator.pop(ctx);
                      navigatorKey.currentState
                          ?.push(MaterialPageRoute(builder: (_) => action.$3));
                    }),
            ])));
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget item(int index, IconData icon, String label) => InkWell(
        onTap: () => _tab(index),
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: AppColors.champagneGold, size: 24),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.lightTextPrimary))
            ])));
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
                      item(3, Icons.leaderboard_rounded, 'Ranks')
                    ]))),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: FloatingActionButton(
            backgroundColor: AppColors.royalForest,
            onPressed: _wheel,
            child: const Icon(Icons.energy_savings_leaf_rounded,
                color: AppColors.champagneGold)));
  }
}
