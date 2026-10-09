import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grevidea/core/theme/app_theme.dart';
import 'package:grevidea/core/widgets/forest_backdrop.dart';
import 'package:grevidea/features/dashboard/dashboard_screen.dart';
import 'package:grevidea/state/app_state.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final dark in [false, true]) {
    testWidgets(
      'APK dashboard greeting, score, tasks and footer at 320px, dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final state = AppState();
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: ForestBackdrop(child: child!),
            ),
            home: DashboardScreen(appState: state),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Your Environmental Score'), findsOneWidget);
        expect(find.text("Today's Easy Tasks"), findsOneWidget);
        expect(
          find.textContaining('Here is your green summary'),
          findsOneWidget,
        );
        expect(find.byType(BottomAppBar), findsOneWidget);
        expect(find.byType(FloatingActionButton), findsOneWidget);
        for (final label in ['Home', 'Tracker', 'Community', 'Ranks']) {
          expect(find.text(label), findsOneWidget);
        }
        expect(find.text('Scan Product (EcoLens)'), findsNothing);
        await tester.tap(find.byTooltip('All 58 Features & Modules'));
        await tester.pumpAndSettle();
        expect(find.text('Grevidea Menu'), findsOneWidget);
        expect(find.text('Insights'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        state.dispose();
      },
    );
  }

  testWidgets(
    'Center footer opens all features and reduced-motion tree preserves score',
    (tester) async {
      final state = AppState();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: ForestBackdrop(child: child!),
          ),
          home: DashboardScreen(appState: state),
        ),
      );
      await tester.pumpAndSettle();
      final score = state.score;
      await tester.tap(
        find.bySemanticsLabel('Autumn tree. Tap to release leaves'),
      );
      await tester.pumpAndSettle();
      expect(state.score, score);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('Grevidea Menu'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
}
