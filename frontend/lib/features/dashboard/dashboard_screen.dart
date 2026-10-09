import 'package:flutter/material.dart';
import '../../core/widgets/feature_directory_drawer.dart';
import '../../core/widgets/autumn_tree.dart';
import '../../state/app_state.dart';

class DashboardScreen extends StatefulWidget {
  final AppState appState;

  const DashboardScreen({super.key, required this.appState});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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
      'description':
          'Turn off air conditioning & geysers during peak hours (12 PM - 3 PM).',
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
      'description':
          'Walk or cycle for neighborhood errands instead of auto or motorbike.',
      'category': 'Transport',
      'points': 75,
      'co2_saved': 1.5,
      'icon': Icons.directions_bike_rounded,
    },
    {
      'id': 'civic_report',
      'title': '📢 Civic Pollution Watch',
      'description':
          'Report 1 garbage dumping or sewage issue directly to TMC in Grevidea.',
      'category': 'Civic',
      'points': 80,
      'co2_saved': 1.0,
      'icon': Icons.campaign_rounded,
    },
    {
      'id': 'natural_light',
      'title': '💡 Daylight Only Until Sunset',
      'description':
          'Maximize cross-ventilation and natural daylight before turning on lamps.',
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
        .map((t) => {
              ...t,
              'completed': widget.appState.isTaskClaimed(t['id'] as String)
            })
        .toList();
    setState(() {
      _dailyTasks = selected;
    });
  }

  void _completeTask(int index) {
    if (index >= _dailyTasks.length) return;
    final task = _dailyTasks[index];
    if (task['completed'] == true ||
        !widget.appState.claimTask(task['id'] as String)) return;

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
        backgroundColor: const Color(0xFF874527),
        content: Text(
            '✓ Completed: ${task['title']}! +$pts Green Points & -$co2 kg CO₂',
            style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  bool _transitPrompted = false;
  void _checkTransit() {
    if (mounted) setState(() {});
    if (!_transitPrompted &&
        (widget.appState.locationService.highSpeed ||
            widget.appState.pendingTrip != null)) {
      _transitPrompted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showInTransitPrompt(25);
      });
    }
    if (!widget.appState.locationService.highSpeed &&
        widget.appState.pendingTrip == null) _transitPrompted = false;
  }

  void _showInTransitPrompt(double speedKmH) {
    showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              const ListTile(
                  title: Text('Which transport are you using?'),
                  subtitle: Text(
                      'GPS detects speed, but cannot reliably identify a car, bus or metro. Choose when safe.')),
              for (final mode in ['metro', 'bus', 'ev_car', 'car'])
                ListTile(
                    title: Text(mode.replaceAll('_', ' ')),
                    onTap: () {
                      widget.appState.selectTransitMode(mode);
                      Navigator.pop(ctx);
                    }),
            ])));
  }

  @override
  void dispose() {
    widget.appState.removeListener(_checkTransit);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? const Color(0xFFFFEBD6) : const Color(0xFF38271F);
    final muted = dark ? const Color(0xFFD3B99F) : const Color(0xFF735B49);
    final accent = dark ? const Color(0xFFF0AC72) : const Color(0xFFA84928);
    final surface = dark ? const Color(0xFF33231D) : const Color(0xFFFFFBF4);
    final score = widget.appState.score;
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF211711) : const Color(0xFFF7EADB),
      drawer: FeatureDirectoryDrawer(appState: widget.appState),
      appBar: AppBar(
        backgroundColor: dark ? const Color(0xFF211711) : const Color(0xFFF7EADB),
        foregroundColor: ink,
        title: Text('Grevidea', style: TextStyle(color: ink, fontSize: 22, fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 170, child: AutumnTree()),
                  Card(
                    color: surface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Environment score', style: TextStyle(color: ink, fontSize: 18, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          Text('$score / 100', style: TextStyle(color: accent, fontSize: 40, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(value: (score / 100).clamp(0.0, 1.0), color: accent, backgroundColor: accent.withValues(alpha: 0.15), minHeight: 8),
                          ),
                          const SizedBox(height: 12),
                          Text('Estimated from your baseline and logged habits.', style: TextStyle(color: muted, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Daily tasks', style: TextStyle(color: ink, fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  for (var i = 0; i < _dailyTasks.length; i++)
                    Card(
                      color: surface,
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Checkbox(
                                value: _dailyTasks[i]['completed'] == true || _dailyTasks[i]['checked'] == true,
                                activeColor: accent,
                                side: BorderSide(color: muted),
                                onChanged: _dailyTasks[i]['completed'] == true ? null : (value) => setState(() => _dailyTasks[i]['checked'] = value == true),
                              ),
                              Expanded(child: Text(_dailyTasks[i]['title'] as String, style: TextStyle(color: ink, fontSize: 16, fontWeight: FontWeight.w600))),
                            ]),
                            Text(_dailyTasks[i]['description'] as String, style: TextStyle(color: muted, fontSize: 14, height: 1.45)),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton(
                                style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: dark ? const Color(0xFF211711) : Colors.white, disabledForegroundColor: muted, disabledBackgroundColor: accent.withValues(alpha: 0.12)),
                                onPressed: _dailyTasks[i]['completed'] == true || _dailyTasks[i]['checked'] != true ? null : () => _completeTask(i),
                                child: Text(_dailyTasks[i]['completed'] == true ? 'Claimed ✓' : 'Claim +${_dailyTasks[i]['points']} points'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
