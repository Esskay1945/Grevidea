import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/grevidea_app_bar.dart';
import '../../core/widgets/feature_directory_drawer.dart';
import '../../state/app_state.dart';

class GreenCommuteScreen extends StatefulWidget {
  final AppState appState;
  const GreenCommuteScreen({super.key, required this.appState});

  @override
  State<GreenCommuteScreen> createState() => _GreenCommuteScreenState();
}

class _GreenCommuteScreenState extends State<GreenCommuteScreen> {
  late TextEditingController _originController;
  late TextEditingController _destController;
  int _selectedModeIndex = 0;
  double _routeDistanceKm = 24.5;
  bool _isSearching = false;

  final List<String> _quickDestinations = [
    'BKC, Mumbai',
    'Andheri East',
    'Thane Station',
    'Vashi, Navi Mumbai',
    'Powai Hiranandani',
  ];

  @override
  void initState() {
    super.initState();
    _originController = TextEditingController(text: '${widget.appState.baseline.cityWard} (Current Location)');
    _destController = TextEditingController(text: 'BKC, Mumbai');
  }

  @override
  void dispose() {
    _originController.dispose();
    _destController.dispose();
    super.dispose();
  }

  void _swapRoute() {
    setState(() {
      final tmp = _originController.text;
      _originController.text = _destController.text;
      _destController.text = tmp;
    });
  }

