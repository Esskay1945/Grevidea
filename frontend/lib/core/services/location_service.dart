import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TravelTrip {
  final double distanceKm;
  final String mode;
  final String? id;
  final DateTime? finishedAt;
  final double peakSpeedKmh;
  final List<Map<String, dynamic>> points;
  const TravelTrip(this.distanceKm, this.mode,
      {this.id,
      this.finishedAt,
      this.peakSpeedKmh = 0,
      this.points = const []});
  Map<String, dynamic> toJson() => {
        'distance': distanceKm,
        'mode': mode,
        'id': id,
        'finishedAt': finishedAt?.toUtc().toIso8601String(),
        'peak': peakSpeedKmh,
        'points': points
      };
  factory TravelTrip.fromJson(Map<String, dynamic> v) =>
      TravelTrip((v['distance'] as num).toDouble(), v['mode'] as String,
          id: v['id'] as String?,
          finishedAt: DateTime.tryParse(v['finishedAt']?.toString() ?? ''),
          peakSpeedKmh: (v['peak'] as num?)?.toDouble() ?? 0,
          points: List<Map<String, dynamic>>.from(v['points'] ?? []));
}

class LocationService extends ChangeNotifier {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();
  Position? _lastKnownPosition;
  Position? get lastKnownPosition => _lastKnownPosition;
  static const double defaultLatitude = 19.2183, defaultLongitude = 72.9781;
  double get currentLatitude => _lastKnownPosition?.latitude ?? defaultLatitude;
  double get currentLongitude =>
      _lastKnownPosition?.longitude ?? defaultLongitude;
  bool _isLocating = false;
  bool get isLocating => _isLocating;
  StreamSubscription<Position>? _subscription;
  Timer? _idleTimer;
  final _trips = StreamController<TravelTrip>.broadcast();
  Stream<TravelTrip> get completedTrips => _trips.stream;
  double _distance = 0, _peakSpeed = 0;
  DateTime? _lastMovement;
  String? _tripId, _account;
  SharedPreferences? _prefs;
  final _points = <Map<String, dynamic>>[];
  bool _finalizing = false;
  Position? _deferredPosition;
  Future<void>? _finishing;
  int _bindingGeneration = 0;
  bool get highSpeed => (_lastKnownPosition?.speed ?? 0) * 3.6 > 25;
  static String inferMode(double kmh) => kmh < 7
      ? 'walk'
      : kmh <= 25
          ? 'bicycle'
          : 'unknown_transit';
  String get _stateKey => 'tracking_state_$_account';
  String get _journalKey => 'tracking_journal_$_account';
  Future<void> bindAccount(String? account) async {
    if (_account == account) return;
    final generation = ++_bindingGeneration;
    await stopTracking();
    if (_finalizing) await _finishing;
    if (generation != _bindingGeneration) return;
    _deferredPosition = null;
    _account = account;
    _distance = 0;
    _peakSpeed = 0;
    _tripId = null;
    _lastMovement = null;
    _lastKnownPosition = null;
    _points.clear();
    if (account == null) return;
    _prefs = await SharedPreferences.getInstance();
    if (_account != account) return;
    try {
      final raw = _prefs!.getString(_stateKey);
      if (raw != null) {
        final s = jsonDecode(raw);
        _distance = (s['distance'] as num).toDouble();
        _peakSpeed = (s['peak'] as num).toDouble();
        _tripId = s['id'];
        _lastMovement = DateTime.tryParse(s['movement'] ?? '');
        _points.addAll(List<Map<String, dynamic>>.from(s['points'] ?? []));
      }
      for (final raw in _prefs!.getStringList(_journalKey) ?? []) {
        _trips.add(
            TravelTrip.fromJson(Map<String, dynamic>.from(jsonDecode(raw))));
      }
      await finishIfIdle(DateTime.now());
    } catch (_) {
      /* Invalid local capture is discarded, never treated as a measured trip. */ _distance =
          0;
      _peakSpeed = 0;
      _lastMovement = null;
      _tripId = null;
      _points.clear();
    }
  }

  Future<void> acknowledgeTrip(String id) async {
    final entries = _prefs?.getStringList(_journalKey) ?? [];
    entries.removeWhere((e) => jsonDecode(e)['id'] == id);
    await _prefs?.setStringList(_journalKey, entries);
  }

  Future<void> _saveCapture() async {
    if (_account == null || _prefs == null) return;
    await _prefs!.setString(
        _stateKey,
        jsonEncode({
          'distance': _distance,
          'peak': _peakSpeed,
          'id': _tripId,
          'movement': _lastMovement?.toIso8601String(),
          'points': _points
        }));
  }

