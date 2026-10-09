import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../core/theme/app_colors.dart';
import '../../core/widgets/grevidea_app_bar.dart';
import '../../core/widgets/feature_directory_drawer.dart';
import '../../state/app_state.dart';
import '../../core/services/location_service.dart';

class GreenCommuteScreen extends StatefulWidget {
  final AppState appState;
  const GreenCommuteScreen({super.key, required this.appState});

  @override
  State<GreenCommuteScreen> createState() => _GreenCommuteScreenState();
}

class _GreenCommuteScreenState extends State<GreenCommuteScreen> {
  late TextEditingController _originController;
  late TextEditingController _destController;
  late final MapController _mapController;
  int _selectedModeIndex = 0;
  double _routeDistanceKm = 0;
  List<ll.LatLng> _routePoints = [];
  ll.LatLng? _destination;
  List<dynamic> _routeVariants = [];
  int? _cleanestRoute;
  int _shortestRoute = 0;
  bool _isSearching = false;
  String _airQualitySource = 'Air-quality source unavailable';

  final Map<String, ll.LatLng> _destinationCoords = {
    'BKC, Mumbai': const ll.LatLng(19.0657, 72.8687),
    'Andheri East': const ll.LatLng(19.1136, 72.8697),
    'Thane Station': const ll.LatLng(19.1860, 72.9757),
    'Vashi, Navi Mumbai': const ll.LatLng(19.0771, 72.9986),
    'Powai Hiranandani': const ll.LatLng(19.1176, 72.9060),
  };

  final List<String> _quickDestinations = [
    'BKC, Mumbai',
    'Andheri East',
    'Thane Station',
    'Vashi, Navi Mumbai',
    'Powai Hiranandani',
  ];

  ll.LatLng get _originCoord => ll.LatLng(
    widget.appState.locationService.currentLatitude,
    widget.appState.locationService.currentLongitude,
  );

