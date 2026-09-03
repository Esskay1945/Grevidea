import 'package:flutter/material.dart';
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
  DateTime _currentDate = DateTime(2025, 5, 28);

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Transport', 'co2': '5.2 kg', 'pct': 0.42, 'pctText': '42%', 'color': AppColors.sapphire, 'icon': Icons.directions_car_rounded},
    {'name': 'Energy', 'co2': '3.5 kg', 'pct': 0.28, 'pctText': '28%', 'color': AppColors.amber, 'icon': Icons.bolt_rounded},
    {'name': 'Food', 'co2': '2.0 kg', 'pct': 0.16, 'pctText': '16%', 'color': AppColors.emerald, 'icon': Icons.restaurant_rounded},
    {'name': 'Waste', 'co2': '1.0 kg', 'pct': 0.08, 'pctText': '8%', 'color': Colors.teal, 'icon': Icons.recycling_rounded},
    {'name': 'Others', 'co2': '0.7 kg', 'pct': 0.06, 'pctText': '6%', 'color': AppColors.champagneGold, 'icon': Icons.more_horiz_rounded},
  ];

  final List<double> _trendPoints = [15.2, 14.0, 16.5, 13.8, 14.2, 13.0, 12.4];

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkCanvas : AppColors.lightCanvas;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Scaffold(
      backgroundColor: bg,
      drawer: FeatureDirectoryDrawer(appState: widget.appState),
      appBar: GrevideaAppBar(
        title: 'My Tracker',
        subtitle: 'Automated Footprint Telemetry',
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
            // Period Segmented Tabs (Day / Week / Month / Year) (Matching Screen 02)
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

            // Date Navigator (< May 28, 2025 >) (Matching Screen 02)
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

            // Total CO2 Footprint Card (Matching Screen 02 in reference mockup)
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
                            '12.4',
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
                        child: const Text(
                          '↓ 16% vs yesterday',
                          style: TextStyle(color: AppColors.emerald, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  // Windmill graphic icon
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
            const SizedBox(height: 24),

            // By Category Section (Matching Screen 02)
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
                children: _categories.map((c) {
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

            // Footprint Trend Line Chart (Mon -> Sun) (Matching Screen 02)
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
                      Text('This Week', style: TextStyle(fontSize: 11, color: AppColors.champagneGold, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 120,
                    child: CustomPaint(
                      size: const Size(double.infinity, 120),
                      painter: _LineTrendPainter(points: _trendPoints, color: AppColors.emerald),
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

    // Gradient fill under curve
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

    // Draw dots
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
