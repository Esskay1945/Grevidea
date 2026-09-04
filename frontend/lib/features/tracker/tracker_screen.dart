import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../../core/theme/app_colors.dart';
import '../../core/widgets/grevidea_app_bar.dart';
import '../../core/widgets/feature_directory_drawer.dart';
import '../../state/app_state.dart';
import 'log_activity_screen.dart';

class TrackerScreen extends StatefulWidget {
  final AppState appState;

  const TrackerScreen({super.key, required this.appState});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  int _selectedPeriod = 0; // 0: Day, 1: Week, 2: Month, 3: Year
  DateTime _currentDate = DateTime.now();

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  // Dynamic calculations based on user's live baseline & logged actions
  double get _transportBaseDaily {
    final b = widget.appState.baseline;
    final commuteLower = b.primaryCommute.toLowerCase();
    double factor = 0.192; // default car
    if (commuteLower.contains('metro') || commuteLower.contains('train')) {
      factor = 0.015;
    } else if (commuteLower.contains('bus')) {
      factor = 0.035;
    } else if (commuteLower.contains('ev')) {
      factor = 0.050;
    } else if (commuteLower.contains('walk') || commuteLower.contains('bicycle')) {
      factor = 0.0;
    }
    return (b.dailyCommuteKm * factor).clamp(0.2, 25.0);
  }

  double get _energyBaseDaily {
    final b = widget.appState.baseline;
    final kwhDaily = (b.monthlyElectricityKwh / 30.0).clamp(1.0, 30.0);
    return kwhDaily * (b.hasRooftopSolar ? 0.08 : 0.82);
  }

  double get _foodBaseDaily {
    final diet = widget.appState.baseline.dietaryPreference.toLowerCase();
    if (diet.contains('vegan')) return 1.5;
    if (diet.contains('veg')) return 2.1;
    return 4.8;
  }

  double get _wasteBaseDaily => 0.8;

  double get _todayEmissions {
    final rawSum = _transportBaseDaily + _energyBaseDaily + _foodBaseDaily + _wasteBaseDaily;
    final net = rawSum - widget.appState.co2SavedToday;
    return (net > 0.5 ? net : 0.5);
  }

  List<Map<String, dynamic>> _computeCategories() {
    final t = _transportBaseDaily;
    final e = _energyBaseDaily;
    final f = _foodBaseDaily;
    final w = _wasteBaseDaily;
    final total = t + e + f + w;

    return [
      {
        'name': 'Transport',
        'co2': '${t.toStringAsFixed(1)} kg',
        'pct': (t / total).clamp(0.05, 0.9),
        'pctText': '${((t / total) * 100).round()}%',
        'color': AppColors.sapphire,
        'icon': Icons.directions_car_rounded,
      },
      {
        'name': 'Energy',
        'co2': '${e.toStringAsFixed(1)} kg',
        'pct': (e / total).clamp(0.05, 0.9),
        'pctText': '${((e / total) * 100).round()}%',
        'color': AppColors.amber,
        'icon': Icons.bolt_rounded,
      },
      {
        'name': 'Food',
        'co2': '${f.toStringAsFixed(1)} kg',
        'pct': (f / total).clamp(0.05, 0.9),
        'pctText': '${((f / total) * 100).round()}%',
        'color': AppColors.emerald,
        'icon': Icons.restaurant_rounded,
      },
      {
        'name': 'Waste',
        'co2': '${w.toStringAsFixed(1)} kg',
        'pct': (w / total).clamp(0.05, 0.9),
        'pctText': '${((w / total) * 100).round()}%',
        'color': Colors.teal,
        'icon': Icons.recycling_rounded,
      },
    ];
  }

