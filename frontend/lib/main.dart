import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/forest_backdrop.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'state/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Immersive edge-to-edge styling for modern Android & iOS
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final appState = AppState();
  await appState.initPersistence();
  runApp(GrevideaApp(appState: appState));
}

class GrevideaApp extends StatefulWidget {
  final AppState appState;

  const GrevideaApp({super.key, required this.appState});

  @override
  State<GrevideaApp> createState() => _GrevideaAppState();
}

class _GrevideaAppState extends State<GrevideaApp> {
  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        return MaterialApp(
          title: 'Grevidea',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: appState.themeMode,
          builder: (context, child) => ForestBackdrop(child: child ?? const SizedBox.shrink()),
          home: (appState.isAuthenticated && appState.hasCompletedOnboarding)
              ? DashboardScreen(appState: appState)
              : LoginScreen(appState: appState),
        );
      },
    );
  }
}