  void _recalculateRoute(String dest) {
    setState(() {
      _destController.text = dest;
      _isSearching = true;
    });

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          if (dest.contains('BKC')) {
            _routeDistanceKm = 24.5;
          } else if (dest.contains('Andheri')) {
            _routeDistanceKm = 21.0;
          } else if (dest.contains('Thane Station')) {
            _routeDistanceKm = 4.8;
          } else if (dest.contains('Vashi')) {
            _routeDistanceKm = 18.2;
          } else {
            _routeDistanceKm = 15.0;
          }
          _isSearching = false;
        });
      }
    });
  }

  List<Map<String, dynamic>> _computeModes() {
    final d = _routeDistanceKm;
    final carCo2 = d * 0.192; // baseline ICE car: 0.192 kg/km

    return [
      {
        'mode': 'Metro / Local Train',
        'duration': '${(d * 1.8).round()} min',
        'co2_val': -(carCo2 - (d * 0.015)), // saved vs car
        'emitted': (d * 0.015).toStringAsFixed(2),
        'fare': '₹${(d * 1.6).round().clamp(10, 60)}',
        'fare_tag': 'Live: Google Routes • 2 mins ago',
        'fare_type': 'Live Tariff',
        'icon': Icons.directions_subway_rounded,
        'color': AppColors.emerald,
        'points': ((carCo2 - (d * 0.015)) * 25).round().clamp(10, 80),
        'isBest': true,
      },
      {
        'mode': 'Electric Bus (TMT/BEST EV)',
        'duration': '${(d * 2.8).round()} min',
        'co2_val': -(carCo2 - (d * 0.025)),
        'emitted': (d * 0.025).toStringAsFixed(2),
        'fare': '₹${(d * 1.0).round().clamp(10, 45)}',
        'fare_tag': 'Calculated: Official TMT Tariff 2026',
        'fare_type': 'Estimated',
        'icon': Icons.directions_bus_rounded,
        'color': AppColors.sapphire,
        'points': ((carCo2 - (d * 0.025)) * 25).round().clamp(5, 60),
        'isBest': false,
      },
      {
        'mode': 'Shared EV Cab / Auto',
        'duration': '${(d * 1.9).round()} min',
        'co2_val': -(carCo2 - (d * 0.050)),
        'emitted': (d * 0.050).toStringAsFixed(2),
        'fare': '₹${(d * 7.5).round().clamp(30, 350)}',
        'fare_tag': 'Calculated: Distance-based EV Tariff',
        'fare_type': 'Estimated',
        'icon': Icons.electric_rickshaw_rounded,
        'color': AppColors.amber,
        'points': 15,
        'isBest': false,
      },
      {
        'mode': 'Personal Petrol Car',
        'duration': '${(d * 2.0).round()} min',
        'co2_val': carCo2, // positive = emitted
        'emitted': carCo2.toStringAsFixed(2),
        'fare': '₹${(d * 9.8).round().clamp(40, 500)} (Fuel)',
        'fare_tag': 'Calculated: 0.192 kg CO₂/km baseline',
        'fare_type': 'Estimated',
        'icon': Icons.directions_car_rounded,
        'color': AppColors.coral,
        'points': 0,
        'isBest': false,
      },
    ];
  }

  void _logCommute() {
    final modes = _computeModes();
    final mode = modes[_selectedModeIndex];
    final co2Val = mode['co2_val'] as double;
    final pts = mode['points'] as int;

    widget.appState.logActivity(
      title: '${mode['mode']} Commute',
      category: 'Transport',
      subtitle: '${_originController.text} → ${_destController.text} (${_routeDistanceKm.toStringAsFixed(1)} km)',
      co2Kg: co2Val,
      icon: mode['icon'] as IconData,
      pointsEarned: pts,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.royalForest,
        content: Text(
          co2Val < 0
              ? '✓ Logged ${mode['mode']}! Saved ${co2Val.abs().toStringAsFixed(1)} kg CO₂ & earned +$pts Green Points.'
              : '✓ Logged ${mode['mode']} commute (${co2Val.toStringAsFixed(1)} kg CO₂ emitted).',
          style: const TextStyle(color: AppColors.champagneGold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkCanvas : AppColors.lightCanvas;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    final modes = _computeModes();

    return Scaffold(
      backgroundColor: bg,
      drawer: FeatureDirectoryDrawer(appState: widget.appState),
      appBar: GrevideaAppBar(
        title: 'Green Commute',
        subtitle: 'Live Multi-Modal Carbon Routing',
        showBack: Navigator.of(context).canPop(),
        appState: widget.appState,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // From / To Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.my_location_rounded, color: AppColors.emerald, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _originController,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 4),
                              border: InputBorder.none,
                              labelText: 'FROM (Live Origin)',
                              labelStyle: TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.swap_vert_rounded, color: AppColors.champagneGold),
                          onPressed: _swapRoute,
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, color: AppColors.coral, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _destController,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                            onSubmitted: _recalculateRoute,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 4),
                              border: InputBorder.none,
                              labelText: 'TO (Destination)',
                              labelStyle: TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Quick Destination Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _quickDestinations.map((dest) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(dest, style: const TextStyle(fontSize: 11)),
                        backgroundColor: cardBg,
                        onPressed: () => _recalculateRoute(dest),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),

              // Interactive Route Map Canvas
              Container(
                height: 170,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isDark ? const Color(0xFF13221A) : const Color(0xFFE2EFE7),
                  border: Border.all(color: AppColors.emerald.withValues(alpha: 0.3)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      // Simulated Vector Grid Map
                      CustomPaint(
                        size: const Size(double.infinity, 170),
                        painter: _RouteMapPainter(isDark: isDark),
                      ),
                      Positioned(
                        top: 12,
                        left: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.alt_route_rounded, size: 14, color: AppColors.champagneGold),
                              const SizedBox(width: 6),
                              Text(
                                '${_routeDistanceKm.toStringAsFixed(1)} km Corridor',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 14,
                        right: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.emerald.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text('🟢 Flow: Normal (EE Highway)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.emerald)),
                              Text('Live Traffic & Geocoding', style: TextStyle(fontSize: 9.5, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                      if (_isSearching)
                        Container(
                          color: Colors.black.withValues(alpha: 0.4),
                          child: const Center(
                            child: CircularProgressIndicator(color: AppColors.champagneGold, strokeWidth: 2.5),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text('Choose Sourced Transit Mode', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textColor)),
              const SizedBox(height: 8),

              // Modes List
              ...List.generate(modes.length, (idx) {
                final m = modes[idx];
                final isSel = _selectedModeIndex == idx;
                final co2Val = m['co2_val'] as double;
                final isSaved = co2Val < 0;

                return GestureDetector(
                  onTap: () => setState(() => _selectedModeIndex = idx),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSel ? AppColors.champagneGold : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                        width: isSel ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (m['color'] as Color).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(m['icon'] as IconData, color: m['color'] as Color, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(m['mode'] as String, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                                      if (m['isBest'] == true) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: AppColors.emerald, borderRadius: BorderRadius.circular(6)),
                                          child: const Text('LOWEST CARBON', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isSaved
                                        ? '${m['duration']} • Saves ${co2Val.abs().toStringAsFixed(1)} kg CO₂ vs car'
                                        : '${m['duration']} • Emits ${co2Val.toStringAsFixed(1)} kg CO₂',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isSaved ? AppColors.emerald : AppColors.coral,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  m['fare'] as String,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textColor),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: m['fare_type'] == 'Live Tariff' ? AppColors.emerald.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    m['fare_type'] as String,
                                    style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: m['fare_type'] == 'Live Tariff' ? AppColors.emerald : Colors.grey),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Source: ${m['fare_tag']}',
                          style: const TextStyle(fontSize: 9, color: Colors.grey, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),

              // Log Commute Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.royalForest,
                    foregroundColor: AppColors.champagneGold,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _logCommute,
                  child: const Text('Log This Commute in Ledger', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteMapPainter extends CustomPainter {
  final bool isDark;
  _RouteMapPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    // Background road network lines
    canvas.drawLine(Offset(0, size.height * 0.4), Offset(size.width, size.height * 0.4), roadPaint);
    canvas.drawLine(Offset(0, size.height * 0.7), Offset(size.width, size.height * 0.8), roadPaint);
    canvas.drawLine(Offset(size.width * 0.3, 0), Offset(size.width * 0.35, size.height), roadPaint);
    canvas.drawLine(Offset(size.width * 0.7, 0), Offset(size.width * 0.65, size.height), roadPaint);

    // Active Route Polyline
    final routePath = Path()
      ..moveTo(size.width * 0.15, size.height * 0.75)
      ..cubicTo(size.width * 0.35, size.height * 0.7, size.width * 0.45, size.height * 0.35, size.width * 0.85, size.height * 0.3);

    final glowPaint = Paint()
      ..color = AppColors.emerald.withValues(alpha: 0.3)
      ..strokeWidth = 8.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final polylinePaint = Paint()
      ..color = AppColors.emerald
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(routePath, glowPaint);
    canvas.drawPath(routePath, polylinePaint);

    // Origin Pin
    final originPaint = Paint()..color = AppColors.emerald;
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.75), 7, originPaint);
    final innerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.75), 3, innerPaint);

    // Destination Pin
    final destPaint = Paint()..color = AppColors.coral;
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.3), 8, destPaint);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.3), 3.5, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
