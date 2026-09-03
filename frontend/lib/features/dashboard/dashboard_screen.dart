import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/responsive_wrapper.dart';
import '../../core/widgets/grevidea_app_bar.dart';
import '../../core/widgets/feature_directory_drawer.dart';
import '../../state/app_state.dart';
import '../tracker/tracker_screen.dart';
import '../tracker/log_activity_screen.dart';
import '../insights/insights_screen.dart';
import '../insights/impact_breakdown_screen.dart';
import '../civic/aqi_map_screen.dart';
import '../civic/report_waste_screen.dart';
import '../marketplace/scan_product_screen.dart';
import '../marketplace/rewards_shop_screen.dart';
import '../climategpt/climategpt_screen.dart';
import '../gamification/challenges_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../community/community_screen.dart';
import '../profile/settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  final AppState appState;

  const DashboardScreen({super.key, required this.appState});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentTabIndex = 0;
  List<Map<String, dynamic>> _dailyTasks = [];

  final List<Map<String, dynamic>> _taskPool = [
    {
      'id': 'bus_commute',
      'title': '🚌 Public Transit Commute',
      'description': 'Take Metro, local train, or BEST/TMT bus instead of private car.',
      'category': 'Transport',
      'points': 60,
      'co2_saved': 2.1,
      'icon': Icons.directions_bus_rounded,
    },
    {
      'id': 'green_plate',
      'title': '🥗 100% Plant-Powered Meal',
      'description': 'Enjoy a plant-based, locally sourced vegetarian lunch or dinner.',
      'category': 'Food',
      'points': 50,
      'co2_saved': 1.8,
      'icon': Icons.restaurant_rounded,
    },
    {
      'id': 'solar_shift',
      'title': '☀️ Peak Load Curtailment',
      'description': 'Turn off air conditioning & geysers during peak hours (12 PM - 3 PM).',
      'category': 'Energy',
      'points': 45,
      'co2_saved': 1.2,
      'icon': Icons.solar_power_rounded,
    },
    {
      'id': 'zero_plastic',
      'title': '♻️ Zero Single-Use Plastic',
      'description': 'Carry reusable cotton cloth bag and refill bottle for all errands.',
      'category': 'Waste',
      'points': 40,
      'co2_saved': 0.8,
      'icon': Icons.shopping_bag_outlined,
    },
    {
      'id': 'cycle_walk',
      'title': '🚲 Active 3km Pedal or Walk',
      'description': 'Walk or cycle for neighborhood errands instead of auto or motorbike.',
      'category': 'Transport',
      'points': 75,
      'co2_saved': 1.5,
      'icon': Icons.directions_bike_rounded,
    },
    {
      'id': 'civic_report',
      'title': '📢 Civic Pollution Watch',
      'description': 'Report 1 garbage dumping or sewage issue directly to TMC in Grevidea.',
      'category': 'Civic',
      'points': 80,
      'co2_saved': 1.0,
      'icon': Icons.campaign_rounded,
    },
    {
      'id': 'natural_light',
      'title': '💡 Daylight Only Until Sunset',
      'description': 'Maximize cross-ventilation and natural daylight before turning on lamps.',
      'category': 'Energy',
      'points': 35,
      'co2_saved': 0.6,
      'icon': Icons.lightbulb_outline_rounded,
    },
    {
      'id': 'waste_segregation',
      'title': '🗑️ Strict 2-Bin Waste Segregation',
      'description': 'Segregate dry recyclables and wet organic waste before collection.',
      'category': 'Waste',
      'points': 40,
      'co2_saved': 0.9,
      'icon': Icons.recycling_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadDailyTasks();
  }

  void _loadDailyTasks() {
    final pool = List<Map<String, dynamic>>.from(_taskPool);
    pool.shuffle();
    final selected = pool.take(3).map((t) => {...t, 'completed': false}).toList();
    setState(() {
      _dailyTasks = selected;
    });
  }

  void _completeTask(int index) {
    if (index >= _dailyTasks.length) return;
    final task = _dailyTasks[index];
    if (task['completed'] == true) return;

    setState(() {
      _dailyTasks[index]['completed'] = true;
    });

    final pts = (task['points'] as int?) ?? 50;
    final co2 = (task['co2_saved'] as double?) ?? 1.0;
    widget.appState.logActivity(
      title: task['title'] as String,
      category: task['category'] as String,
      subtitle: task['description'] as String,
      co2Kg: -co2,
      pointsEarned: pts,
      icon: (task['icon'] as IconData?) ?? Icons.eco_rounded,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.royalForest,
        content: Text('✓ Completed: ${task['title']}! +$pts Green Points & -$co2 kg CO₂', style: const TextStyle(color: AppColors.champagneGold)),
      ),
    );
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 12) {
      return 'Good morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good afternoon';
    } else if (hour >= 17 && hour < 24) {
      // 5:00 PM to 11:59 PM is Good evening
      return 'Good evening';
    } else {
      return 'Good night';
    }
  }

  void _showInTransitPrompt(double speedKmH) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.coral.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.speed_rounded, color: AppColors.coral, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('In-Transit Detected (${speedKmH.toStringAsFixed(0)} km/h)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Text('You are moving faster than 25 km/h. Which vehicle are you using?', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _buildVehicleOption(ctx, 'Metro / Local Train', 'Zero direct emissions • 85% lower carbon', Icons.directions_subway_rounded, AppColors.emerald, -1.8, 35),
              _buildVehicleOption(ctx, 'Electric / TMT City Bus', 'High occupancy transit • 60% lower carbon', Icons.directions_bus_rounded, AppColors.sapphire, -1.2, 25),
              _buildVehicleOption(ctx, 'EV Cab / Shared Auto', 'Electric powertrain • 45% lower carbon', Icons.electric_rickshaw_rounded, AppColors.amber, -0.8, 20),
              _buildVehicleOption(ctx, 'Personal Petrol Car', 'Single occupancy • Fossil fuel combustion', Icons.directions_car_rounded, AppColors.coral, 2.4, 0),
              _buildVehicleOption(ctx, 'Motorbike / Scooter', '2-wheeler commute • Moderate fuel usage', Icons.two_wheeler_rounded, Colors.orange, 1.1, 5),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVehicleOption(BuildContext ctx, String mode, String sub, IconData icon, Color color, double co2Kg, int pts) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(mode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text(sub, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        trailing: Text(
          co2Kg < 0 ? '${co2Kg.abs()} kg saved' : '+$co2Kg kg CO₂',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: co2Kg < 0 ? AppColors.emerald : AppColors.coral),
        ),
        onTap: () {
          Navigator.pop(ctx);
          widget.appState.logActivity(
            title: '$mode Commute',
            category: 'Transport',
            subtitle: 'Speed detected trip • ${co2Kg < 0 ? "Saved ${co2Kg.abs()} kg CO2" : "Emitted $co2Kg kg CO2"}',
            co2Kg: co2Kg,
            icon: icon,
            pointsEarned: pts,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.royalForest,
              content: Text(
                co2Kg < 0
                    ? '✓ Logged $mode! Saved ${co2Kg.abs()} kg CO₂ & earned +$pts Green Points.'
                    : '✓ Logged $mode commute. CO₂ emissions updated in your ledger.',
                style: const TextStyle(color: AppColors.champagneGold),
              ),
            ),
          );
        },
      ),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Quick Eco Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.champagneGold)),
                  Icon(Icons.energy_savings_leaf_rounded, color: AppColors.emerald),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(backgroundColor: AppColors.royalForest, child: Icon(Icons.add_circle_outline_rounded, color: AppColors.champagneGold)),
                title: const Text('Log Daily Commute / Diet', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Record metro, plant meals, or solar savings'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => LogActivityScreen(appState: widget.appState)));
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: AppColors.royalForest, child: Icon(Icons.qr_code_scanner_rounded, color: AppColors.champagneGold)),
                title: const Text('Scan Product (EcoLens)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Barcode scan for packaging & lifecycle carbon'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ScanProductScreen(appState: widget.appState)));
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: AppColors.royalForest, child: Icon(Icons.delete_sweep_rounded, color: AppColors.coral)),
                title: const Text('Report Waste Hotspot', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Geotagged citizen report directly to TMC'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ReportWasteScreen(appState: widget.appState)));
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: AppColors.royalForest, child: Icon(Icons.psychology_rounded, color: AppColors.emerald)),
                title: const Text('Ask ClimateGPT', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Instant answers & local pollution guidance'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ClimateGptScreen(appState: widget.appState)));
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
    final bg = isDark ? AppColors.darkCanvas : AppColors.lightCanvas;

    final List<Widget> pages = [
      _buildHomeContent(isDark),
      TrackerScreen(appState: widget.appState),
      CommunityScreen(appState: widget.appState),
      LeaderboardScreen(appState: widget.appState),
      SettingsScreen(appState: widget.appState),
    ];

    return Scaffold(
      backgroundColor: bg,
      drawer: FeatureDirectoryDrawer(appState: widget.appState),
      appBar: _currentTabIndex == 0
          ? GrevideaAppBar(
              title: 'Grevidea',
              subtitle: 'Live green. Lead change.',
              appState: widget.appState,
            )
          : null,
      bottomNavigationBar: _buildBottomNavBar(isDark),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.royalForest,
        elevation: 6,
        onPressed: _openQuickActionWheel,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.champagneGold, width: 2),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.royalForest, Color(0xFF0F4733)],
            ),
          ),
          child: const Icon(Icons.energy_savings_leaf_rounded, color: AppColors.champagneGold, size: 28),
        ),
      ),
      body: pages[_currentTabIndex],
    );
  }

  Widget _buildBottomNavBar(bool isDark) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      elevation: 12,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.home_rounded, 'Home'),
            _buildNavItem(1, Icons.show_chart_rounded, 'Tracker'),
            const SizedBox(width: 48), // Gap for floating center leaf button
            _buildNavItem(2, Icons.people_outline_rounded, 'Community'),
            _buildNavItem(3, Icons.leaderboard_rounded, 'Ranks'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentTabIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => setState(() => _currentTabIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected
                  ? AppColors.champagneGold
                  : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected
                    ? AppColors.champagneGold
                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Home / Dashboard Screen 01 Content ──────────────────────────────────
  Widget _buildHomeContent(bool isDark) {
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return ResponsiveWrapper(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Greeting Header (Matching Screen 01)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_getTimeGreeting()}, ${widget.appState.userName}!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: textColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Here's your environmental impact summary for today.",
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Environmental Score Card (Matching Screen 01 in reference mockup)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.royalForest,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.champagneGold, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.royalForest.withValues(alpha: 0.35),
                    blurRadius: 14,
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
                      const SizedBox(height: 4),
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
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.emerald),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "You're doing better than 78% of users!",
                        style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8)),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => InsightsScreen(appState: widget.appState)));
                        },
                        child: Row(
                          children: const [
                            Text(
                              'View Insights',
                              style: TextStyle(color: AppColors.champagneGold, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded, color: AppColors.champagneGold, size: 14),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Radial Leaf Progress Meter
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.deepForest,
                      border: Border.all(color: AppColors.emerald, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.emerald.withValues(alpha: 0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.energy_savings_leaf_rounded, color: AppColors.emerald, size: 40),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4 Stats Cards in a Row (Matching Screen 01)
            Row(
              children: [
                _buildStatMiniCard('CO₂ Saved Today', '${widget.appState.co2SavedToday} kg', '↓ 18% vs avg', Icons.eco_rounded, AppColors.emerald, cardBg, isDark),
                const SizedBox(width: 8),
                _buildStatMiniCard('Streak', '${widget.appState.streakDays} days', 'Keep it up!', Icons.local_fire_department_rounded, AppColors.amber, cardBg, isDark),
                const SizedBox(width: 8),
                _buildStatMiniCard('Green Points', '${widget.appState.greenPoints}', '+150 this month', Icons.stars_rounded, AppColors.champagneGold, cardBg, isDark),
                const SizedBox(width: 8),
                _buildStatMiniCard('Trees Equiv', '${widget.appState.treesEquivalent}', 'Lifetime', Icons.park_rounded, AppColors.emerald, cardBg, isDark),
              ],
            ),
            const SizedBox(height: 18),

            // Two Cards: Your Impact Breakdown Donut & Current AQI (Thane) (Matching Screen 01)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Impact Breakdown Card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Your Impact Breakdown',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.sapphire, width: 3.5),
                              ),
                              child: const Center(
                                child: Text('12.4\nkg', textAlign: TextAlign.center, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  _MiniLegend(color: AppColors.sapphire, label: 'Transport 42%'),
                                  _MiniLegend(color: AppColors.amber, label: 'Energy 28%'),
                                  _MiniLegend(color: AppColors.emerald, label: 'Food 16%'),
                                  _MiniLegend(color: Colors.teal, label: 'Waste 8%'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ImpactBreakdownScreen(appState: widget.appState)));
                          },
                          child: const Text('Detailed Report →', style: TextStyle(color: AppColors.champagneGold, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Current AQI Thane Card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text('Current AQI (Thane)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              '${widget.appState.currentAqi}',
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.emerald),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.emerald.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.appState.aqiCategory,
                                style: const TextStyle(color: AppColors.emerald, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text('PM2.5: 21 • PM10: 38 • O3: 28', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.0, color: Colors.grey)),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => AqiMapScreen(appState: widget.appState)));
                          },
                          child: const Text('View AQI Map →', style: TextStyle(color: AppColors.champagneGold, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ── Dynamic Daily Eco-Quests ──────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt_rounded, color: AppColors.champagneGold, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      'Daily Eco-Quests',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textColor),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () {
                    _loadDailyTasks();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.royalForest,
                        duration: Duration(milliseconds: 1400),
                        content: Text('🔀 Shuffled! New random daily quests assigned.', style: TextStyle(color: AppColors.champagneGold)),
                      ),
                    );
                  },
                  icon: const Icon(Icons.shuffle_rounded, size: 14, color: AppColors.champagneGold),
                  label: const Text('Shuffle Quests', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.champagneGold)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Column(
              children: List.generate(_dailyTasks.length, (i) {
                final task = _dailyTasks[i];
                final isDone = task['completed'] == true;
                final pts = task['points'] as int? ?? 50;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDone
                        ? (isDark ? const Color(0xFF13281D) : const Color(0xFFE8F5E9))
                        : (isDark ? AppColors.darkSurface : const Color(0xFFF9F6ED)),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDone ? AppColors.emerald : AppColors.champagneGold.withValues(alpha: 0.35),
                      width: isDone ? 1.2 : 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDone
                              ? AppColors.emerald.withValues(alpha: 0.2)
                              : AppColors.royalForest.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          task['icon'] as IconData? ?? Icons.eco_rounded,
                          color: isDone ? AppColors.emerald : AppColors.champagneGold,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task['title'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                decoration: isDone ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              task['description'] as String,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: isDone ? null : () => _completeTask(i),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDone ? Colors.transparent : AppColors.royalForest,
                          elevation: isDone ? 0 : 2,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: isDone ? const BorderSide(color: AppColors.emerald) : BorderSide.none,
                          ),
                        ),
                        child: Text(
                          isDone ? 'Claimed ✓' : '+$pts pts',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDone ? AppColors.emerald : AppColors.champagneGold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),

            // Quick Actions Horizontal Pills (Matching Screen 01 in reference mockup)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Quick Actions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textColor)),
                InkWell(
                  onTap: () => _showInTransitPrompt(32.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.royalForest,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.champagneGold.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.speed_rounded, size: 12, color: AppColors.champagneGold),
                        SizedBox(width: 4),
                        Text('Transit Tracker', style: TextStyle(fontSize: 10, color: AppColors.champagneGold, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickActionChip('Log Activity', Icons.add_circle_outline_rounded, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => LogActivityScreen(appState: widget.appState)));
                  }, isDark),
                  _buildQuickActionChip('Scan Product', Icons.qr_code_scanner_rounded, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ScanProductScreen(appState: widget.appState)));
                  }, isDark),
                  _buildQuickActionChip('AQI Map', Icons.map_rounded, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => AqiMapScreen(appState: widget.appState)));
                  }, isDark),
                  _buildQuickActionChip('Leaderboard', Icons.leaderboard_rounded, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => LeaderboardScreen(appState: widget.appState)));
                  }, isDark),
                  _buildQuickActionChip('Challenges', Icons.flag_rounded, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChallengesScreen(appState: widget.appState)));
                  }, isDark),
                  _buildQuickActionChip('Rewards Shop', Icons.storefront_rounded, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => RewardsShopScreen(appState: widget.appState)));
                  }, isDark),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Recent Activities Header (Matching Screen 01)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Activities', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textColor)),
                GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => LogActivityScreen(appState: widget.appState)));
                  },
                  child: const Text('See All', style: TextStyle(fontSize: 11, color: AppColors.champagneGold, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Recent 3 Activities
            ...widget.appState.recentActivities.take(3).map((act) {
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.royalForest.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(act.icon, color: AppColors.emerald, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(act.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
                          Text(act.subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Text(
                      act.co2Kg < 0 ? '${act.co2Kg.abs().toStringAsFixed(1)} kg saved' : '${act.co2Kg.toStringAsFixed(1)} kg',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: act.co2Kg < 0 ? AppColors.emerald : Colors.grey,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildStatMiniCard(String label, String val, String sub, IconData icon, Color color, Color cardBg, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(val, maxLines: 1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 2),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 8.5, color: Colors.grey)),
            const SizedBox(height: 2),
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionChip(String label, IconData icon, VoidCallback onTap, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(icon, color: AppColors.champagneGold, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        side: BorderSide(color: AppColors.champagneGold.withValues(alpha: 0.35)),
        onPressed: onTap,
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
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9.0, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
