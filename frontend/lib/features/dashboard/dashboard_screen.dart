import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/responsive_wrapper.dart';
import '../../core/widgets/curved_nav_bar.dart';
import '../../core/widgets/gold_sparkline.dart';
import '../../core/widgets/terrarium_3d_widget.dart';
import '../../state/app_state.dart';
import '../tracker/tracker_screen.dart';
import '../civic/civic_screen.dart';
import '../marketplace/marketplace_screen.dart';
import '../climategpt/climategpt_screen.dart';
import '../profile/profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  final AppState appState;

  const DashboardScreen({super.key, required this.appState});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentTabIndex = 0;

  void _openCameraScanner() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 18),
              const Icon(Icons.qr_code_scanner_rounded, color: AppColors.champagneGold, size: 48),
              const SizedBox(height: 12),
              const Text('EcoLens Camera Scanner', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text(
                'Point camera at any packaged item to scan barcodes (Open Food Facts) or classify waste materials via AI.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Simulate Barcode Scan (Amul Milk / Parle)'),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.royalForest,
                        content: Text('✓ Scanned: 100% Recyclable TetraPak (Eco-Score: A, Carbon: 0.18 kg CO₂)', style: TextStyle(color: AppColors.champagneGold, fontWeight: FontWeight.w600)),
                      ),
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

  void _openQuickActionWheel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Quick Action Hub', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.champagneGold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(backgroundColor: AppColors.royalForest, child: Icon(Icons.directions_subway_rounded, color: AppColors.champagneGold)),
                title: const Text('Log Daily Commute'),
                subtitle: const Text('Record metro, bus, or EV trip to claim points'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() => _currentTabIndex = 1);
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: AppColors.royalForest, child: Icon(Icons.delete_sweep_rounded, color: AppColors.champagneGold)),
                title: const Text('Report Waste Hotspot'),
                subtitle: const Text('Submit geotagged photo to municipal squad'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() => _currentTabIndex = 3);
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: AppColors.royalForest, child: Icon(Icons.smart_toy_rounded, color: AppColors.champagneGold)),
                title: const Text('Ask ClimateGPT'),
                subtitle: const Text('Scientific climate assistant & fact-checker'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClimateGptScreen(appState: widget.appState)));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Body content based on active tab
    Widget activeBody;
    switch (_currentTabIndex) {
      case 1:
        activeBody = TrackerScreen(appState: widget.appState);
        break;
      case 3:
        activeBody = CivicScreen(appState: widget.appState);
        break;
      case 4:
        activeBody = ProfileScreen(appState: widget.appState);
        break;
      case 0:
      default:
        activeBody = _buildDashboardContent(context, isDark);
        break;
    }

    return Scaffold(
      body: activeBody,
      bottomNavigationBar: CurvedNavBar(
        currentIndex: _currentTabIndex,
        onTabSelected: (index) {
          setState(() => _currentTabIndex = index);
        },
        onCenterCrestTap: _openQuickActionWheel,
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context, bool isDark) {
    final state = widget.appState;

    return ResponsiveWrapper(
      applyBottomPadding: false,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top App Bar: Logo on Left, CAMERA on Right (Replaces Bell) ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.royalForest,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.champagneGold, width: 1.5),
                      ),
                      child: const Icon(Icons.eco_rounded, color: AppColors.champagneGold, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Grevidea',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.royalForest,
                          ),
                        ),
                        const Text(
                          'Live green. Lead change.',
                          style: TextStyle(fontSize: 10, color: AppColors.champagneGold, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),

                // Camera Action Icon (placed exactly where bell was as instructed!)
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    shape: BoxShape.circle,
                    border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.camera_alt_rounded, color: AppColors.champagneGold, size: 22),
                    tooltip: 'EcoLens Camera Scanner',
                    onPressed: _openCameraScanner,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Greeting Yash
            Text(
              'Good morning, ${state.userName}! 🌿',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkTextPrimary : AppColors.royalForest,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Here's your environmental impact summary for today.",
              style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ),

            const SizedBox(height: 18),

            // ── Hero Card: Environmental Score 82/100 with Terrarium3DWidget ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: AppColors.royalForest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.champagneGold.withOpacity(0.4), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Environmental Score',
                          style: TextStyle(fontSize: 13, color: AppColors.champagneGold, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${state.score}',
                              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                            const Text(
                              '/100',
                              style: TextStyle(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Great!',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.emerald),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "You're doing better than 78% of urban users!",
                          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
                        ),
                      ],
                    ),
                  ),
                  // The 3D Terrarium Orb Widget
                  Terrarium3DWidget(score: state.score, size: 124),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── 4 Quick Metric Cards with Gold Sparklines ─────────────────
            Row(
              children: [
                _MetricCard(
                  label: 'CO₂ Saved',
                  value: '${state.co2SavedToday} kg',
                  sub: '↑ 18% today',
                  icon: Icons.eco_rounded,
                  sparkline: const [1.2, 1.6, 2.0, 1.8, 2.1, 2.4],
                ),
                const SizedBox(width: 8),
                _MetricCard(
                  label: 'Streak',
                  value: '${state.streakDays} days',
                  sub: 'Keep it up!',
                  icon: Icons.local_fire_department_rounded,
                  sparkline: const [8, 9, 10, 11, 12, 13, 14],
                ),
                const SizedBox(width: 8),
                _MetricCard(
                  label: 'Points',
                  value: '${state.greenPoints}',
                  sub: '↑ 120 wk',
                  icon: Icons.stars_rounded,
                  sparkline: const [650, 680, 720, 750, 790, 812],
                ),
                const SizedBox(width: 8),
                _MetricCard(
                  label: 'Trees Equiv',
                  value: '${state.treesEquivalent}',
                  sub: 'This month',
                  icon: Icons.park_rounded,
                  sparkline: const [1.0, 1.4, 1.8, 2.1, 2.4, 2.6],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Split Row: Impact Breakdown & Current AQI ─────────────────
            Row(
              children: [
                // Impact Breakdown Donut Card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Impact Breakdown', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 72,
                                height: 72,
                                child: CircularProgressIndicator(
                                  value: 0.72,
                                  strokeWidth: 8,
                                  backgroundColor: Colors.grey.withOpacity(0.15),
                                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.champagneGold),
                                ),
                              ),
                              const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('12.4', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                                  Text('kg CO₂', style: TextStyle(fontSize: 9, color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const _MiniLegend(color: AppColors.champagneGold, label: 'Transport 42%'),
                        const _MiniLegend(color: AppColors.emerald, label: 'Energy 28%'),
                        const _MiniLegend(color: AppColors.amber, label: 'Food 16%'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Current AQI Card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Current AQI', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.emerald.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                              child: const Text('Live', style: TextStyle(fontSize: 9, color: AppColors.emerald, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text('${state.currentAqi}', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: AppColors.emerald)),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(state.aqiCategory, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.emerald)),
                                const Text('Thane West', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text('Air quality is satisfactory for outdoor workouts.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        const Divider(height: 16),
                        const Text('PM2.5: 21  |  PM10: 38', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Today's Challenge Banner ──────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.champagneGold.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.royalForest, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.shopping_bag_outlined, color: AppColors.champagneGold, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text("Today's Challenge", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.champagneGold.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                              child: const Text('+50 Points', style: TextStyle(fontSize: 10, color: AppColors.champagneGold, fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text('Avoid single-use plastic today', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), minimumSize: Size.zero),
                    onPressed: state.challengeAccepted
                        ? null
                        : () {
                            state.acceptChallenge();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: AppColors.royalForest,
                                content: Text('✓ Challenge accepted! +50 points added to your vault.', style: TextStyle(color: AppColors.champagneGold, fontWeight: FontWeight.w600)),
                              ),
                            );
                          },
                    child: Text(state.challengeAccepted ? 'Accepted' : 'Accept', style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Quick Actions Row ─────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Quick Actions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextPrimary : AppColors.royalForest)),
                GestureDetector(
                  onTap: () => setState(() => _currentTabIndex = 3),
                  child: const Text('View All', style: TextStyle(fontSize: 12, color: AppColors.champagneGold, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ActionButton(icon: Icons.directions_bike_rounded, label: 'Log Activity', onTap: () => setState(() => _currentTabIndex = 1)),
                _ActionButton(icon: Icons.qr_code_scanner_rounded, label: 'Scan Product', onTap: _openCameraScanner),
                _ActionButton(icon: Icons.delete_outline_rounded, label: 'Report Waste', onTap: () => setState(() => _currentTabIndex = 3)),
                _ActionButton(icon: Icons.air_rounded, label: 'Check AQI', onTap: () => setState(() => _currentTabIndex = 3)),
                _ActionButton(icon: Icons.card_giftcard_rounded, label: 'Rewards', onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => MarketplaceScreen(appState: widget.appState)));
                }),
              ],
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final List<double> sparkline;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.sparkline,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 16, color: AppColors.champagneGold),
                GoldSparkline(data: sparkline, height: 14),
              ],
            ),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 1),
            Text(label, style: const TextStyle(fontSize: 9.5, color: Colors.grey)),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(fontSize: 8.5, color: AppColors.champagneGold, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _MiniLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _MiniLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3.0),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              shape: BoxShape.circle,
              border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
            ),
            child: Icon(icon, color: AppColors.champagneGold, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
