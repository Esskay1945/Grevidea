import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class TravelTrip {
  final double distanceKm;
  final String mode;
  const TravelTrip(this.distanceKm, this.mode);
}

class LocationService extends ChangeNotifier {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();
  Position? _lastKnownPosition;
  Position? get lastKnownPosition => _lastKnownPosition;
  // Viewport fallback only, never a substitute for hardware GPS in submissions.
  static const double defaultLatitude = 19.2183;
  static const double defaultLongitude = 72.9781;
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
  bool get highSpeed => (_lastKnownPosition?.speed ?? 0) * 3.6 > 25;
  static String inferMode(double kmh) => kmh < 7
      ? 'walk'
      : kmh <= 25
          ? 'bicycle'
          : 'unknown_transit';

  /// Called only by the explicit onboarding handshake.
  Future<bool> requestOnboardingPermission() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      final allowed = permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
      if (allowed) await startSilentTracking();
      return allowed;
    } catch (_) {
      return false;
    }
  }

  Future<void> startSilentTracking() async {
    if (_subscription != null) return;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) return;
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
    } catch (_) {
      /* No permission popups on startup or from individual screens. */
    }
  }

  @visibleForTesting
  void ingest(Position position) {
    if (!position.accuracy.isFinite || position.accuracy > 50) return;
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
      if (seconds > 0 && speed <= 180 && speed > 1 && meters >= 15) {
        _distance += meters / 1000;
        if (speed > _peakSpeed) _peakSpeed = speed;
        _lastMovement = position.timestamp;
      }
    }
    finishIfIdle(position.timestamp);
    notifyListeners();
  }

  @visibleForTesting
  void finishIfIdle(DateTime now) {
    if (_lastMovement == null ||
        now.difference(_lastMovement!) < const Duration(minutes: 3)) return;
    if (_distance >= .05)
      _trips.add(TravelTrip(_distance, inferMode(_peakSpeed)));
    _distance = 0;
    _peakSpeed = 0;
    _lastMovement = null;
  }

  Future<void> stopTracking() async {
    await _subscription?.cancel();
    _subscription = null;
    _idleTimer?.cancel();
    _idleTimer = null;
    _distance = 0;
    _peakSpeed = 0;
    _lastMovement = null;
    _lastKnownPosition = null;
  }

  Future<Position?> getCurrentLocation({bool forceRefresh = false}) async {
    if (_lastKnownPosition != null && !forceRefresh) return _lastKnownPosition;
    _isLocating = true;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) return null;
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

  double distanceBetweenKm(
          double startLat, double startLng, double endLat, double endLng) =>
      Geolocator.distanceBetween(startLat, startLng, endLat, endLng) / 1000;
}
