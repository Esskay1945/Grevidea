import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _lastKnownPosition;
  Position? get lastKnownPosition => _lastKnownPosition;

  // Fallback coordinates (Majiwada, Thane West) if device location is unavailable
  static const double defaultLatitude = 19.2183;
  static const double defaultLongitude = 72.9781;

  double get currentLatitude => _lastKnownPosition?.latitude ?? defaultLatitude;
  double get currentLongitude => _lastKnownPosition?.longitude ?? defaultLongitude;

  bool _isLocating = false;
  bool get isLocating => _isLocating;

  /// Acquire live GPS position from device hardware
  Future<Position?> getCurrentLocation({bool forceRefresh = false}) async {
    if (_lastKnownPosition != null && !forceRefresh) {
      return _lastKnownPosition;
    }

    _isLocating = true;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled on device.');
        return _lastKnownPosition;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied.');
          return _lastKnownPosition;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied.');
        return _lastKnownPosition;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 6),
      );

      _lastKnownPosition = position;
      return position;
    } catch (e) {
      debugPrint('Error getting location: $e');
      return _lastKnownPosition;
    } finally {
      _isLocating = false;
    }
  }

  /// Calculates distance in kilometers between two GPS coordinates
  double distanceBetweenKm(double startLat, double startLng, double endLat, double endLng) {
    final distanceInMeters = Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
    return distanceInMeters / 1000.0;
  }
}
