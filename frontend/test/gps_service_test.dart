import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:grevidea/core/services/location_service.dart';
class DeviceGps extends GeolocatorPlatform {
  bool enabled = true;
  bool requested = false;
  LocationSettings? settings;
  LocationPermission permission = LocationPermission.denied;
  double accuracy = 8;
  @override Future<bool> isLocationServiceEnabled() async => enabled;
  @override Future<LocationPermission> checkPermission() async => permission;
  @override Future<LocationPermission> requestPermission() async { requested = true; return LocationPermission.whileInUse; }
  @override Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    settings = locationSettings;
    return Position(latitude: 18.52, longitude: 73.85, timestamp: DateTime.now(), accuracy: accuracy,
      altitude: 0, altitudeAccuracy: 0, heading: 0, headingAccuracy: 0, speed: 0, speedAccuracy: 0);
  }
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final original = GeolocatorPlatform.instance;
  tearDown(() => GeolocatorPlatform.instance = original);
  test('Permission is followed by actual high accuracy device acquisition', () async {
    final gps = DeviceGps();
    GeolocatorPlatform.instance = gps;
    final service = LocationService();
    final fix = await service.getCurrentLocation(forceRefresh: true);
    expect(gps.requested, isTrue);
    expect(gps.settings!.accuracy, LocationAccuracy.high);
    expect(fix!.latitude, 18.52);
    expect(fix.longitude, 73.85);
  });
  test('Disabled GPS and imprecise fixes are failures, never a default city', () async {
    final gps = DeviceGps()..enabled = false;
    GeolocatorPlatform.instance = gps;
    final service = LocationService();
    expect(await service.getCurrentLocation(forceRefresh: true), isNull);
    expect(service.error, contains('Turn on'));
    gps.enabled = true;
    gps.accuracy = 1000;
    expect(await service.getCurrentLocation(forceRefresh: true), isNull);
    expect(service.error, contains('imprecise'));
  });
}
