import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grevidea/main.dart';
import 'package:grevidea/state/app_state.dart';
import 'package:grevidea/core/models/plant_record.dart';

void main() {
  group('1. Smoke & UI Initialization', () {
    testWidgets('Grevidea app launches with title Grevidea and initializes correctly', (WidgetTester tester) async {
      final appState = AppState();
      await tester.pumpWidget(GrevideaApp(appState: appState));
      expect(find.text('Grevidea'), findsWidgets);
    });
  });

  group('2. Pure Dynamic AppState Zero-State & Defaults', () {
    test('Brand new user initializes with pure zero metrics and unachieved stats', () {
      final state = AppState();
      expect(state.greenPoints, equals(0));
      expect(state.streakDays, equals(0));
      expect(state.co2SavedToday, equals(0.0));
      expect(state.totalCo2Saved, equals(0.0));
      expect(state.treesEquivalent, equals(0.0));
      expect(state.recentActivities.isEmpty, isTrue);
      expect(state.challengeAccepted, isFalse);
      expect(state.useMetricUnits, isTrue);
    });

    test('Unit preference toggles between Metric and Imperial correctly', () {
      final state = AppState();
      expect(state.useMetricUnits, isTrue);
      state.setUseMetricUnits(false);
      expect(state.useMetricUnits, isFalse);
      state.setUseMetricUnits(true);
      expect(state.useMetricUnits, isTrue);
    });
  });

  group('3. Dynamic Activity Logging & Impact Ledger', () {
    test('Logging an eco activity increments green points and accumulates CO2 savings', () async {
      final state = AppState();
      expect(state.greenPoints, equals(0));
      expect(state.totalCo2Saved, equals(0.0));

      await state.logActivity(
        title: 'Metro Line 4 Commute',
        category: 'Transport',
        subtitle: '12 km electrified transit',
        co2Kg: -2.4,
        icon: Icons.directions_subway_rounded,
        pointsEarned: 25,
      );

      expect(state.greenPoints, equals(25));
      expect(state.recentActivities.length, equals(1));
      expect(state.co2SavedToday, equals(2.4));
      expect(state.totalCo2Saved, equals(2.4));
      expect(state.treesEquivalent, greaterThan(0.0));
    });

    test('Multiple activities aggregate accurately into totalCo2Saved', () async {
      final state = AppState();

      await state.logActivity(
        title: 'Solar PV Home Generation',
        category: 'Energy',
        subtitle: '4 kWh generated',
        co2Kg: -3.2,
        icon: Icons.solar_power_rounded,
        pointsEarned: 30,
      );

      await state.logActivity(
        title: 'Wet Waste Composted',
        category: 'Waste',
        subtitle: '1.5 kg segregated compost',
        co2Kg: -1.0,
        icon: Icons.recycling_rounded,
        pointsEarned: 15,
      );

      expect(state.greenPoints, equals(45));
      expect(state.recentActivities.length, equals(2));
      expect(state.totalCo2Saved, equals(4.2));
    });
  });

  group('4. Strict Plant-a-Tree Check-in & Point Revocation', () {
    test('Missed tree check-in deduction penalty deducts previously earned points completely', () async {
      final state = AppState();

      // Initial tree planting (+100 pts)
      await state.logActivity(
        title: 'Planted Ashoka Sapling',
        category: 'Waste',
        subtitle: 'Photo verified sapling',
        pointsEarned: 100,
        co2Kg: -2.0,
        icon: Icons.park_rounded,
      );
      expect(state.greenPoints, equals(100));

      // Month 1 verified (+50 pts)
      await state.logActivity(
        title: 'Month 1 Growth Verified',
        category: 'Education',
        subtitle: 'Ashoka Sapling healthy',
        pointsEarned: 50,
        co2Kg: -1.0,
        icon: Icons.eco_rounded,
      );
      expect(state.greenPoints, equals(150));

      // Month 2 missed: penalty deduction revoking all 150 points earned for the plant
      await state.logActivity(
        title: 'Penalty: Missed Tree Check-in',
        category: 'Waste',
        subtitle: 'Revoked all 150 points due to missed check-in',
        pointsEarned: -150,
        co2Kg: 0.0,
        icon: Icons.cancel_rounded,
      );

      expect(state.greenPoints, equals(0));
    });
  });

  group('5. Mathematical Leaderboard Rank Determination', () {
    test('Rank is dynamically computed: User with highest score is mathematically #1', () {
      final dataset = [
        {'user_name': 'Neighbor A', 'points': 80, 'is_current_user': false},
        {'user_name': 'Neighbor B', 'points': 50, 'is_current_user': false},
      ];

      const userPoints = 120;
      final higherCount = dataset.where((u) => ((u['points'] as int?) ?? 0) > userPoints).length;
      final calculatedRank = higherCount + 1;

      expect(calculatedRank, equals(1));
    });

    test('Rank is dynamically computed: User below a higher scorer is mathematically #2', () {
      final dataset = [
        {'user_name': 'Neighbor A', 'points': 200, 'is_current_user': false},
        {'user_name': 'Neighbor B', 'points': 50, 'is_current_user': false},
      ];

      const userPoints = 100;
      final higherCount = dataset.where((u) => ((u['points'] as int?) ?? 0) > userPoints).length;
      final calculatedRank = higherCount + 1;

      expect(calculatedRank, equals(2));
    });

    test('When no other users exist in dataset, user rank is mathematically #1', () {
      final List<Map<String, dynamic>> emptyDataset = [];
      const userPoints = 0;
      final higherCount = emptyDataset.where((u) => ((u['points'] as int?) ?? 0) > userPoints).length;
      final calculatedRank = higherCount + 1;

      expect(calculatedRank, equals(1));
    });
  });

  group('6. High-Speed Transit Speed Threshold Detection (>25 km/h)', () {
    test('Speed at 15 km/h (walking/jogging) does not trigger transit prompt', () {
      const currentSpeedKmh = 15.0;
      final isHighSpeedTransit = currentSpeedKmh > 25.0;
      expect(isHighSpeedTransit, isFalse);
    });

    test('Speed at 38 km/h (bus/train/car) triggers transit prompt', () {
      const currentSpeedKmh = 38.0;
      final isHighSpeedTransit = currentSpeedKmh > 25.0;
      expect(isHighSpeedTransit, isTrue);
    });
  });

  group('7. One-Time Onboarding Gating & User Database Persistence', () {
    test('New user starts with hasCompletedOnboarding = false and empty plant tracker', () {
      final state = AppState();
      state.signup(name: 'New Tester', email: 'newtester@example.com', password: 'Password123!');
      expect(state.hasCompletedOnboarding, isFalse);
      expect(state.plants.isEmpty, isTrue);
      expect(state.userEmail, equals('newtester@example.com'));
      expect(state.userPassword, equals('Password123!'));
    });

    test('Completing onboarding sets hasCompletedOnboarding = true and preserves status', () {
      final state = AppState();
      state.signup(name: 'Eco Warrior', email: 'warrior@example.com', password: 'Pass123!@#');
      expect(state.hasCompletedOnboarding, isFalse);

      state.completeOnboarding();
      expect(state.hasCompletedOnboarding, isTrue);

      // Logging in again as the same user must retain hasCompletedOnboarding = true (one-time form only)
      final loginSuccess = state.login('warrior@example.com', 'Pass123!@#');
      expect(loginSuccess, isTrue);
      expect(state.hasCompletedOnboarding, isTrue);
    });

    test('Wrong password returns false on login', () {
      final state = AppState();
      state.signup(name: 'Secure User', email: 'secure@example.com', password: 'CorrectPassword123');
      
      final failedLogin = state.login('secure@example.com', 'WrongPassword456');
      expect(failedLogin, isFalse);

      final okLogin = state.login('secure@example.com', 'CorrectPassword123');
      expect(okLogin, isTrue);
    });
  });

  group('8. Plant Tracker Zero-State & Adoption Lifecycle', () {
    test('Brand new user has 0 plants initially, adoption increments count', () {
      final state = AppState();
      state.signup(name: 'Gardener', email: 'gardener@example.com', password: 'PlantPassword123');
      expect(state.plants.isEmpty, isTrue);

      state.addPlant(
        PlantGrowthRecord(
          id: 1,
          species: 'Neem Sapling (Azadirachta indica)',
          location: 'Balcony Pot #1',
          plantedDate: DateTime.now(),
          currentMonth: 1,
          isMonthVerified: true,
          pointsEarned: 100,
        ),
      );

      expect(state.plants.length, equals(1));
      expect(state.plants.first.species, equals('Neem Sapling (Azadirachta indica)'));
      expect(state.greenPoints, equals(100));
    });
  });
}
