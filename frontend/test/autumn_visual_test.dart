import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grevidea/core/theme/app_theme.dart';
import 'package:grevidea/core/widgets/forest_backdrop.dart';
import 'package:grevidea/features/auth/login_screen.dart';
import 'package:grevidea/features/dashboard/dashboard_screen.dart';
import 'package:grevidea/features/tracker/tracker_screen.dart';
import 'package:grevidea/features/climategpt/climategpt_screen.dart';
import 'package:grevidea/state/app_state.dart';

/// CI produces actual Flutter-rendered previews, rather than more mockups.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final dark in [false, true]) {
    for (final page in ['dashboard', 'menu', 'tracker', 'assistant', 'login']) {
      testWidgets('Autumn preview $page, dark=$dark', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final state = AppState();
        final boundaryKey = GlobalKey();
        final widget = switch (page) {
          'tracker' => TrackerScreen(appState: state),
          'assistant' => ClimateGptScreen(appState: state),
          'login' => LoginScreen(appState: state),
          _ => DashboardScreen(appState: state),
        };
        final loader = FontLoader('Lora')
          ..addFont(rootBundle.load('assets/fonts/Lora.ttf'));
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        final cupertino = FontLoader('CupertinoIcons')
          ..addFont(rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'));
        await tester.runAsync(() async {
          await loader.load();
          await icons.load();
          await cupertino.load();
          final emojiFile = File('/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf');
          if (emojiFile.existsSync()) {
            final emoji = FontLoader('NotoColorEmoji')
              ..addFont(Future.value(ByteData.sublistView(emojiFile.readAsBytesSync())));
            await emoji.load();
          }
        });
        final oldShadows = debugDisableShadows;
        debugDisableShadows = false;
        addTearDown(() => debugDisableShadows = oldShadows);
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: RepaintBoundary(
                key: boundaryKey,
                child: ForestBackdrop(child: child!),
              ),
            ),
            home: widget,
          ),
        );
        final ctx = tester.element(find.byType(ForestBackdrop));
        await tester.runAsync(
          () => precacheImage(
            AssetImage(
              dark
                  ? 'assets/autumn/autumn_night.webp'
                  : 'assets/autumn/autumn_day.webp',
            ),
            ctx,
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        if (page == 'menu') {
          await tester.tap(find.byTooltip('All 58 Features & Modules'));
          await tester.pump(const Duration(milliseconds: 500));
        }
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final output = Directory('build/autumn-previews')
            ..createSync(recursive: true);
          File('${output.path}/$page-${dark ? 'dark' : 'light'}.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.pumpWidget(const SizedBox.shrink());
        state.dispose();
        debugDisableShadows = oldShadows;
      });
    }
  }
}