  Future<bool> requestOnboardingPermission() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied)
        p = await Geolocator.requestPermission();
      final allowed =
          p == LocationPermission.whileInUse || p == LocationPermission.always;
      if (allowed) await startSilentTracking();
      return allowed;
    } catch (_) {
      return false;
    }
  }

  Future<void> startSilentTracking() async {
    if (_subscription != null || _account == null) return;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final p = await Geolocator.checkPermission();
      if (p != LocationPermission.whileInUse && p != LocationPermission.always)
        return;
      _subscription = Geolocator.getPositionStream(
              locationSettings: !kIsWeb &&
                      defaultTargetPlatform == TargetPlatform.android
                  ? AndroidSettings(
                      accuracy: LocationAccuracy.medium,
                      distanceFilter: 50,
                      intervalDuration: const Duration(seconds: 30),
                      foregroundNotificationConfig:
                          const ForegroundNotificationConfig(
                              notificationTitle: 'Grevidea travel tracking',
                              notificationText:
                                  'Measuring travel distance for your carbon ledger',
                              enableWakeLock: false))
                  : const LocationSettings(
                      accuracy: LocationAccuracy.medium, distanceFilter: 50))
          .listen(ingest, onError: (_) {
        stopTracking();
      });
      _idleTimer = Timer.periodic(
          const Duration(seconds: 30), (_) => finishIfIdle(DateTime.now()));
    } catch (_) {/* Startup never requests permission. */}
  }

  @visibleForTesting
  void ingest(Position position) {
    if (_finalizing) {
      _deferredPosition = position;
      return;
    }
    if (!position.accuracy.isFinite ||
        position.accuracy > 50 ||
        !position.latitude.isFinite ||
        !position.longitude.isFinite ||
        position.latitude.abs() > 90 ||
        position.longitude.abs() > 180) return;
    final previous = _lastKnownPosition;
    _lastKnownPosition = position;
    if (previous != null) {
      final seconds =
          position.timestamp.difference(previous.timestamp).inMilliseconds /
              1000;
      final meters = Geolocator.distanceBetween(previous.latitude,
          previous.longitude, position.latitude, position.longitude);
      final speed = position.speed >= 0
          ? position.speed * 3.6
          : seconds > 0
              ? meters / seconds * 3.6
              : 0.0;
      if (seconds > 0 &&
          seconds <= 300 &&
          speed <= 180 &&
          speed > 1 &&
          meters >= 15) {
        _tripId ??=
            'trip-${position.timestamp.microsecondsSinceEpoch}-${Random().nextInt(1 << 30)}';
        if (_points.isEmpty)
          _points.add({
            'latitude': previous.latitude,
            'longitude': previous.longitude,
            'accuracy': previous.accuracy
          });
        _distance += meters / 1000;
        _peakSpeed = max(_peakSpeed, speed);
        _lastMovement = position.timestamp;
        _points.add({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy
        });
        if (_points.length > 256) {
          final kept = List.generate(128, (i) => _points[i * 2]);
          _points
            ..clear()
            ..addAll(kept);
        }
        _saveCapture();
      }
    }
    finishIfIdle(position.timestamp);
    notifyListeners();
  }

  @visibleForTesting
  Future<void> finishIfIdle(DateTime now) {
    if (_finalizing) return _finishing ?? Future.value();
    return _finishing = _finishIfIdle(now);
  }

  Future<void> _finishIfIdle(DateTime now) async {
    if (_finalizing ||
        _lastMovement == null ||
        now.difference(_lastMovement!) < const Duration(minutes: 3)) return;
    _finalizing = true;
    try {
      if (_distance >= .05) {
        final trip = TravelTrip(_distance, inferMode(_peakSpeed),
            id: _tripId,
            finishedAt: _lastMovement,
            peakSpeedKmh: _peakSpeed,
            points: List.of(_points));
        if (_prefs != null && _account != null) {
          final journal = _prefs!.getStringList(_journalKey) ?? [];
          if (!journal.any((e) => jsonDecode(e)['id'] == trip.id)) {
            journal.add(jsonEncode(trip.toJson()));
            await _prefs!.setStringList(_journalKey, journal);
          }
        }
        _trips.add(trip);
      }
      _distance = 0;
      _peakSpeed = 0;
      _lastMovement = null;
      _tripId = null;
      _points.clear();
      await _saveCapture();
    } finally {
      _finalizing = false;
      final deferred = _deferredPosition;
      _deferredPosition = null;
      if (deferred != null) ingest(deferred);
    }
  }

  Future<void> stopTracking() async {
    await _subscription?.cancel();
    _subscription = null;
    _idleTimer?.cancel();
    _idleTimer = null;
    await _saveCapture();
  }

  Future<Position?> getCurrentLocation({bool forceRefresh = false}) async {
    if (_lastKnownPosition != null &&
        !forceRefresh &&
        DateTime.now().difference(_lastKnownPosition!.timestamp) <
            const Duration(minutes: 2)) return _lastKnownPosition;
    _isLocating = true;
    try {
      final p = await Geolocator.checkPermission();
      if (p != LocationPermission.whileInUse && p != LocationPermission.always)
        return null;
      _lastKnownPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 8)));
      notifyListeners();
      return _lastKnownPosition;
    } catch (_) {
      return null;
    } finally {
      _isLocating = false;
    }
  }

  double distanceBetweenKm(double a, double b, double c, double d) =>
      Geolocator.distanceBetween(a, b, c, d) / 1000;
}
