import 'package:flutter/material.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../../core/theme/app_colors.dart';
import '../../core/widgets/grevidea_app_bar.dart';
import '../../core/widgets/feature_directory_drawer.dart';
import '../../state/app_state.dart';

class DisasterAlertsScreen extends StatefulWidget {
  final AppState appState;
  const DisasterAlertsScreen({super.key, required this.appState});

  @override
  State<DisasterAlertsScreen> createState() => _DisasterAlertsScreenState();
}

class _DisasterAlertsScreenState extends State<DisasterAlertsScreen> {
  bool _isLoadingFeed = false;

  final List<Map<String, dynamic>> _authoritativeShelters = [];
  final List<Map<String, dynamic>> _liveAlerts = [];
  @override
  void initState() {
    super.initState();
    _refreshFeed();
  }

  Future<void> _refreshFeed() async {
    if (_isLoadingFeed) return;
    setState(() => _isLoadingFeed = true);
    final position = await widget.appState.locationService
        .getCurrentLocation(forceRefresh: true);
    final data = position == null
        ? null
        : await widget.appState.api.request(
            '/api/v1/weather?lat=${position.latitude}&lon=${position.longitude}');
    final shelters = position == null
        ? null
        : await widget.appState.api.request(
            '/api/v1/shelters?lat=${position.latitude}&lon=${position.longitude}&radius_km=5');
    if (!mounted) return;
    _authoritativeShelters.clear();
    if (shelters is List)
      _authoritativeShelters.addAll(List<Map<String, dynamic>>.from(shelters));
    _liveAlerts.clear();
    if (data == null) {
      _liveAlerts.add({
        'title': 'Weather unavailable',
        'source': 'No verified telemetry',
        'timestamp': '',
        'severity': 'Unavailable',
        'icon': Icons.cloud_off,
        'color': AppColors.amber,
        'description':
            'Enable location in settings and check your connection. No hazard status can be determined.'
      });
    } else {
      final current = data['weather']['current'];
      final aqi = data['air_quality']?['current']?['us_aqi'];
      final temperatures =
          (data['weather']['hourly']?['temperature_2m'] as List?) ?? [];
      final heat = temperatures.length >= 48 &&
          temperatures.take(48).every((t) => t is num && t > 42);
      _liveAlerts.add({
        'title':
            heat ? '48-hour extreme heat forecast' : 'Local weather forecast',
        'source': data['source'],
        'timestamp': current['time'].toString(),
        'severity': heat ? 'Critical' : 'Advisory',
        'icon': Icons.thermostat,
        'color': heat ? AppColors.coral : AppColors.emerald,
        'description':
            'Temperature: ${current['temperature_2m']} °C · precipitation: ${current['precipitation']} mm. Forecast model, not an official emergency warning.'
      });
      _liveAlerts.add({
        'title': aqi is num && aqi > 350
            ? 'Hazardous air forecast'
            : 'Air quality forecast',
        'source': 'Open-Meteo / CAMS · US AQI',
        'timestamp': data['air_quality']?['current']?['time']?.toString() ?? '',
        'severity': 'Advisory',
        'icon': Icons.air,
        'color': aqi is num && aqi > 350 ? AppColors.coral : AppColors.amber,
        'description': aqi == null
            ? 'Air quality is unavailable.'
            : 'US AQI: $aqi. This is model data, not a CPCB station measurement.'
      });
    }
    setState(() => _isLoadingFeed = false);
  }

