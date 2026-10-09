import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grevidea/core/network/api_service.dart';
import 'package:grevidea/core/services/location_service.dart';
import 'package:grevidea/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('Activity identifiers and timestamps survive local persistence', () {
    final item = ActivityLogItem(
        clientId: 'trip-test',
        title: 'Walk',
        category: 'Transport',
        subtitle: 'Measured trip',
        co2Kg: -.192,
        icon: Icons.directions_walk,
        timestamp: DateTime.utc(2026, 10, 9));
    final restored =
        ActivityLogItem.fromJson(jsonDecode(jsonEncode(item.toJson())));
    expect(restored.clientId, item.clientId);
    expect(restored.timestamp, item.timestamp);
    expect(restored.co2Kg, -.192);
  });
  test('Permanent rejection is distinguishable from an offline retry', () {
    for (final status in [400, 403, 404, 409, 422]) {
      expect(ApiResult(status, null).permanentFailure, isTrue);
    }
    for (final status in [0, 401, 429, 500, 503]) {
      expect(ApiResult(status, null).permanentFailure, isFalse);
    }
  });
  test('Trip journal retains unacknowledged trips across account restart',
      () async {
    final location = LocationService();
    await location.bindAccount(null);
    await location.bindAccount('capture@example.test');
    final captured = <TravelTrip>[];
    final subscription = location.completedTrips.listen(captured.add);
    final start = DateTime.now();
    Position point(double lat, int seconds) => Position(
        latitude: lat,
        longitude: 72.9,
        timestamp: start.add(Duration(seconds: seconds)),
        accuracy: 10,
        altitude: 0,
        heading: 0,
        speed: 1.5,
        speedAccuracy: 1,
        altitudeAccuracy: 1,
        headingAccuracy: 1);
    location.ingest(point(19.2, 0));
    location.ingest(point(19.201, 90));
    await location.finishIfIdle(start.add(const Duration(minutes: 5)));
    await Future<void>.delayed(Duration.zero);
    expect(captured, hasLength(1));
    final trip = captured.single;
    expect(trip.mode, 'walk');
    expect(trip.distanceKm, greaterThan(.1));
    expect(trip.finishedAt, start.add(const Duration(seconds: 90)));
    await location.bindAccount(null);
    await location.bindAccount('capture@example.test');
    await Future<void>.delayed(Duration.zero);
    expect(captured, hasLength(2));
    expect(captured.last.id, trip.id);
    await location.acknowledgeTrip(trip.id!);
    await location.bindAccount(null);
    await location.bindAccount('capture@example.test');
    await Future<void>.delayed(Duration.zero);
    expect(captured, hasLength(2));
    await subscription.cancel();
    await location.bindAccount(null);
  });
}