  ll.LatLng get _destCoord => _destination ?? _originCoord;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _originController = TextEditingController(
      text: '${widget.appState.baseline.cityWard} (Live GPS)',
    );
    _destController = TextEditingController(text: 'BKC, Mumbai');
  }

  @override
  void dispose() {
    _originController.dispose();
    _destController.dispose();
    super.dispose();
  }

  void _swapRoute() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Origin follows your live GPS. Choose a new destination.',
        ),
      ),
    );
  }

  Future<void> _recalculateRoute(String dest, {ll.LatLng? tapped}) async {
    if (_isSearching) return;
    setState(() {
      _destController.text = dest;
      _isSearching = true;
      _routePoints = [];
      _routeDistanceKm = 0;
      _routeVariants = [];
      _cleanestRoute = null;
    });
    try {
      final position = await widget.appState.locationService.getCurrentLocation(
        forceRefresh: true,
      );
      if (position == null)
        throw StateError(
          'Enable location in device settings; no live origin available.',
        );
      var target = tapped;
      if (target == null) {
        final results = await widget.appState.api.request(
          '/api/v1/location/search?q=${Uri.encodeQueryComponent(dest)}',
        );
        if (results is! List || results.isEmpty)
          throw StateError('Destination search unavailable or no match found.');
        target = ll.LatLng(
          double.parse(results.first['lat']),
          double.parse(results.first['lon']),
        );
      }
      final result = await widget.appState.api.request(
        '/api/v1/location/route',
        data: {
          'origin_lat': position.latitude,
          'origin_lon': position.longitude,
          'destination_lat': target.latitude,
          'destination_lon': target.longitude,
        },
      );
      if (result == null || (result['routes'] as List).isEmpty)
        throw StateError('Road routing unavailable.');
      _routeVariants = result['routes'] as List;
      _airQualitySource =
          result['air_quality_status'] as String? ??
          'Air-quality source unavailable';
      _cleanestRoute = (result['cleanest_route_index'] as num?)?.toInt();
      _shortestRoute = List.generate(_routeVariants.length, (i) => i).reduce(
        (a, b) =>
            (_routeVariants[a]['distance'] as num) <=
                (_routeVariants[b]['distance'] as num)
            ? a
            : b,
      );
      final route = _routeVariants[_shortestRoute];
      final points = (route['geometry']['coordinates'] as List)
          .map(
            (p) =>
                ll.LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()),
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _destination = target;
        _routePoints = points;
        _routeDistanceKm = (route['distance'] as num).toDouble() / 1000;
      });
      _mapController.move(
        ll.LatLng(
          (position.latitude + target.latitude) / 2,
          (position.longitude + target.longitude) / 2,
        ),
        11.5,
      );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectRoute(bool cleaner) {
    if (_routeVariants.isEmpty) return;
    final index = cleaner ? _cleanestRoute : _shortestRoute;
    if (index == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Route air-quality estimates are unavailable.'),
        ),
      );
      return;
    }
    final route = _routeVariants[index];
    setState(() {
      _routeDistanceKm = (route['distance'] as num).toDouble() / 1000;
      _routePoints = (route['geometry']['coordinates'] as List)
          .map(
            (p) =>
                ll.LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()),
          )
          .toList();
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
        'fare_tag': 'Estimate using OSRM road distance; not a rail itinerary',
        'fare_type': 'Estimated',
        'icon': Icons.directions_subway_rounded,
        'color': AppColors.leafOf(context),
        'points': ((carCo2 - (d * 0.015)) * 25).round().clamp(10, 80),
        'isBest': true,
      },
      {
        'mode': 'Electric Bus (TMT/BEST EV)',
        'duration': '${(d * 2.8).round()} min',
        'co2_val': -(carCo2 - (d * 0.025)),
        'emitted': (d * 0.025).toStringAsFixed(2),
        'fare': '₹${(d * 1.0).round().clamp(10, 45)}',
        'fare_tag': 'Indicative bus fare estimate',
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
    if (_routePoints.isEmpty || _routeDistanceKm <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Find a real route first.")));
      return;
    }
    final modes = _computeModes();
    final mode = modes[_selectedModeIndex];
    final co2Val = mode['co2_val'] as double;
    final pts = mode['points'] as int;

    const apiModes = ['metro', 'bus', 'ev_car', 'car'];
    widget.appState.recordTrip(
      TravelTrip(_routeDistanceKm, apiModes[_selectedModeIndex]),
      apiModes[_selectedModeIndex],
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
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.inkOf(context);

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
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkCardBorder
                        : AppColors.lightCardBorder,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.my_location_rounded,
                          color: AppColors.leafOf(context),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _originController,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                            decoration:  InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 4),
                              border: InputBorder.none,
                              labelText: 'FROM (Live Origin)',
                              labelStyle: TextStyle(
                                fontSize: 10,
                                color: AppColors.mutedOf(context),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.swap_vert_rounded,
                            color: AppColors.accentOf(context),
                          ),
                          onPressed: _swapRoute,
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: AppColors.coral,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _destController,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                            onSubmitted: _recalculateRoute,
                            decoration:  InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 4),
                              border: InputBorder.none,
                              labelText: 'TO (Destination)',
                              labelStyle: TextStyle(
                                fontSize: 10,
                                color: AppColors.mutedOf(context),
                              ),
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

              // Real Interactive OpenStreetMap Corridor Map
              Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.leafOf(context).withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: ll.LatLng(
                            (_originCoord.latitude + _destCoord.latitude) / 2,
                            (_originCoord.longitude + _destCoord.longitude) / 2,
                          ),
                          initialZoom: 11.5,
                          onTap: (_, point) => _recalculateRoute(
                            "Selected map destination",
                            tapped: point,
                          ),
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.grevidea.app',
                          ),
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _routePoints,
                                strokeWidth: 4.5,
                                color: AppColors.leafOf(context),
                              ),
                            ],
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _originCoord,
                                width: 38,
                                height: 38,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.royalForest,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.champagneGold,
                                      width: 2.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.leafOf(context)
                                            .withValues(alpha: 0.5),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.my_location_rounded,
                                    color: AppColors.champagneGold,
                                    size: 18,
                                  ),
                                ),
                              ),
                              Marker(
                                point: _destCoord,
                                width: 38,
                                height: 38,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.coral,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.location_on_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Corridor distance chip
                      Positioned(
                        top: 12,
                        left: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.alt_route_rounded,
                                size: 14,
                                color: AppColors.accentOf(context),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_routeDistanceKm.toStringAsFixed(1)} km Corridor',
                                style: TextStyle(
                                  color: AppColors.inkOf(context),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Map Zoom / Recenter Controls
                      Positioned(
                        top: 12,
                        right: 14,
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: () {
                                final currentZoom = _mapController.camera.zoom;
                                _mapController.move(
                                  _mapController.camera.center,
                                  currentZoom + 1,
                                );
                              },
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.add,
                                  size: 18,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () {
                                final currentZoom = _mapController.camera.zoom;
                                _mapController.move(
                                  _mapController.camera.center,
                                  currentZoom - 1,
                                );
                              },
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.remove,
                                  size: 18,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () {
                                _mapController.move(_originCoord, 13.0);
                              },
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.royalForest,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.gps_fixed_rounded,
                                  size: 16,
                                  color: AppColors.champagneGold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Bottom Traffic & Geocoding Bar
                      Positioned(
                        bottom: 12,
                        left: 14,
                        right: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurface.withValues(alpha: 0.92)
                                : AppColors.lightSurface.withValues(
                                    alpha: 0.95,
                                  ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.leafOf(context)
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () => _selectRoute(false),
                                child: const Text(
                                  'Shortest road route',
                                  style: TextStyle(fontSize: 10),
                                ),
                              ),
                              TextButton(
                                onPressed: () => _selectRoute(true),
                                child: const Text(
                                  'Lower exposure estimate',
                                  style: TextStyle(fontSize: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_isSearching)
                        Container(
                          color: Colors.black.withValues(alpha: 0.35),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.champagneGold,
                              strokeWidth: 2.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(_airQualitySource, style: const TextStyle(fontSize: 11)),
              const SizedBox(height: 8),
              Text(
                'Compare estimated emissions',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
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
                        color: isSel
                            ? AppColors.accentOf(context)
                            : (isDark
                                  ? AppColors.darkCardBorder
                                  : AppColors.lightCardBorder),
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
                                color: (m['color'] as Color).withValues(
                                  alpha: 0.15,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                m['icon'] as IconData,
                                color: m['color'] as Color,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        m['mode'] as String,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: textColor,
                                        ),
                                      ),
                                      if (m['isBest'] == true) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.leafOf(context),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            'LOWEST CARBON',
                                            style: TextStyle(
                                              fontSize: 8,
                                              color: AppColors.inkOf(context),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
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
                                      color: isSaved
                                          ? AppColors.leafOf(context)
                                          : AppColors.coral,
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
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: m['fare_type'] == 'Estimated'
                                        ? AppColors.leafOf(context)
                                              .withValues(alpha: 0.2)
                                        : AppColors.mutedOf(context)
                                              .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    m['fare_type'] as String,
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                      color: m['fare_type'] == 'Estimated'
                                          ? AppColors.leafOf(context)
                                          : AppColors.mutedOf(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Source: ${m['fare_tag']}',
                          style:  TextStyle(
                            fontSize: 9,
                            color: AppColors.mutedOf(context),
                            fontStyle: FontStyle.italic,
                          ),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _logCommute,
                  child: const Text(
                    'Log This Commute in Ledger',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
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
