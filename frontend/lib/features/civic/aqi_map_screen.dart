import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/grevidea_app_bar.dart';
import '../../core/widgets/feature_directory_drawer.dart';
import '../../state/app_state.dart';

class AqiMapScreen extends StatefulWidget {
  final AppState appState;
  const AqiMapScreen({super.key, required this.appState});

  @override
  State<AqiMapScreen> createState() => _AqiMapScreenState();
}

class _AqiMapScreenState extends State<AqiMapScreen> {
  final TransformationController _transformationController = TransformationController();
  double _currentScale = 1.0;
  Map<String, dynamic>? _selectedMarker;

  // Level 1: Global / World Mega Hubs (Zoom < 1.1)
  final List<Map<String, dynamic>> _worldHubs = [
    {'name': 'Tokyo', 'region': 'Japan', 'aqi': 28, 'status': 'Good', 'color': AppColors.emerald, 'x': 0.82, 'y': 0.35, 'pm25': 8.2},
    {'name': 'London', 'region': 'United Kingdom', 'aqi': 35, 'status': 'Good', 'color': AppColors.emerald, 'x': 0.46, 'y': 0.28, 'pm25': 10.4},
    {'name': 'New York', 'region': 'United States', 'aqi': 42, 'status': 'Good', 'color': AppColors.emerald, 'x': 0.28, 'y': 0.32, 'pm25': 12.1},
    {'name': 'Mumbai MMR', 'region': 'India', 'aqi': 54, 'status': 'Moderate', 'color': AppColors.amber, 'x': 0.64, 'y': 0.46, 'pm25': 28.4},
    {'name': 'Delhi NCR', 'region': 'India', 'aqi': 245, 'status': 'Poor', 'color': AppColors.coral, 'x': 0.65, 'y': 0.40, 'pm25': 112.0},
    {'name': 'Beijing', 'region': 'China', 'aqi': 88, 'status': 'Moderate', 'color': AppColors.amber, 'x': 0.76, 'y': 0.36, 'pm25': 36.2},
    {'name': 'Sydney', 'region': 'Australia', 'aqi': 18, 'status': 'Good', 'color': AppColors.emerald, 'x': 0.86, 'y': 0.72, 'pm25': 5.0},
    {'name': 'Paris', 'region': 'France', 'aqi': 32, 'status': 'Good', 'color': AppColors.emerald, 'x': 0.48, 'y': 0.30, 'pm25': 9.5},
    {'name': 'São Paulo', 'region': 'Brazil', 'aqi': 65, 'status': 'Moderate', 'color': AppColors.amber, 'x': 0.34, 'y': 0.68, 'pm25': 24.1},
  ];

  // Level 2: National / State Level (1.1 <= Zoom < 2.0)
  final List<Map<String, dynamic>> _stateNodes = [
    {'name': 'Maharashtra', 'region': 'India', 'aqi': 58, 'status': 'Moderate', 'color': AppColors.amber, 'x': 0.50, 'y': 0.52, 'pm25': 31.0},
    {'name': 'Delhi NCR', 'region': 'India', 'aqi': 245, 'status': 'Poor', 'color': AppColors.coral, 'x': 0.48, 'y': 0.32, 'pm25': 112.0},
    {'name': 'Karnataka', 'region': 'India', 'aqi': 45, 'status': 'Good', 'color': AppColors.emerald, 'x': 0.49, 'y': 0.66, 'pm25': 14.8},
    {'name': 'Gujarat', 'region': 'India', 'aqi': 92, 'status': 'Moderate', 'color': AppColors.amber, 'x': 0.38, 'y': 0.44, 'pm25': 42.0},
    {'name': 'Tamil Nadu', 'region': 'India', 'aqi': 48, 'status': 'Good', 'color': AppColors.emerald, 'x': 0.52, 'y': 0.74, 'pm25': 16.2},
    {'name': 'West Bengal', 'region': 'India', 'aqi': 128, 'status': 'Unhealthy', 'color': Colors.orange, 'x': 0.68, 'y': 0.42, 'pm25': 58.5},
    {'name': 'Telangana', 'region': 'India', 'aqi': 62, 'status': 'Moderate', 'color': AppColors.amber, 'x': 0.53, 'y': 0.58, 'pm25': 33.1},
  ];