  Future<void> _sendSos() async {
    final position = await widget.appState.locationService
        .getCurrentLocation(forceRefresh: true);
    final address = position == null
        ? null
        : await widget.appState.api.request(
            '/api/v1/location/address?lat=${position.latitude}&lon=${position.longitude}');
    int? battery;
    try {
      battery = await Battery().batteryLevel;
    } catch (_) {}
    final result = position == null
        ? null
        : await widget.appState.api.request('/api/v1/sos', data: {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'disaster_type': 'emergency',
            'description': 'User requested assistance',
            'needs': ['rescue'],
            'people_count': 1,
            'battery_percent': battery,
            'street_address': address?['display_name']
          });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result == null
            ? 'SOS not saved. Live GPS, sign-in and a connection are required.'
            : 'SOS stored in Grevidea. Emergency services and trusted contacts have not been notified.')));
  }

  void _triggerSos(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning_rounded, color: AppColors.coral, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text('Emergency SOS Beacon',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Save a request for nearby Grevidea helpers. This does not contact emergency services or trusted contacts:',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.coral.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.coral.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '📍 Live GPS: ${widget.appState.locationService.currentLatitude.toStringAsFixed(4)}° N, ${widget.appState.locationService.currentLongitude.toStringAsFixed(4)}° E',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(
                      'Ward: ${widget.appState.baseline.cityWard} (Device Sensor Live)',
                      style: const TextStyle(fontSize: 11)),
                  const SizedBox(height: 2),
                  const Text('Emergency Helpline: 1077 (TMC Disaster Cell)',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: AppColors.coral)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _sendSos();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral),
            child: const Text('Save SOS Request',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildRealShelterMap({double height = 180, bool isDark = false}) {
    final userLat = widget.appState.locationService.currentLatitude;
    final userLng = widget.appState.locationService.currentLongitude;
    final userCoord = ll.LatLng(userLat, userLng);

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: AppColors.coral.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: userCoord,
                initialZoom: 13.0,
                interactionOptions:
                    const InteractionOptions(flags: InteractiveFlag.all),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.grevidea.app',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [
                        userCoord,
                        const ll.LatLng(19.2150, 72.9750),
                        const ll.LatLng(19.2183, 72.9781),
                      ],
                      strokeWidth: 4.0,
                      color: AppColors.coral,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    // User live GPS marker
                    Marker(
                      point: userCoord,
                      width: 38,
                      height: 38,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.royalForest,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.champagneGold, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                                color: AppColors.emerald.withValues(alpha: 0.6),
                                blurRadius: 8,
                                spreadRadius: 2),
                          ],
                        ),
                        child: const Icon(Icons.my_location_rounded,
                            color: AppColors.champagneGold, size: 18),
                      ),
                    ),
                    // Municipal Shelter Markers
                    ..._authoritativeShelters.map((s) {
                      final lat = s['lat'] as double;
                      final lng = s['lng'] as double;
                      return Marker(
                        point: ll.LatLng(lat, lng),
                        width: 40,
                        height: 40,
                        child: Tooltip(
                          message: '${s['name']} (${s['distance']})',
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.coral,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const [
                                BoxShadow(color: Colors.black38, blurRadius: 6)
                              ],
                            ),
                            child: const Icon(Icons.home_work_rounded,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ],
            ),
            // Top Chip
            Positioned(
              top: 10,
              left: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.shield_rounded,
                        size: 14, color: AppColors.champagneGold),
                    SizedBox(width: 6),
                    Text('Verified municipal shelter feed unavailable',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            // Bottom tag
            Positioned(
              bottom: 8,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('OpenStreetMap Live Tiles',
                    style: TextStyle(color: Colors.white70, fontSize: 9)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSheltersMapModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurface
          : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Safe Shelters & Evacuation Map',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(
                          'Authoritative TMC Civil Defense Registry (${widget.appState.baseline.cityWard})',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.lightTextSecondary)),
                    ],
                  ),
                  const Icon(Icons.shield_rounded,
                      color: AppColors.emerald, size: 24),
                ],
              ),
              const SizedBox(height: 14),

              // Real Shelter Map
              _buildRealShelterMap(height: 200, isDark: isDark),
              const SizedBox(height: 14),

              // Shelters List
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _authoritativeShelters.length,
                  separatorBuilder: (_, __) => const Divider(height: 12),
                  itemBuilder: (context, idx) {
                    final s = _authoritativeShelters[idx];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor:
                            AppColors.royalForest.withValues(alpha: 0.15),
                        child: const Icon(Icons.home_work_rounded,
                            color: AppColors.emerald, size: 20),
                      ),
                      title: Text(s['name'] as String,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12.5)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${s['location']} • ${s['distance']}',
                              style: const TextStyle(
                                  fontSize: 10.5,
                                  color: AppColors.lightTextSecondary)),
                          Text(
                              'Cap: ${s['capacity']} • Helpline: ${s['helpline']}',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.champagneGold,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.royalForest,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          minimumSize: const Size(60, 32),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.royalForest,
                              content: Text(
                                  'Navigating to ${s['name']} (${s['distance']}). Helpline: ${s['helpline']}',
                                  style: const TextStyle(
                                      color: AppColors.champagneGold)),
                            ),
                          );
                        },
                        child: const Text('Navigate',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.champagneGold)),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkCanvas : AppColors.lightCanvas;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Scaffold(
      backgroundColor: bg,
      drawer: FeatureDirectoryDrawer(appState: widget.appState),
      appBar: GrevideaAppBar(
        title: 'Disaster Alerts',
        subtitle: 'Live TMC & Early Warning System',
        showBack: Navigator.of(context).canPop(),
        appState: widget.appState,
        extraActions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.champagneGold),
            tooltip: 'Refresh Live Hazards',
            onPressed: _refreshFeed,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: () => _triggerSos(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.coral,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.sos_rounded, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Broadcast Emergency SOS Beacon',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Live risk summary for ${widget.appState.baseline.cityWard}',
            style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary),
          ),
          const SizedBox(height: 12),

          // High Alert Banner with Clickable Shelter Map Action
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A1515) : const Color(0xFFFFF0F0),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.coral.withValues(alpha: 0.6), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded,
                        color: AppColors.coral, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'High Flood Risk Warning',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.coral),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${widget.appState.baseline.cityWard} (Creek inlet zones)',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor),
                ),
                const SizedBox(height: 8),
                Text(
                  'Heavy rainfall predicted in next 24 hours. High tide may cause temporary water-logging near Majiwada bridge. 3 TMC safe shelters are on standby.',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary),
                ),
                const SizedBox(height: 14),

                // Interactive Safe Shelters Button
                InkWell(
                  onTap: _openSheltersMapModal,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.coral.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.coral.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'View Safe Shelters & Evacuation Map',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.coral),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded,
                            size: 14, color: AppColors.coral),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Live Evacuation High-Ground Shelters Map
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Live Evacuation & Shelter Grid',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: textColor),
              ),
              Text(
                _authoritativeShelters.isEmpty
                    ? 'Shelter feed unavailable'
                    : '${_authoritativeShelters.length} active verified shelters',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.emerald,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildRealShelterMap(height: 190, isDark: isDark),
          const SizedBox(height: 20),

          // Active Alerts Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Live Hazards & Advisories',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: textColor),
              ),
              if (_isLoadingFeed)
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.champagneGold)),
            ],
          ),
          const SizedBox(height: 12),

          // Live Alerts List
          ..._liveAlerts.map((alert) {
            return _buildAlertTile(
              alert['title'] as String,
              alert['source'] as String,
              alert['timestamp'] as String,
              alert['description'] as String,
              alert['icon'] as IconData,
              alert['color'] as Color,
              cardBg,
              textColor,
              isDark,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAlertTile(
    String title,
    String source,
    String timestamp,
    String desc,
    IconData icon,
    Color color,
    Color cardBg,
    Color textColor,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color:
                isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: textColor)),
                    const SizedBox(height: 2),
                    Text('$source • $timestamp',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.lightTextSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(desc,
              style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary)),
        ],
      ),
    );
  }
}
