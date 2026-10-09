import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../state/app_state.dart';
import '../../core/widgets/grevidea_app_bar.dart';
import '../../core/theme/app_colors.dart';

/// Database-backed nearby rides and crisis resources; polling is foreground only.
class NearbyBoardScreen extends StatefulWidget {
  final AppState appState;
  final bool carpools;
  const NearbyBoardScreen({
    super.key,
    required this.appState,
    this.carpools = false,
  });
  @override
  State<NearbyBoardScreen> createState() => _NearbyBoardScreenState();
}

class _NearbyBoardScreenState extends State<NearbyBoardScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _items = [];
  List<LatLng> _corridor = [];
  String? _error;
  String? _pickupDistance;
  bool _busy = false;
  Timer? _poll;
  Timer? _reconnect;
  WebSocketChannel? _channel;
  StreamSubscription? _liveSubscription;
  bool _foreground = true;
  bool _liveConnected = false;
  final List<LatLng> _walkingPath = [];
  int _rideGeneration = 0;
  Future<void> _connectLive() async {
    if (!_foreground || _channel != null) return;
    final position = await widget.appState.locationService.getCurrentLocation();
    if (!mounted || !_foreground || position == null) return;
    final channel = widget.appState.api.openLiveChannel();
    if (channel == null) return;
    _channel = channel;
    void disconnected() {
      if (!mounted || !_foreground) return;
      _channel = null;
      _liveConnected = false;
      _poll ??= Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
      _reconnect?.cancel();
      _reconnect = Timer(const Duration(seconds: 5), _connectLive);
    }

    try {
      await channel.ready;
      if (!mounted || !_foreground) {
        channel.sink.close();
        return;
      }
      _liveSubscription = channel.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message as String);
            if (data['type'] == 'snapshot' && mounted) {
              setState(() {
                _items = List<Map<String, dynamic>>.from(
                  data[widget.carpools ? 'carpools' : 'mutual_aid'],
                );
                _error = null;
                _liveConnected = true;
              });
              _poll?.cancel();
              _poll = null;
            }
          } catch (_) {}
        },
        onError: (_) => disconnected(),
        onDone: disconnected,
      );
      channel.sink.add(
        jsonEncode({
          'lat': position.latitude,
          'lon': position.longitude,
          'radius_km': 5,
        }),
      );
    } catch (_) {
      channel.sink.close();
      disconnected();
    }
  }

  void _stopLive() {
    _reconnect?.cancel();
    _reconnect = null;
    _liveSubscription?.cancel();
    _liveSubscription = null;
    _channel?.sink.close();
    _channel = null;
    _liveConnected = false;
  }

  String get _path => widget.carpools ? 'carpool/nearby' : 'mutual-aid';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  void _start() {
    _refresh();
    _connectLive();
    _poll ??= Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      _start();
    } else {
      _foreground = false;
      _stopLive();
      _poll?.cancel();
      _poll = null;
    }
  }

  @override
  void dispose() {
    _foreground = false;
    _stopLive();
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_busy) return;
    _busy = true;
    final position = await widget.appState.locationService.getCurrentLocation();
    final result = position == null
        ? null
        : await widget.appState.api.request(
            '/api/v1/$_path?lat=${position.latitude}&lon=${position.longitude}&radius_km=5',
          );
    if (mounted)
      setState(() {
        _error = result is List
            ? null
            : 'Live GPS, sign-in and gateway connection are required.';
        if (result is List) _items = List<Map<String, dynamic>>.from(result);
      });
    _busy = false;
  }

  Future<void> _act(Map<String, dynamic> item) async {
    final path = widget.carpools
        ? 'carpool/${item['id']}/book'
        : 'mutual-aid/${item['id']}/coordinate';
    final result = await widget.appState.api.request('/api/v1/$path', data: {});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == null
              ? 'Request not accepted: it may be yours, already booked, full or coordinated.'
              : widget.carpools
              ? 'Ride booked. Available seats: ${result['seats_available']}'
              : 'Request coordinated.',
        ),
      ),
    );
    await _refresh();
  }

  Future<void> _publish() async {
    final description = TextEditingController();
    final destination = TextEditingController();
    var category = 'water';
    var seats = 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, change) => AlertDialog(
          title: Text(
            widget.carpools ? 'Offer a ride' : 'Post a resource or request',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!widget.carpools)
                DropdownButton<String>(
                  value: category,
                  items: ['water', 'power', 'shelter', 'medical', 'food']
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: (v) => change(() => category = v!),
                ),
              TextField(
                controller: description,
                decoration: InputDecoration(
                  labelText: widget.carpools
                      ? 'Pickup description'
                      : 'What do you need or offer?',
                ),
              ),
              if (widget.carpools) ...[
                TextField(
                  controller: destination,
                  decoration: const InputDecoration(
                    labelText: 'Destination address',
                  ),
                ),
                DropdownButton<int>(
                  value: seats,
                  items: List.generate(
                    8,
                    (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text('${i + 1} seats'),
                    ),
                  ),
                  onChanged: (v) => change(() => seats = v!),
                ),
                const Text(
                  'Departure is 30 minutes from now; points price is zero.',
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Publish'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) {
      description.dispose();
      destination.dispose();
      return;
    }
    final text = description.text.trim();
    final dest = destination.text.trim();
    description.dispose();
    destination.dispose();
    final position = await widget.appState.locationService.getCurrentLocation(
      forceRefresh: true,
    );
    dynamic result;
    if (position != null && text.isNotEmpty) {
      if (widget.carpools && dest.isNotEmpty) {
        final locations = await widget.appState.api.request(
          '/api/v1/location/search?q=${Uri.encodeQueryComponent(dest)}',
        );
        if (locations is List && locations.isNotEmpty) {
          final target = locations.first;
          final route = await widget.appState.api.request(
            '/api/v1/location/route',
            data: {
              'origin_lat': position.latitude,
              'origin_lon': position.longitude,
              'destination_lat': double.parse(target['lat']),
              'destination_lon': double.parse(target['lon']),
            },
          );
          if (route != null && (route['routes'] as List).isNotEmpty)
            result = await widget.appState.api.request(
              '/api/v1/carpool',
              data: {
                'origin': text,
                'destination': dest,
                'departure_at': DateTime.now()
                    .toUtc()
                    .add(const Duration(minutes: 30))
                    .toIso8601String(),
                'seats_available': seats,
                'price_points': 0,
                'pickup_lat': position.latitude,
                'pickup_lon': position.longitude,
                'route_geometry': route['routes'][0]['geometry'],
              },
            );
        }
      } else if (!widget.carpools) {
        result = await widget.appState.api.request(
          '/api/v1/mutual-aid',
          data: {
            'category': category,
            'description': text,
            'latitude': position.latitude,
            'longitude': position.longitude,
          },
        );
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == null
              ? 'Not published. Check location, connection and required fields.'
              : 'Published to nearby Grevidea users.',
        ),
      ),
    );
    await _refresh();
  }

  Future<void> _showRide(Map<String, dynamic> item) async {
    final generation = ++_rideGeneration;
    final coords = item['route_geometry']?['coordinates'];
    final location = widget.appState.locationService;
    final distance = location.lastKnownPosition == null
        ? null
        : location.distanceBetweenKm(
            location.currentLatitude,
            location.currentLongitude,
            (item['pickup_lat'] as num).toDouble(),
            (item['pickup_lon'] as num).toDouble(),
          );
    setState(() {
      _corridor = coords is List
          ? coords
                .map(
                  (p) => LatLng(
                    (p[1] as num).toDouble(),
                    (p[0] as num).toDouble(),
                  ),
                )
                .toList()
          : [];
      _pickupDistance = distance == null
          ? null
          : 'Pickup ${distance.toStringAsFixed(2)} km away in a straight line; finding a walking route';
      _walkingPath.clear();
    });
    final position = location.lastKnownPosition;
    if (position == null) return;
    final route = await widget.appState.api.request(
      '/api/v1/location/route',
      data: {
        'profile': 'foot',
        'origin_lat': position.latitude,
        'origin_lon': position.longitude,
        'destination_lat': item['pickup_lat'],
        'destination_lon': item['pickup_lon'],
      },
    );
    if (!mounted || generation != _rideGeneration) return;
    final routes = route?['routes'];
    if (routes is! List || routes.isEmpty) {
      setState(
        () => _pickupDistance =
            'Walking route unavailable. Straight-line distance: ${distance?.toStringAsFixed(2)} km.',
      );
      return;
    }
    if (routes is List &&
        routes.isNotEmpty &&
        routes.first['distance'] is num) {
      final first = routes.first;
      setState(() {
        _pickupDistance =
            'Walking route: ${((first['distance'] as num) / 1000).toStringAsFixed(2)} km to pickup';
        _walkingPath
          ..clear()
          ..addAll(
            (first['geometry']['coordinates'] as List).map(
              (p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()),
            ),
          );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = widget.appState.locationService;
    final origin = LatLng(location.currentLatitude, location.currentLongitude);
    return Scaffold(
      appBar: GrevideaAppBar(
        title: widget.carpools ? 'Nearby Carpooling' : 'Community Mutual Aid',
        subtitle: _liveConnected
            ? 'Within 5 km · live updates'
            : 'Within 5 km · reconnecting / periodic refresh',
        showBack: true,
        appState: widget.appState,
      ),
      body: Column(
        children: [
          SizedBox(
            height: 240,
            child: FlutterMap(
              options: MapOptions(initialCenter: origin, initialZoom: 13),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.grevidea.app',
                ),
                PolylineLayer(
                  polylines: [
                    if (_walkingPath.isNotEmpty)
                      Polyline(
                        points: _walkingPath,
                        color: AppColors.accentOf(context),
                        strokeWidth: 4,
                      ),
                    if (_corridor.isNotEmpty)
                      Polyline(
                        points: _corridor,
                        color: AppColors.leafOf(context),
                        strokeWidth: 4,
                      ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    if (location.lastKnownPosition != null)
                      Marker(
                        point: origin,
                        child: const Icon(
                          Icons.my_location,
                          color: AppColors.sapphire,
                        ),
                      ),
                    for (final item in _items)
                      Marker(
                        point: LatLng(
                          (item[widget.carpools ? 'pickup_lat' : 'latitude']
                                  as num)
                              .toDouble(),
                          (item[widget.carpools ? 'pickup_lon' : 'longitude']
                                  as num)
                              .toDouble(),
                        ),
                        child: GestureDetector(
                          onTap: () =>
                              widget.carpools ? _showRide(item) : _act(item),
                          child: Icon(
                            widget.carpools
                                ? Icons.directions_car
                                : Icons.volunteer_activism,
                            color: item['status'] == 'coordinated'
                                ? AppColors.mutedOf(context)
                                : AppColors.leafOf(context),
                          ),
                        ),
                      ),
                  ],
                ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('© OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),
          if (_pickupDistance != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(_pickupDistance!),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
              FilledButton.icon(
                onPressed: _publish,
                icon: const Icon(Icons.add),
                label: Text(widget.carpools ? 'Offer ride' : 'Post resource'),
              ),
            ],
          ),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
          if (_items.isEmpty && _error == null)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No nearby listings yet.'),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (ctx, i) {
                final item = _items[i];
                return ListTile(
                  onTap: widget.carpools ? () => _showRide(item) : null,
                  title: Text(
                    widget.carpools
                        ? '${item['origin']} → ${item['destination']}'
                        : '${item['category']}: ${item['description']}',
                  ),
                  subtitle: Text(
                    widget.carpools
                        ? '${item['seats_available']} seats · ${item['departure_at']}'
                        : item['status'],
                  ),
                  trailing: TextButton(
                    onPressed: item['status'] == 'coordinated'
                        ? null
                        : () => _act(item),
                    child: Text(widget.carpools ? 'Book' : 'Coordinate'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
