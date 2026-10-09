import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grevidea/core/theme/app_theme.dart';
import 'package:grevidea/core/widgets/autumn_tree.dart';
import 'package:grevidea/features/dashboard/dashboard_screen.dart';
import 'package:grevidea/state/app_state.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final dark in [false, true]) {
    testWidgets('Dashboard has only score and tasks at 320px, dark=$dark', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = AppState();
      await tester.pumpWidget(MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        home: DashboardScreen(appState: state),
      ));
      await tester.pump();
      expect(find.text('Environment score'), findsOneWidget);
      expect(find.text('Daily tasks'), findsOneWidget);
      expect(find.byType(BottomAppBar), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.text('Scan Product (EcoLens)'), findsNothing);
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Tracker'), findsOneWidget);
      expect(find.text('Community'), findsOneWidget);
      expect(find.text('Insights'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    });
  }

  testWidgets('Reduced motion keeps tappable tree static without errors', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MediaQuery(
      data: MediaQueryData(disableAnimations: true),
      child: SizedBox(height: 170, child: AutumnTree()),
    )));
    await tester.tap(find.byType(AutumnTree));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
