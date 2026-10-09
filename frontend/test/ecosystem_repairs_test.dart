import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grevidea/state/app_state.dart';
import 'package:grevidea/core/services/location_service.dart';
import 'package:grevidea/core/theme/app_colors.dart';
import 'package:grevidea/features/dashboard/dashboard_screen.dart';
import 'package:grevidea/features/profile/ecosystem_catalog_screen.dart';
import 'package:flutter/services.dart';

import 'dart:convert';

import 'package:grevidea/main.dart';
import 'package:grevidea/core/widgets/persistent_feature_tray.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'Feature routes keep the tray and preserve form text through dialogs',
    (tester) async {
      final state = AppState();
      state.signup(
        name: 'Audit',
        email: 'navigation@example.test',
        password: 'testpassword',
      );
      state.completeOnboarding();
      await tester.pumpWidget(GrevideaApp(appState: state));
      final context = tester.element(find.byType(DashboardScreen));
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: TextField(key: Key('featureInput'))),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(PersistentFeatureTray), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('featureInput')),
        'preserved destination',
      );
      final featureContext = tester.element(
        find.byKey(const Key('featureInput')),
      );
      showDialog(
        context: featureContext,
        builder: (ctx) => AlertDialog(
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close test dialog'),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Close test dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('preserved destination'), findsOneWidget);
      await tester.tap(find.text('Home').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(PersistentFeatureTray), findsNothing);
      expect(find.byType(DashboardScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    },
  );
  test('Baseline decimals and multi-modal breakdown survive serialization', () {
    final baseline = UserBaselineProfile(
      commuteDistances: {'Metro': 12.75, 'Walking': .35},
      dailyCommuteKm: 13.1,
    );
    final restored = UserBaselineProfile.fromJson(baseline.toJson());
    expect(restored.commuteDistances, {'Metro': 12.75, 'Walking': .35});
    expect(restored.dailyCommuteKm, 13.1);
  });
  test('Speed thresholds never infer a car or train without confirmation', () {
    expect(LocationService.inferMode(6.99), 'walk');
    expect(LocationService.inferMode(7), 'bicycle');
    expect(LocationService.inferMode(25), 'bicycle');
    expect(LocationService.inferMode(25.01), 'unknown_transit');
  });
  test('Onboarding and habit claim survive a fresh AppState', () async {
    final state = AppState();
    await state.initPersistence();
    state.signup(
      name: 'Audit',
      email: 'audit@example.test',
      password: 'testpassword',
    );
    state.completeOnboarding();
    expect(state.claimTask('green_plate'), isTrue);
    expect(state.claimTask('green_plate'), isFalse);
    final restored = AppState();
    await restored.initPersistence();
    expect(restored.hasCompletedOnboarding, isTrue);
    expect(restored.isTaskClaimed('green_plate'), isTrue);
    state.dispose();
    restored.dispose();
  });
  test('Negative reward cost cannot mint points', () {
    final state = AppState();
    expect(state.redeemReward(cost: -1, rewardName: 'Invalid'), isFalse);
    expect(state.greenPoints, 0);
    state.dispose();
  });
  test(
    'Core text contrast exceeds WCAG AA against light and dark card surfaces',
    () {
      double contrast(Color text, Color background) {
        final a = text.computeLuminance();
        final b = background.computeLuminance();
        return ((a > b ? a : b) + .05) / ((a > b ? b : a) + .05);
      }

      for (final colors in [
        [AppColors.lightTextPrimary, AppColors.lightSurface],
        [AppColors.lightTextSecondary, AppColors.lightSurfaceAlt],
        [AppColors.darkTextPrimary, AppColors.darkSurface],
        [AppColors.darkTextSecondary, AppColors.darkSurfaceAlt],
      ]) {
        expect(contrast(colors[0], colors[1]), greaterThan(4.5));
      }
    },
  );
  test('Exactly 58 distinct real tool entries are bundled', () async {
    final catalog = jsonDecode(
      await rootBundle.loadString('assets/feature_catalog.json'),
    ) as List;
    expect(catalog.length, 58);
    expect(catalog.map((f) => f['tool']).toSet().length, 58);
  });
  testWidgets(
    'Home hides analytics; score card opens Tracker and returns to Home',
    (tester) async {
      final state = AppState();
      await tester.pumpWidget(
        MaterialApp(home: DashboardScreen(appState: state)),
      );
      expect(find.text('Your Environmental Score'), findsOneWidget);
      expect(find.text('By Category'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Your Environmental Score'));
      await tester.pump();
      expect(find.text('Your Environmental Score'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Home').last);
      await tester.pump();
      expect(find.text('Your Environmental Score'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
  testWidgets('Full feature directory displays categorized navigation', (
    tester,
  ) async {
    await tester.runAsync(
      () => rootBundle.loadString('assets/feature_catalog.json'),
    );
    final state = AppState();
    await tester.pumpWidget(
      MaterialApp(home: EcosystemCatalogScreen(appState: state)),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(find.text('All 58 Features'), findsOneWidget);
    await tester.tap(find.text('Climate assistance'));
    await tester.pumpAndSettle();
    expect(find.text('Ask Climate Assistant'), findsOneWidget);
    await tester.tap(find.text('Ask Climate Assistant'));
    await tester.pumpAndSettle();
    expect(find.text('Message'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
}
