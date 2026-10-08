import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/forest_backdrop.dart';
import 'core/widgets/persistent_feature_tray.dart';
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
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final _RouteTrayObserver _observer;
  bool _featureOpen = false;
  @override
  void initState() {
    super.initState();
    _observer = _RouteTrayObserver((show) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _featureOpen != show)
          setState(() => _featureOpen = show);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        return MaterialApp(
          title: 'Grevidea',
          navigatorKey: _navigatorKey,
          navigatorObservers: [_observer],
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: appState.themeMode,
          builder: (context, child) => ForestBackdrop(
            child: _featureOpen &&
                    appState.isAuthenticated &&
                    appState.hasCompletedOnboarding
                ? PersistentFeatureTray(
                    appState: appState,
                    navigatorKey: _navigatorKey,
                    child: child ?? const SizedBox.shrink())
                : child ?? const SizedBox.shrink(),
          ),
          home: (appState.isAuthenticated && appState.hasCompletedOnboarding)
              ? DashboardScreen(appState: appState)
              : LoginScreen(appState: appState),
        );
      },
    );
  }
}

class _RouteTrayObserver extends NavigatorObserver {
  final void Function(bool) onChange;
  final List<Route<dynamic>> _pages = [];
  _RouteTrayObserver(this.onChange);
  void _update() =>
      onChange(_pages.length > 1 && _pages.last.settings.name != '/dashboard');
  @override
  void didPush(Route route, Route? previous) {
    if (route is PageRoute) {
      _pages.add(route);
      _update();
    }
  }

  @override
  void didPop(Route route, Route? previous) {
    _pages.remove(route);
    _update();
  }

  @override
  void didRemove(Route route, Route? previous) {
    _pages.remove(route);
    _update();
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    final index = oldRoute == null ? -1 : _pages.indexOf(oldRoute);
    if (index >= 0) _pages.removeAt(index);
    if (newRoute is PageRoute)
      _pages.insert(index < 0 ? _pages.length : index, newRoute);
    _update();
  }
}
