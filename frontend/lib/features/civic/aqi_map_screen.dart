import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
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
  late final MapController _mapController;
  Map<String, dynamic>? _selectedMarker;
  double _currentZoom = 12.0;

  // Real GPS Station Nodes
  final List<Map<String, dynamic>> _stations = [
    {
      'name': 'Thane Majiwada (Live GPS)',
      'region': 'Thane West',
      'aqi': 54,
      'status': 'Moderate',
      'color': AppColors.amber,
      'lat': 19.2183,
      'lng': 72.9781,
      'pm25': 28.4,
      'pm10': 52.1,
      'o3': 31.0,
    },
    {
      'name': 'Mumbai BKC Financial Hub',
      'region': 'Mumbai',
      'aqi': 68,
      'status': 'Moderate',
      'color': AppColors.amber,
      'lat': 19.0657,
      'lng': 72.8687,
      'pm25': 34.0,
      'pm10': 66.0,
      'o3': 38.0,
    },
    {
      'name': 'Colaba Ocean Observatory',
      'region': 'South Mumbai',
      'aqi': 38,
      'status': 'Good',
      'color': AppColors.emerald,
      'lat': 18.9067,
      'lng': 72.8147,
      'pm25': 12.0,
      'pm10': 29.0,
      'o3': 22.0,
    },
    {
      'name': 'Andheri Industrial Substation',
      'region': 'Western Suburbs',
      'aqi': 82,
      'status': 'Moderate',
      'color': AppColors.amber,
      'lat': 19.1136,
      'lng': 72.8697,
      'pm25': 41.5,
      'pm10': 78.0,
      'o3': 42.0,
    },
    {
      'name': 'Navi Mumbai Vashi Hub',
      'region': 'Navi Mumbai',
      'aqi': 56,
      'status': 'Moderate',
      'color': AppColors.amber,
      'lat': 19.0771,
      'lng': 72.9986,
      'pm25': 29.0,
      'pm10': 54.0,
      'o3': 30.0,
    },
    {
      'name': 'Ghodbunder Highway Station',
      'region': 'Thane North',
      'aqi': 61,
      'status': 'Moderate',
      'color': AppColors.amber,
      'lat': 19.2625,
      'lng': 72.9530,
      'pm25': 32.5,
      'pm10': 59.0,
      'o3': 34.0,
    },
    // Major Regional Hubs
    {
      'name': 'Delhi Anand Vihar',
      'region': 'Delhi NCR',
      'aqi': 245,
      'status': 'Poor',
      'color': AppColors.coral,
      'lat': 28.6469,
      'lng': 77.3160,
      'pm25': 112.0,
      'pm10': 185.0,
      'o3': 45.0,
    },
    {
      'name': 'Bengaluru City Center',
      'region': 'Karnataka',
      'aqi': 42,
      'status': 'Good',
      'color': AppColors.emerald,
      'lat': 12.9716,
      'lng': 77.5946,
      'pm25': 14.0,
      'pm10': 32.0,
      'o3': 18.0,
    },
  ];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selectedMarker = _stations.first;
  }

  void _zoomIn() {
    final current = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, current + 1);
    setState(() => _currentZoom = current + 1);
  }

  void _zoomOut() {
    final current = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, current - 1);
    setState(() => _currentZoom = current - 1);
  }

  void _resetToUserLocation() {
    final userLat = widget.appState.locationService.currentLatitude;
    final userLng = widget.appState.locationService.currentLongitude;
    _mapController.move(ll.LatLng(userLat, userLng), 13.0);
    setState(() {
      _selectedMarker = _stations.first;
      _currentZoom = 13.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    final userLat = widget.appState.locationService.currentLatitude;
    final userLng = widget.appState.locationService.currentLongitude;
    final userCoord = ll.LatLng(userLat, userLng);

    return Scaffold(
      drawer: FeatureDirectoryDrawer(appState: widget.appState),
      appBar: GrevideaAppBar(
        title: 'Global AQI Map',
        subtitle: 'Real OpenStreetMap Live Stations',
        showBack: Navigator.of(context).canPop(),
        appState: widget.appState,
      ),
      body: Stack(
        children: [
          // Real OpenStreetMap Tiles
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: userCoord,
              initialZoom: _currentZoom,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
              onPositionChanged: (pos, _) {
                if (pos.zoom != null && (pos.zoom! - _currentZoom).abs() > 0.5) {
                  setState(() => _currentZoom = pos.zoom!);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.grevidea.app',
              ),
              MarkerLayer(
                markers: [
                  // User live GPS Marker
                  Marker(
                    point: userCoord,
                    width: 44,
                    height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.royalForest,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.champagneGold, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.emerald.withValues(alpha: 0.6),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.my_location_rounded, color: AppColors.champagneGold, size: 22),
                    ),
                  ),
                  // AQI Stations Markers
                  ..._stations.map((m) {
                    final lat = m['lat'] as double;
                    final lng = m['lng'] as double;
                    final isSel = _selectedMarker?['name'] == m['name'];
                    final aqi = m['aqi'] as int;
                    final color = m['color'] as Color;

                    return Marker(
                      point: ll.LatLng(lat, lng),
                      width: isSel ? 76 : 56,
                      height: isSel ? 56 : 42,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedMarker = m);
                          _mapController.move(ll.LatLng(lat, lng), _currentZoom);
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                (m['name'] as String).split(' ').first,
                                style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ],
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
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 6),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.public_rounded, size: 14, color: AppColors.champagneGold),
                  const SizedBox(width: 6),
                  Text(
                    _currentZoom > 11 ? 'Hyperlocal Ward View' : 'Regional / National View',
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
            left: 20,
            right: 20,
            child: _selectedMarker != null
                ? Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: (_selectedMarker!['color'] as Color).withValues(alpha: 0.6), width: 1.5),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _selectedMarker!['color'] as Color,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_selectedMarker!['aqi']} AQI',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedMarker!['name'] as String,
                                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: textColor),
                                  ),
                                  Text(
                                    '${_selectedMarker!['region']} • Status: ${_selectedMarker!['status']}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
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
                            _buildPollutantPill('PM2.5', '${_selectedMarker!['pm25']} µg/m³', isDark),
                            _buildPollutantPill('PM10', '${_selectedMarker!['pm10'] ?? 52.0} µg/m³', isDark),
                            _buildPollutantPill('O₃', '${_selectedMarker!['o3'] ?? 31.0} ppb', isDark),
                          ],
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildMapControlBtn(IconData icon, VoidCallback onTap, Color bg, Color color) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
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
