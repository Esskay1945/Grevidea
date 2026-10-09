import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/responsive_wrapper.dart';
import '../../core/widgets/forest_backdrop.dart';
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
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentTabIndex = 0;
  final Set<int> _visitedTabs = {0};
  List<Map<String, dynamic>> _dailyTasks = [];

  final List<Map<String, dynamic>> _taskPool = [
    {
      'id': 'bus_commute',
      'title': '🚌 Public Transit Commute',
      'description':
          'Take Metro, local train, or BEST/TMT bus instead of private car.',
      'category': 'Transport',
      'points': 60,
      'co2_saved': 2.1,
      'icon': Icons.directions_bus_rounded,
    },
    {
      'id': 'green_plate',
      'title': '🥗 100% Plant-Powered Meal',
      'description':
          'Enjoy a plant-based, locally sourced vegetarian lunch or dinner.',
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
      'description':
          'Carry reusable cotton cloth bag and refill bottle for all errands.',
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
      'description':
          'Segregate dry recyclables and wet organic waste before collection.',
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
    widget.appState.addListener(_checkTransit);
  }

  void _loadDailyTasks() {
    final pool = List<Map<String, dynamic>>.from(_taskPool);
    final today = DateTime.now();
    final shift =
        DateTime(today.year, today.month, today.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay %
        pool.length;
    final rotated = [...pool.skip(shift), ...pool.take(shift)];
    final selected = rotated
        .take(3)
        .map(
          (t) => {
            ...t,
            'completed': widget.appState.isTaskClaimed(t['id'] as String),
          },
        )
        .toList();
    setState(() {
      _dailyTasks = selected;
    });
  }

  void _completeTask(int index) {
    if (index >= _dailyTasks.length) return;
    final task = _dailyTasks[index];
    if (task['completed'] == true ||
        !widget.appState.claimTask(task['id'] as String))
      return;

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
        content: Text(
          '✓ Completed: ${task['title']}! +$pts Green Points & -$co2 kg CO₂',
          style: TextStyle(color: AppColors.champagneGold),
        ),
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
      return 'Good evening';
    }
  }

  bool _transitPrompted = false;
  void _checkTransit() {
    if (_currentTabIndex != widget.appState.mainTab)
      setState(() => _currentTabIndex = widget.appState.mainTab);
    if (!_transitPrompted &&
        (widget.appState.locationService.highSpeed ||
            widget.appState.pendingTrip != null)) {
      _transitPrompted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showInTransitPrompt(25);
      });
    }
    if (!widget.appState.locationService.highSpeed &&
        widget.appState.pendingTrip == null)
      _transitPrompted = false;
  }

  void _showInTransitPrompt(double speedKmH) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Which transport are you using?'),
              subtitle: Text(
                'GPS detects speed, but cannot reliably identify a car, bus or metro. Choose when safe.',
              ),
            ),
            for (final mode in ['metro', 'bus', 'ev_car', 'car'])
              ListTile(
                title: Text(mode.replaceAll('_', ' ')),
                onTap: () {
                  widget.appState.selectTransitMode(mode);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.appState.removeListener(_checkTransit);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkCanvas : AppColors.lightCanvas;

    _visitedTabs.add(_currentTabIndex);
    final List<Widget> pages = [
      _buildHomeContent(isDark),
      TrackerScreen(appState: widget.appState),
      CommunityScreen(appState: widget.appState),
      LeaderboardScreen(appState: widget.appState),
      SettingsScreen(appState: widget.appState),
    ];

    return Scaffold(
      key: _scaffoldKey,
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
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.champagneGold, width: 2),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.royalForest, Color(0xFFC56C40)],
            ),
          ),
          child: Icon(
            Icons.energy_savings_leaf_rounded,
            color: AppColors.champagneGold,
            size: 28,
          ),
        ),
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: List.generate(
          pages.length,
          (i) => _visitedTabs.contains(i) ? pages[i] : const SizedBox.shrink(),
        ),
      ),
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
      onTap: () => widget.appState.setMainTab(index),
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
                  ? AppColors.accentOf(context)
                  : (isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected
                    ? AppColors.accentOf(context)
                    : (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary),
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
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;

    return ResponsiveWrapper(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Greeting Header
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
                        maxLines: 2,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Here is your green summary for today.",
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  label: 'Autumn tree. Tap to release leaves',
                  button: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) => ForestBackdrop.releaseLeaves(
                      context,
                      details.globalPosition,
                    ),
                    child: const SizedBox(width: 64, height: 64),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Environmental Score Card
            GestureDetector(
              onTap: () => widget.appState.setMainTab(1),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.accentOf(context),
                    width: 1.5,
                  ),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Environmental Score',
                            style: TextStyle(
                              color: AppColors.mutedOf(context),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '${widget.appState.score}',
                                style: TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.accentOf(context),
                                  letterSpacing: -1,
                                ),
                              ),
                              Text(
                                ' /100',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.mutedOf(context),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Great!',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accentOf(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Score estimated from your baseline and logged habits.",
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.inkOf(context)
                                  .withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () {
                              widget.appState.setMainTab(1);
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    'View Full Details in Tracker',
                                    style: TextStyle(
                                      color: AppColors.accentOf(context),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: AppColors.accentOf(context),
                                  size: 14,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Radial Leaf Progress Meter
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? AppColors.darkSurfaceAlt
                            : AppColors.lightSurfaceAlt,
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkSurfaceAlt
                              : AppColors.lightSurfaceAlt,
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentOf(context)
                                .withValues(alpha: 0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 82,
                            height: 82,
                            child: CircularProgressIndicator(
                              value: (widget.appState.score / 100).clamp(
                                0.0,
                                1.0,
                              ),
                              strokeWidth: 4,
                              color: AppColors.accentOf(context),
                              backgroundColor: isDark
                                  ? AppColors.darkSurfaceAlt
                                  : AppColors.lightSurfaceAlt,
                            ),
                          ),
                          Icon(
                            Icons.energy_savings_leaf_rounded,
                            color: AppColors.accentOf(context),
                            size: 40,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),

            // ── Today's Easy Tasks ─────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      color: AppColors.accentOf(context),
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Today's Easy Tasks",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
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
                        content: Text(
                          'Today’s tasks refreshed.',
                          style: TextStyle(color: AppColors.champagneGold),
                        ),
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.shuffle_rounded,
                    size: 14,
                    color: AppColors.accentOf(context),
                  ),
                  label: Text(
                    'Refresh',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accentOf(context),
                    ),
                  ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDone
                        ? (isDark
                              ? AppColors.darkSurfaceAlt
                              : AppColors.lightSurfaceAlt)
                        : (isDark
                              ? AppColors.darkSurface
                              : AppColors.lightSurface),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDone
                          ? AppColors.accentOf(context)
                          : AppColors.accentOf(context).withValues(alpha: 0.35),
                      width: isDone ? 1.2 : 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDone
                              ? AppColors.accentOf(context)
                                    .withValues(alpha: 0.2)
                              : AppColors.royalForest.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Checkbox(
                          value: isDone || task['checked'] == true,
                          onChanged: isDone
                              ? null
                              : (value) => setState(
                                  () => task['checked'] = value == true,
                                ),
                          activeColor: AppColors.accentOf(context),
                          checkColor: isDark ? AppColors.midnightObsidian : Colors.white,
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
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                                decoration: isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              task['description'] as String,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: isDone || task['checked'] != true
                            ? null
                            : () => _completeTask(i),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDone
                              ? Colors.transparent
                              : AppColors.royalForest,
                          elevation: isDone ? 0 : 2,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: isDone
                                ? BorderSide(color: AppColors.accentOf(context))
                                : BorderSide.none,
                          ),
                        ),
                        child: Text(
                          isDone ? 'Claimed ✓' : '+$pts pts',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDone
                                ? AppColors.accentOf(context)
                                : AppColors.champagneGold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildStatMiniCard(
    String label,
    String val,
    String sub,
    IconData icon,
    Color color,
    Color cardBg,
    bool isDark,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? AppColors.darkCardBorder
                : AppColors.lightCardBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
            ),
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
              child: Text(
                val,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 8.5,
                color: AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 8,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionChip(
    String label,
    IconData icon,
    VoidCallback onTap,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(icon, color: AppColors.accentOf(context), size: 16),
        label: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        side: BorderSide(
          color: AppColors.accentOf(context).withValues(alpha: 0.35),
        ),
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
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9.0,
                color: AppColors.lightTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