  // Level 3: Hyperlocal City / Ward Level (Zoom >= 2.0)
  final List<Map<String, dynamic>> _cityStations = [
    {'name': 'Thane Majiwada (Live GPS)', 'region': 'Thane West', 'aqi': 54, 'status': 'Moderate', 'color': AppColors.amber, 'x': 0.52, 'y': 0.42, 'pm25': 28.4, 'pm10': 52.1, 'o3': 31.0},
    {'name': 'Mumbai BKC Financial Hub', 'region': 'Mumbai', 'aqi': 68, 'status': 'Moderate', 'color': AppColors.amber, 'x': 0.48, 'y': 0.56, 'pm25': 34.0, 'pm10': 66.0, 'o3': 38.0},
    {'name': 'Colaba Ocean Observatory', 'region': 'South Mumbai', 'aqi': 38, 'status': 'Good', 'color': AppColors.emerald, 'x': 0.44, 'y': 0.72, 'pm25': 12.0, 'pm10': 29.0, 'o3': 22.0},
    {'name': 'Andheri Industrial Substation', 'region': 'Western Suburbs', 'aqi': 82, 'status': 'Moderate', 'color': AppColors.amber, 'x': 0.42, 'y': 0.46, 'pm25': 41.5, 'pm10': 78.0, 'o3': 42.0},
    {'name': 'Navi Mumbai Vashi Hub', 'region': 'Navi Mumbai', 'aqi': 56, 'status': 'Moderate', 'color': AppColors.amber, 'x': 0.62, 'y': 0.58, 'pm25': 29.0, 'pm10': 54.0, 'o3': 30.0},
    {'name': 'Ghodbunder Highway Station', 'region': 'Thane North', 'aqi': 61, 'status': 'Moderate', 'color': AppColors.amber, 'x': 0.54, 'y': 0.32, 'pm25': 32.5, 'pm10': 59.0, 'o3': 34.0},
  ];

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_onScaleChanged);
    _selectedMarker = _cityStations.first;
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onScaleChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _onScaleChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    if ((scale - _currentScale).abs() > 0.05) {
      setState(() {
        _currentScale = scale;
      });
    }
  }

  void _zoomIn() {
    final matrix = _transformationController.value.clone();
    matrix.scale(1.3, 1.3);
    _transformationController.value = matrix;
  }

  void _zoomOut() {
    final matrix = _transformationController.value.clone();
    matrix.scale(0.77, 0.77);
    _transformationController.value = matrix;
  }

  void _resetToUserLocation() {
    _transformationController.value = Matrix4.identity()..scale(2.2);
    setState(() {
      _selectedMarker = _cityStations.first;
    });
  }

  String _getZoomLevelLabel() {
    if (_currentScale < 1.1) {
      return 'Global World View';
    } else if (_currentScale < 2.0) {
      return 'State Regional View';
    } else {
      return 'Hyperlocal Ward View';
    }
  }

  List<Map<String, dynamic>> _getActiveMarkers() {
    if (_currentScale < 1.1) {
      return _worldHubs;
    } else if (_currentScale < 2.0) {
      return _stateNodes;
    } else {
      return _cityStations;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkCanvas : AppColors.lightCanvas;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    final markers = _getActiveMarkers();

    return Scaffold(
      backgroundColor: bg,
      drawer: FeatureDirectoryDrawer(appState: widget.appState),
      appBar: GrevideaAppBar(
        title: 'Global AQI Map',
        subtitle: '${_getZoomLevelLabel()} • Pinch to Zoom',
        showBack: Navigator.of(context).canPop(),
        appState: widget.appState,
      ),
      body: Stack(
        children: [
          // Pinch & Pan Interactive Map Canvas
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.6,
              maxScale: 3.5,
              boundaryMargin: const EdgeInsets.all(300),
              child: Container(
                width: 900,
                height: 700,
                color: isDark ? const Color(0xFF0F1B15) : const Color(0xFFDCECE3),
                child: CustomPaint(
                  painter: _GlobalMapGridPainter(isDark: isDark, scale: _currentScale),
                  child: Stack(
                    children: markers.map((m) {
                      final x = (m['x'] as double) * 900;
                      final y = (m['y'] as double) * 700;
                      final aqi = m['aqi'] as int;
                      final color = m['color'] as Color;
                      final isSel = _selectedMarker?['name'] == m['name'];

                      return Positioned(
                        left: x - 24,
                        top: y - 24,
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedMarker = m);
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white, width: isSel ? 2.5 : 1.2),
                                  boxShadow: [
                                    BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: isSel ? 10 : 4),
                                  ],
                                ),
                                child: Text(
                                  '$aqi',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  m['name'] as String,
                                  style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),

          // Floating Top Level Indicator Pill
          Positioned(
            top: 14,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface.withValues(alpha: 0.92) : Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.emerald.withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.public_rounded, size: 14, color: AppColors.champagneGold),
                  const SizedBox(width: 6),
                  Text(
                    _getZoomLevelLabel(),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: textColor),
                  ),
                ],
              ),
            ),
          ),

          // Zoom Controls Floating Column
          Positioned(
            top: 14,
            right: 20,
            child: Column(
              children: [
                _buildMapControlBtn(Icons.add_rounded, _zoomIn, cardBg, textColor),
                const SizedBox(height: 8),
                _buildMapControlBtn(Icons.remove_rounded, _zoomOut, cardBg, textColor),
                const SizedBox(height: 8),
                _buildMapControlBtn(Icons.my_location_rounded, _resetToUserLocation, cardBg, AppColors.emerald),
              ],
            ),
          ),

          // Live Selected Station Card at Bottom
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: (_selectedMarker?['color'] as Color? ?? AppColors.emerald).withValues(alpha: 0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedMarker?['name'] ?? 'Local Station',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: textColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${_selectedMarker?['region'] ?? ""} • Live Station Telemetry',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: (_selectedMarker?['color'] as Color? ?? AppColors.emerald).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _selectedMarker?['color'] as Color? ?? AppColors.emerald),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'AQI ${_selectedMarker?['aqi'] ?? "--"}',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: _selectedMarker?['color'] as Color? ?? AppColors.emerald),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '(${_selectedMarker?['status'] ?? ""})',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _selectedMarker?['color'] as Color? ?? AppColors.emerald),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildPollutantPill('PM2.5', '${_selectedMarker?['pm25'] ?? 24} µg/m³', isDark),
                      _buildPollutantPill('PM10', '${_selectedMarker?['pm10'] ?? 48} µg/m³', isDark),
                      _buildPollutantPill('Ozone (O₃)', '${_selectedMarker?['o3'] ?? 28} µg/m³', isDark),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapControlBtn(IconData icon, VoidCallback onTap, Color bg, Color color) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4),
        ],
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: color, size: 20),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildPollutantPill(String label, String val, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 9.5, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(val, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _GlobalMapGridPainter extends CustomPainter {
  final bool isDark;
  final double scale;
  _GlobalMapGridPainter({required this.isDark, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)
      ..strokeWidth = 1.0;

    for (double x = 0; x < size.width; x += 60) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 60) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // World Map Landmass Outlines (Vector representation)
    final landPaint = Paint()
      ..color = isDark ? const Color(0xFF1B3024) : const Color(0xFFC7E2D2)
      ..style = PaintingStyle.fill;

    // Asia & India sub-continent
    final indiaPath = Path()
      ..moveTo(size.width * 0.60, size.height * 0.35)
      ..lineTo(size.width * 0.70, size.height * 0.36)
      ..lineTo(size.width * 0.68, size.height * 0.50)
      ..lineTo(size.width * 0.64, size.height * 0.58)
      ..lineTo(size.width * 0.62, size.height * 0.48)
      ..close();
    canvas.drawPath(indiaPath, landPaint);

    // Europe
    final eurPath = Path()
      ..moveTo(size.width * 0.44, size.height * 0.24)
      ..lineTo(size.width * 0.52, size.height * 0.22)
      ..lineTo(size.width * 0.50, size.height * 0.35)
      ..lineTo(size.width * 0.43, size.height * 0.32)
      ..close();
    canvas.drawPath(eurPath, landPaint);

    // Americas
    final americasPath = Path()
      ..moveTo(size.width * 0.22, size.height * 0.24)
      ..lineTo(size.width * 0.34, size.height * 0.25)
      ..lineTo(size.width * 0.30, size.height * 0.45)
      ..lineTo(size.width * 0.36, size.height * 0.72)
      ..lineTo(size.width * 0.26, size.height * 0.55)
      ..close();
    canvas.drawPath(americasPath, landPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