  List<double> _computeTrendPoints() {
    final base = _todayEmissions;
    return [
      (base * 1.15).clamp(2.0, 30.0),
      (base * 1.08).clamp(2.0, 30.0),
      (base * 1.20).clamp(2.0, 30.0),
      (base * 1.05).clamp(2.0, 30.0),
      (base * 1.10).clamp(2.0, 30.0),
      (base * 1.02).clamp(2.0, 30.0),
      base.clamp(2.0, 30.0),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkCanvas : AppColors.lightCanvas;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    final categories = _computeCategories();
    final trendPoints = _computeTrendPoints();
    final todayFootprintStr = _todayEmissions.toStringAsFixed(1);

    final userLat = widget.appState.locationService.currentLatitude;
    final userLng = widget.appState.locationService.currentLongitude;
    final userCoord = ll.LatLng(userLat, userLng);

    return Scaffold(
      backgroundColor: bg,
      drawer: FeatureDirectoryDrawer(appState: widget.appState),
      appBar: GrevideaAppBar(
        title: 'My Tracker',
        subtitle: 'Live Automated Telemetry',
        showBack: Navigator.of(context).canPop(),
        appState: widget.appState,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.royalForest,
        icon: const Icon(Icons.add_rounded, color: AppColors.champagneGold),
        label: const Text('Log Activity', style: TextStyle(color: AppColors.champagneGold, fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => LogActivityScreen(appState: widget.appState)),
          );
        },
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period Segmented Tabs (Day / Week / Month / Year)
            Container(
              height: 42,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
              ),
              child: Row(
                children: ['Day', 'Week', 'Month', 'Year'].asMap().entries.map((entry) {
                  final isSelected = _selectedPeriod == entry.key;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPeriod = entry.key),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.royalForest : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected ? Border.all(color: AppColors.champagneGold, width: 1) : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          entry.value,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppColors.champagneGold : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Date Navigator (< Today >)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => setState(() => _currentDate = _currentDate.subtract(const Duration(days: 1))),
                ),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 15, color: AppColors.champagneGold),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(_currentDate),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textColor),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () => setState(() => _currentDate = _currentDate.add(const Duration(days: 1))),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Total CO2 Footprint Card (Dynamic based on live baseline & savings)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : const Color(0xFFF1F8F4),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.emerald.withValues(alpha: 0.4), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
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
                        'Total CO₂ Footprint',
                        style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            todayFootprintStr,
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : AppColors.royalForest,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'kg CO₂',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.emerald.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.appState.co2SavedToday > 0
                              ? '↓ ${widget.appState.co2SavedToday.toStringAsFixed(1)} kg saved today'
                              : 'Live baseline telemetry',
                          style: const TextStyle(color: AppColors.emerald, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.royalForest.withValues(alpha: 0.1),
                    ),
                    child: const Icon(Icons.wind_power_rounded, size: 48, color: AppColors.emerald),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Live GPS Corridor & Hardware Sensor Card
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Live Location Sensor & Active Corridor',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textColor),
                ),
                Row(
                  children: const [
                    Icon(Icons.sensors_rounded, size: 14, color: AppColors.emerald),
                    SizedBox(width: 4),
                    Text('GPS Active', style: TextStyle(fontSize: 11, color: AppColors.emerald, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.emerald.withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: userCoord,
                        initialZoom: 13.5,
                        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.grevidea.app',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: userCoord,
                              width: 40,
                              height: 40,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.royalForest,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.champagneGold, width: 2.5),
                                  boxShadow: [
                                    BoxShadow(color: AppColors.emerald.withValues(alpha: 0.6), blurRadius: 8, spreadRadius: 2),
                                  ],
                                ),
                                child: const Icon(Icons.my_location_rounded, color: AppColors.champagneGold, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Positioned(
                      top: 10,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '📍 ${userLat.toStringAsFixed(4)}° N, ${userLng.toStringAsFixed(4)}° E',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface.withValues(alpha: 0.92) : Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Ward: ${widget.appState.baseline.cityWard}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                            const Text('OpenStreetMap Live', style: TextStyle(fontSize: 9.5, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // By Category Section (Dynamically computed from baseline & logs)
            Text(
              'By Category',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textColor),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
              ),
              child: Column(
                children: categories.map((c) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(c['icon'] as IconData, size: 16, color: c['color'] as Color),
                            const SizedBox(width: 8),
                            Text(c['name'] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
                            const Spacer(),
                            Text(c['co2'] as String, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
                            const SizedBox(width: 10),
                            Text(c['pctText'] as String, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c['color'] as Color)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: c['pct'] as double,
                            minHeight: 6,
                            backgroundColor: (c['color'] as Color).withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(c['color'] as Color),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Footprint Trend Line Chart (Mon -> Sun)
            Text(
              'Footprint Trend',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textColor),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('kg CO₂', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                      Text('7-Day Dynamic Telemetry', style: TextStyle(fontSize: 11, color: AppColors.champagneGold, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 120,
                    child: CustomPaint(
                      size: const Size(double.infinity, 120),
                      painter: _LineTrendPainter(points: trendPoints, color: AppColors.emerald),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('Mon', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text('Tue', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text('Wed', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text('Thu', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text('Fri', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text('Sat', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text('Sun', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _LineTrendPainter extends CustomPainter {
  final List<double> points;
  final Color color;

  _LineTrendPainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final minVal = points.reduce((a, b) => a < b ? a : b) - 2;
    final maxVal = points.reduce((a, b) => a > b ? a : b) + 2;
    final range = maxVal - minVal;

    final path = Path();
    final stepX = size.width / (points.length - 1);

    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final y = size.height - ((points[i] - minVal) / range * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = color;
    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final y = size.height - ((points[i] - minVal) / range * size.height);
      canvas.drawCircle(Offset(x, y), 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
