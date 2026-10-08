import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grevidea/core/theme/app_theme.dart';
import 'package:grevidea/core/widgets/forest_backdrop.dart';

void main() {
  testWidgets(
    'Forest theme preserves control geometry, taps and route navigation',
    (tester) async {
      var dark = false;
      var taps = 0;
      late StateSetter update;
      const buttonKey = ValueKey('existing-control');
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MaterialApp(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: ForestBackdrop(child: child!),
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      key: buttonKey,
                      onPressed: () {
                        taps++;
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const Scaffold(
                              body: Center(child: Text('Existing route')),
                            ),
                          ),
                        );
                      },
                      child: const Text('Existing action'),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      final dayRect = tester.getRect(find.byKey(buttonKey));
      expect(find.byType(ForestBackdrop), findsOneWidget);
      update(() => dark = true);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(buttonKey)), dayRect);
      final images = tester.widgetList<Image>(find.byType(Image));
      expect(
        (images.single.image as AssetImage).assetName,
        contains('forest_night'),
      );
      await tester.tap(find.byKey(buttonKey));
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(find.text('Existing route'), findsOneWidget);
      Navigator.of(tester.element(find.text('Existing route'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Existing action'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Atmosphere pauses in background and resumes on foreground', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        builder: (_, child) => ForestBackdrop(child: child!),
        home: const Scaffold(body: Text('Content')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.binding.hasScheduledFrame, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
