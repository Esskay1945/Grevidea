import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/models/plant_record.dart';
import '../core/network/api_service.dart';
import '../core/services/location_service.dart';

class UserBaselineProfile {
  Map<String, double> commuteDistances;
  String cityWard;
  String primaryCommute;
  double dailyCommuteKm;
  String dietaryPreference;
  double monthlyElectricityKwh;
  String dwellingType;
  bool hasRooftopSolar;
  String primaryGoal;

  UserBaselineProfile({
    Map<String, double>? commuteDistances,
    this.cityWard = 'Thane West, Maharashtra',
    this.primaryCommute = 'Metro',
    this.dailyCommuteKm = 18.5,
    this.dietaryPreference = 'Vegetarian',
    this.monthlyElectricityKwh = 160.0,
    this.dwellingType = 'Apartment',
    this.hasRooftopSolar = false,
    this.primaryGoal = 'Reduce Carbon & Earn Rewards',
  }) : commuteDistances = commuteDistances ?? {};

  Map<String, dynamic> toJson() => {
        'commuteDistances': commuteDistances,
        'cityWard': cityWard,
        'primaryCommute': primaryCommute,
        'dailyCommuteKm': dailyCommuteKm,
        'dietaryPreference': dietaryPreference,
        'monthlyElectricityKwh': monthlyElectricityKwh,
        'dwellingType': dwellingType,
        'hasRooftopSolar': hasRooftopSolar,
        'primaryGoal': primaryGoal,
      };

  factory UserBaselineProfile.fromJson(Map<String, dynamic> json) =>
      UserBaselineProfile(
        commuteDistances: (json['commuteDistances'] as Map?)
            ?.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
        cityWard: json['cityWard'] as String? ?? 'Thane West, Maharashtra',
        primaryCommute: json['primaryCommute'] as String? ?? 'Metro',
        dailyCommuteKm: (json['dailyCommuteKm'] as num?)?.toDouble() ?? 18.5,
        dietaryPreference: json['dietaryPreference'] as String? ?? 'Vegetarian',
        monthlyElectricityKwh:
            (json['monthlyElectricityKwh'] as num?)?.toDouble() ?? 160.0,
        dwellingType: json['dwellingType'] as String? ?? 'Apartment',
        hasRooftopSolar: json['hasRooftopSolar'] as bool? ?? false,
        primaryGoal:
            json['primaryGoal'] as String? ?? 'Reduce Carbon & Earn Rewards',
      );
}

class ActivityLogItem {
  final String? clientId;
  final String title;
  final String category;
  final String subtitle;
  final double co2Kg;
  final IconData icon;
  final DateTime timestamp;

  ActivityLogItem({
    this.clientId,
    required this.title,
    required this.category,
    required this.subtitle,
    required this.co2Kg,
    required this.icon,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'clientId': clientId,
        'title': title,
        'category': category,
        'subtitle': subtitle,
        'co2Kg': co2Kg,
        'iconCode': icon.codePoint,
        'timestamp': timestamp.toIso8601String(),
      };

  static IconData _categoryToIcon(String category) {
    switch (category.toLowerCase()) {
      case 'transport':
        return Icons.directions_transit_rounded;
      case 'energy':
        return Icons.bolt_rounded;
      case 'food':
        return Icons.restaurant_rounded;
      case 'waste':
        return Icons.recycling_rounded;
      default:
        return Icons.eco_rounded;
    }
  }

  factory ActivityLogItem.fromJson(Map<String, dynamic> json) =>
      ActivityLogItem(
        clientId: json['clientId'] as String?,
        title: json['title'] as String? ?? 'Activity',
        category: json['category'] as String? ?? 'General',
        subtitle: json['subtitle'] as String? ?? '',
        co2Kg: (json['co2Kg'] as num?)?.toDouble() ?? 0.0,
        icon: _categoryToIcon(json['category'] as String? ?? 'General'),
        timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
            DateTime.now(),
      );
}

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  final ApiService _api = ApiService();
  ApiService get api => _api;

  final LocationService _locationService = LocationService();
  LocationService get locationService => _locationService;

  int _mainTab = 0;
  int get mainTab => _mainTab;
  void setMainTab(int index) {
    if (index >= 0 && index < 4) {
      _mainTab = index;
      notifyListeners();
    }
  }

  SharedPreferences? _prefs;
  Timer? _syncTimer;
  bool _syncing = false;
  String get _outboxKey => 'grevidea_outbox_$_userEmail';
  Future<void> _enqueue(String path, Map<String, dynamic> data) async {
    final owner = _userEmail;
    final key = _outboxKey;
    _prefs ??= await SharedPreferences.getInstance();
    final entries = _prefs!.getStringList(key) ?? [];
    entries.add(jsonEncode({'path': path, 'data': data}));
    await _prefs!.setStringList(key, entries);
    if (owner == _userEmail) unawaited(syncPendingLedger());
  }

  List<String> get failedSyncEntries =>
      _prefs?.getStringList('failed_$_outboxKey') ?? [];
  Future<void> syncPendingLedger() async {
    if (_syncing ||
        !_isAuthenticated ||
        _prefs == null ||
        _api.authenticatedEmail != _userEmail.toLowerCase()) return;
    _syncing = true;
    final owner = _userEmail;
    final key = _outboxKey;
    try {
      while (_userEmail == owner) {
        final entries = _prefs!.getStringList(key) ?? [];
        if (entries.isEmpty) break;
        final entry = jsonDecode(entries.first) as Map<String, dynamic>;
        final response = await _api.requestDetailed(entry['path'] as String,
            data: Map<String, dynamic>.from(entry['data']));
        if (_userEmail != owner ||
            _api.authenticatedEmail != owner.toLowerCase()) break;
        if (response.data == null && !response.permanentFailure) break;
        if (response.permanentFailure) {
          final failed = _prefs!.getStringList('failed_$key') ?? [];
          failed.add(jsonEncode({...entry, 'status': response.status}));
          await _prefs!.setStringList('failed_$key', failed);
        }
        final latest = _prefs!.getStringList(key) ?? [];
        if (latest.isNotEmpty && latest.first == entries.first) {
          latest.removeAt(0);
          await _prefs!.setStringList(key, latest);
        }
      }
      if (_userEmail == owner) {
        await refreshSharedHistory();
        final balance = await _api.request('/api/v1/points');
        if (balance?['total_points'] is num &&
            (_prefs!.getStringList(key) ?? []).isEmpty)
          setVerifiedPoints((balance['total_points'] as num).toInt());
      }
    } finally {
      _syncing = false;
    }
  }

  bool _refreshingHistory = false;
  Future<void> refreshSharedHistory() async {
    if (_refreshingHistory ||
        !_isAuthenticated ||
        _api.authenticatedEmail != _userEmail.toLowerCase()) return;
    _refreshingHistory = true;
    final owner = _userEmail;
    try {
      final history = await _api.request('/api/v1/activities?days=366');
      if (owner != _userEmail || history?['activities'] is! List) return;
      final merged = <String, ActivityLogItem>{};
      for (final a in _recentActivities) {
        if (a.clientId != null) merged[a.clientId!] = a;
      }
      for (final value in history['activities']) {
        final row = Map<String, dynamic>.from(value);
        final id = row['client_id'] as String;
        merged[id] = ActivityLogItem(
            clientId: id,
            title: row['title'] as String,
            category: row['category'] as String,
            subtitle: row['subtitle'] as String? ?? '',
            co2Kg: (row['co2_delta_kg'] as num).toDouble(),
            icon: ActivityLogItem._categoryToIcon(row['category'] as String),
            timestamp: DateTime.parse(row['occurred_at'] as String).toLocal());
      }
      final legacy =
          _recentActivities.where((a) => a.clientId == null).toList();
      _recentActivities
        ..clear()
        ..addAll([...merged.values, ...legacy]
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp)));
      final remoteBaseline = await _api.request('/api/v1/baseline');
      final pendingBaseline = (_prefs?.getStringList(_outboxKey) ?? [])
          .any((e) => jsonDecode(e)['path'] == '/api/v1/baseline');
      if (owner == _userEmail &&
          !pendingBaseline &&
          remoteBaseline?['profile'] is Map) {
        _baseline = UserBaselineProfile.fromJson(
            Map<String, dynamic>.from(remoteBaseline['profile']));
        _hasCompletedOnboarding = remoteBaseline['completed'] == true;
      }
      if (owner == _userEmail) {
        recalculateMetrics();
        _saveCurrentUserToDb();
        notifyListeners();
      }
    } finally {
      _refreshingHistory = false;
    }
  }

  AppState() {
    recalculateMetrics();
    WidgetsBinding.instance.addObserver(this);
    _initBackend();
    _locationService.addListener(_locationChanged);
    _tripSubscription = _locationService.completedTrips.listen((trip) async {
      final owner = _userEmail;
      if (!_isAuthenticated) return;
      if (trip.mode == 'unknown_transit' &&
          _selectedTransitMode == null &&
          trip.points.length >= 3) {
        final inference = await _api.request('/api/v1/transit/infer',
            data: {'points': trip.points, 'peak_speed_kmh': trip.peakSpeedKmh});
        if (owner != _userEmail || !_isAuthenticated) return;
        if (inference?['confidence'] is num &&
            inference['confidence'] >= 0.9 &&
            ['metro', 'train'].contains(inference['mode'])) {
          await recordTrip(trip, inference['mode']);
          return;
        }
      }
      if (trip.mode == 'unknown_transit') {
        if (_selectedTransitMode != null) {
          recordTrip(trip, _selectedTransitMode!);
          _selectedTransitMode = null;
          return;
        }
        if (!_pendingTrips.any((t) => t.id == trip.id)) _pendingTrips.add(trip);
        notifyListeners();
        return;
      }
      recordTrip(trip, trip.mode);
    });
  }

  StreamSubscription<TravelTrip>? _tripSubscription;
  final List<TravelTrip> _pendingTrips = [];
  TravelTrip? get _pendingTrip =>
      _pendingTrips.isEmpty ? null : _pendingTrips.first;
  String? _selectedTransitMode;
  void selectTransitMode(String mode) {
    if (_pendingTrip != null) {
      recordTrip(_pendingTrip!, mode);
    } else {
      _selectedTransitMode = mode;
    }
  }

  TravelTrip? get pendingTrip => _pendingTrip;
  void _locationChanged() => notifyListeners();
  Future<void> recordTrip(TravelTrip trip, String mode) async {
    final tripOwner = _userEmail;
    final tripId = trip.id ?? 'trip-${DateTime.now().microsecondsSinceEpoch}';
    final calculation =
        await _api.calculateCarbon(mode: mode, distanceKm: trip.distanceKm);
    if (tripOwner != _userEmail || !_isAuthenticated) return;
    final emitted = (calculation['co2_kg'] as num?)?.toDouble() ?? 0;
    final saved =
        (trip.distanceKm * .192 - emitted).clamp(0.0, double.infinity);
    await logActivity(
        clientId: tripId,
        timestamp: trip.finishedAt,
        syncToServer: false,
        title: '$mode trip',
        category: 'Transport',
        subtitle:
            '${trip.distanceKm.toStringAsFixed(2)} km · emitted ${emitted.toStringAsFixed(2)} kg · saved ${saved.toStringAsFixed(2)} kg',
        co2Kg: emitted - trip.distanceKm * .192,
        icon: Icons.directions_transit,
        pointsEarned: (calculation['green_points_earned'] as num?)?.toInt() ??
            (saved * 100).toInt());
    await _enqueue('/api/v1/carbon/log', {
      'mode': mode,
      'distance_km': trip.distanceKm,
      'client_id': tripId,
      'occurred_at':
          (trip.finishedAt ?? DateTime.now()).toUtc().toIso8601String()
    });
    if (trip.id != null) await _locationService.acknowledgeTrip(trip.id!);
    _pendingTrips.removeWhere((t) => t.id == trip.id);
    notifyListeners();
  }

  @override
  void dispose() {
    _themeTimer?.cancel();
    _syncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _tripSubscription?.cancel();
    _locationService.removeListener(_locationChanged);
    super.dispose();
  }

  /// Initialize persistent storage and restore saved user state
  Future<void> initPersistence() async {
    try {
      _prefs = await SharedPreferences.getInstance();

      // Restore Theme
      final savedTheme = _prefs?.getString('grevidea_theme_mode');
      if (savedTheme == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (savedTheme == 'light') {
        _themeMode = ThemeMode.light;
      }

      _autoTheme = savedTheme == null || savedTheme == 'system';
      _updateAutomaticTheme();
      _themeTimer ??= Timer.periodic(
          const Duration(minutes: 1), (_) => _updateAutomaticTheme());
      // Check current user session
      final currentEmail = _prefs?.getString('grevidea_current_user_email');
      if (currentEmail != null && currentEmail.isNotEmpty) {
        _loadUserFromDb(currentEmail);
        if (_userPassword.isNotEmpty) {
          final owner = _userEmail;
          unawaited(_api.login(_userEmail, _userPassword).then((_) async {
            if (owner != _userEmail || !_isAuthenticated) return;
            await syncPendingLedger();
            await refreshSharedHistory();
          }));
        }
      } else {
        // Default clean state for first launch before login
        _isAuthenticated = false;
        _hasCompletedOnboarding = false;
        _plants.clear();
      }

      _syncTimer ??= Timer.periodic(
          const Duration(minutes: 1), (_) => syncPendingLedger());
      unawaited(syncPendingLedger());
      // Acquire live GPS coordinates
      await _locationService.bindAccount(_isAuthenticated ? _userEmail : null);
      await _locationService.startSilentTracking();
    } catch (e) {
      debugPrint('Error initializing AppState persistence: $e');
    }
    notifyListeners();
  }

  void _initBackend() async {
    final reachable = await _api.checkHealth();
    if (reachable) {
      final aqiData = await _api.fetchAqi(city: 'Thane');
      if (aqiData['aqi'] != null) {
        _currentAqi = aqiData['aqi'] is int
            ? aqiData['aqi']
            : (int.tryParse(aqiData['aqi'].toString()) ?? _currentAqi);
        _aqiCategory = aqiData['category']?.toString() ?? _aqiCategory;
        notifyListeners();
      }
    }
  }

  // ── Theme State ──────────────────────────────────────────────────
  Timer? _themeTimer;
  bool _autoTheme = true;
  @override
  void didChangePlatformBrightness() => _updateAutomaticTheme();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _updateAutomaticTheme();
  }

  void _updateAutomaticTheme() {
    if (!_autoTheme) return;
    final hour = DateTime.now().hour;
    final dark = hour < 6 ||
        hour >= 18 ||
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    final mode = dark ? ThemeMode.dark : ThemeMode.light;
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
    }
  }

  ThemeMode _themeMode = (DateTime.now().hour < 6 || DateTime.now().hour >= 18)
      ? ThemeMode.dark
      : ThemeMode.light;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme() {
    _autoTheme = false;
    _themeMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    _prefs?.setString('grevidea_theme_mode', isDarkMode ? 'dark' : 'light');
    notifyListeners();
  }

  void setTheme(ThemeMode mode) {
    _autoTheme = mode == ThemeMode.system;
    _themeMode = mode;
    _updateAutomaticTheme();
    _prefs?.setString(
        'grevidea_theme_mode',
        mode == ThemeMode.system
            ? 'system'
            : mode == ThemeMode.dark
                ? 'dark'
                : 'light');
    notifyListeners();
  }

  // ── Auth & User State ────────────────────────────────────────────
  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  bool _hasCompletedOnboarding = false;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;

  String _userName = 'Siddharth Kumar';
  String get userName => _userName;

  String _userEmail = 'esskay400d@gmail.com';
  String get userEmail => _userEmail;

  // ── 58-Feature Baseline Data ─────────────────────────────────────
  UserBaselineProfile _baseline = UserBaselineProfile();
  UserBaselineProfile get baseline => _baseline;

  void completeOnboarding() {
    _hasCompletedOnboarding = true;
    _enqueue(
        '/api/v1/baseline', {'profile': _baseline.toJson(), 'completed': true});
    _saveCurrentUserToDb();
    notifyListeners();
  }

  void updateBaseline({
    Map<String, double>? commuteDistances,
    required String cityWard,
    required String primaryCommute,
    required double dailyCommuteKm,
    required String dietaryPreference,
    required double monthlyElectricityKwh,
    required String dwellingType,
    required bool hasRooftopSolar,
    required String primaryGoal,
  }) {
    _baseline = UserBaselineProfile(
      commuteDistances: commuteDistances,
      cityWard: cityWard,
      primaryCommute: primaryCommute,
      dailyCommuteKm: dailyCommuteKm,
      dietaryPreference: dietaryPreference,
      monthlyElectricityKwh: monthlyElectricityKwh,
      dwellingType: dwellingType,
      hasRooftopSolar: hasRooftopSolar,
      primaryGoal: primaryGoal,
    );
    _hasCompletedOnboarding = true;
    _enqueue(
        '/api/v1/baseline', {'profile': _baseline.toJson(), 'completed': true});
    _saveCurrentUserToDb();
    recalculateMetrics();
    notifyListeners();
  }

  // ── Dashboard & Environmental Metrics (Computed Dynamically) ─────
  int _score = 50;
  int get score => _score;

  double _co2SavedToday = 0.0;
  double get co2SavedToday => _co2SavedToday;

  double get totalCo2Saved {
    double total = 0.0;
    for (final a in _recentActivities) {
      if (a.co2Kg < 0) total += a.co2Kg.abs();
    }
    return double.parse(total.toStringAsFixed(1));
  }

  int _streakDays = 0;
  int get streakDays => _streakDays;

  int _greenPoints = 0;
  int get greenPoints => _greenPoints;

  double _treesEquivalent = 0.0;
  double get treesEquivalent => _treesEquivalent;

  int _currentAqi = 0;
  int get currentAqi => _currentAqi;
  String _aqiCategory = 'Unavailable';
  String get aqiCategory => _aqiCategory;

  bool _challengeAccepted = false;
  bool get challengeAccepted => _challengeAccepted;

  // Unit Preferences: true = Metric (km, kg CO2, °C), false = Imperial (mi, lbs CO2, °F)
  bool _useMetricUnits = true;
  bool get useMetricUnits => _useMetricUnits;
  void setUseMetricUnits(bool metric) {
    _useMetricUnits = metric;
    notifyListeners();
  }

  void recalculateMetrics() {
    final now = DateTime.now();
    double savedToday = 0.0;

    for (final a in _recentActivities) {
      if (a.timestamp.year == now.year &&
          a.timestamp.month == now.month &&
          a.timestamp.day == now.day) {
        if (a.co2Kg < 0) {
          savedToday += a.co2Kg.abs();
        }
      }
    }

    _co2SavedToday = double.parse(savedToday.toStringAsFixed(1));

    // Tree equivalents: 1 mature Indian urban tree absorbs ~21.0 kg CO2/year (~0.057 kg/day)
    _treesEquivalent = _co2SavedToday > 0
        ? double.parse((_co2SavedToday / 21.0).toStringAsFixed(2))
        : 0.0;

    // Dynamic Environmental Score (0 to 100) calculated from baseline lifestyle + active stewardship
    int baseScore = 50;

    if (_baseline.hasRooftopSolar) baseScore += 10;
    if (!_baseline.dietaryPreference.toLowerCase().contains('non-veg') &&
        (_baseline.dietaryPreference.toLowerCase().contains('veg') ||
            _baseline.dietaryPreference.toLowerCase().contains('plant'))) {
      baseScore += 8;
    }

    final commuteLower = _baseline.primaryCommute.toLowerCase();
    if (commuteLower.contains('metro') ||
        commuteLower.contains('ev') ||
        commuteLower.contains('train') ||
        commuteLower.contains('bicycle') ||
        commuteLower.contains('walk')) {
      baseScore += 10;
    } else if (commuteLower.contains('petrol') ||
        commuteLower.contains('diesel') ||
        commuteLower.contains('car')) {
      baseScore -= 6;
    }

    // Stewardship activities bonus (+3 per activity logged today)
    final todayActivitiesCount = _recentActivities
        .where((a) =>
            a.timestamp.year == now.year &&
            a.timestamp.month == now.month &&
            a.timestamp.day == now.day)
        .length;
    baseScore += (todayActivitiesCount * 3).clamp(0, 18);

    _score = baseScore.clamp(20, 99);
  }

  // ── Recent Activity Logs (Populated on real usage, persisted to DB) ──
  final List<ActivityLogItem> _recentActivities = [];
  List<ActivityLogItem> get recentActivities =>
      List.unmodifiable(_recentActivities);

  // ── Plant Growth Tracker Records (Completely empty [] for new users) ──
  final List<PlantGrowthRecord> _plants = [];
  List<PlantGrowthRecord> get plants => List.unmodifiable(_plants);

  void addPlant(PlantGrowthRecord plant) {
    _plants.add(plant);
    _greenPoints += plant.pointsEarned;
    _saveCurrentUserToDb();
    recalculateMetrics();
    notifyListeners();
  }

  void updatePlant(PlantGrowthRecord updated) {
    final idx = _plants.indexWhere((p) => p.id == updated.id);
    if (idx != -1) {
      _plants[idx] = updated;
      _saveCurrentUserToDb();
      notifyListeners();
    }
  }

  void forfeitPlant(int plantId) {
    final idx = _plants.indexWhere((p) => p.id == plantId);
    if (idx != -1) {
      final p = _plants[idx];
      // Deduct plant-points if check-in missed
      _greenPoints = (_greenPoints - p.pointsEarned).clamp(0, 999999);
      _plants[idx] = PlantGrowthRecord(
        id: p.id,
        species: p.species,
        location: p.location,
        plantedDate: p.plantedDate,
        currentMonth: p.currentMonth,
        isMonthVerified: false,
        pointsEarned: 0,
        isForfeited: true,
      );
      _saveCurrentUserToDb();
      recalculateMetrics();
      notifyListeners();
    }
  }

  String _taskKey(String id) =>
      'claim_${userEmail}_${DateTime.now().toIso8601String().substring(0, 10)}_$id';
  final Set<String> _sessionClaims = {};
  bool isTaskClaimed(String id) =>
      _sessionClaims.contains(_taskKey(id)) ||
      (_prefs?.getBool(_taskKey(id)) ?? false);
  bool claimTask(String id) {
    if (isTaskClaimed(id)) return false;
    _sessionClaims.add(_taskKey(id));
    _prefs?.setBool(_taskKey(id), true);
    final day = DateTime.now()
        .toUtc()
        .add(const Duration(hours: 5, minutes: 30))
        .toIso8601String()
        .substring(0, 10);
    _enqueue('/api/v1/habits/claim', {'habit_id': id, 'day': day});
    return true;
  }

  // ── Backend API Actions ──────────────────────────────────────────
  Future<void> logActivity({
    required String title,
    required String category,
    required String subtitle,
    required double co2Kg,
    required IconData icon,
    int pointsEarned = 0,
    String? clientId,
    bool syncToServer = true,
    DateTime? timestamp,
  }) async {
    clientId ??= 'activity-${DateTime.now().microsecondsSinceEpoch}';
    if (_recentActivities.any((a) => a.clientId == clientId)) return;
    final occurredAt = timestamp ?? DateTime.now();
    _recentActivities.insert(
      0,
      ActivityLogItem(
        clientId: clientId,
        title: title,
        category: category,
        subtitle: subtitle,
        co2Kg: co2Kg,
        icon: icon,
        timestamp: occurredAt,
      ),
    );
    _greenPoints += pointsEarned;
    recalculateMetrics();
    _saveCurrentUserToDb();
    notifyListeners();

    if (syncToServer)
      await _enqueue('/api/v1/activities', {
        'client_id': clientId,
        'category': category,
        'title': title,
        'subtitle': subtitle,
        'co2_delta_kg': co2Kg,
        'occurred_at': occurredAt.toUtc().toIso8601String()
      });
    // Estimates are user-reported; the server's authoritative point ledger is separate.
    // Do not invent a five-kilometre trip for unrelated food/energy/waste actions.
  }

  void acceptChallenge({int bonusPoints = 50}) {
    if (_challengeAccepted) return;
    _challengeAccepted = true;
    _greenPoints += bonusPoints;
    _saveCurrentUserToDb();
    notifyListeners();
  }

  void setVerifiedPoints(int points) {
    _greenPoints = points < 0 ? 0 : points;
    _saveCurrentUserToDb();
    notifyListeners();
  }

  bool redeemReward({required int cost, required String rewardName}) {
    if (cost > 0 && _greenPoints >= cost) {
      _greenPoints -= cost;
      _saveCurrentUserToDb();
      notifyListeners();
      return true;
    }
    return false;
  }

  void voteCivicProject(int pointsReward) {
    _greenPoints += pointsReward;
    _saveCurrentUserToDb();
    recalculateMetrics();
    notifyListeners();
  }

  void completeLearningCard(int pointsReward) {
    _greenPoints += pointsReward;
    _saveCurrentUserToDb();
    recalculateMetrics();
    notifyListeners();
  }

  // ── Local Database Persistence Engine ────────────────────────────
  String _userPassword = '';
  String get userPassword => _userPassword;

  final Map<String, dynamic> _inMemoryUsersDb = {};

  Map<String, dynamic> _getUsersDb() {
    if (_inMemoryUsersDb.isNotEmpty) {
      return Map<String, dynamic>.from(_inMemoryUsersDb);
    }
    final raw = _prefs?.getString('grevidea_users_db');
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _inMemoryUsersDb.addAll(decoded);
      return Map<String, dynamic>.from(_inMemoryUsersDb);
    } catch (_) {
      return {};
    }
  }

  void _saveUsersDb(Map<String, dynamic> db) {
    _inMemoryUsersDb.clear();
    _inMemoryUsersDb.addAll(db);
    _prefs?.setString('grevidea_users_db', jsonEncode(db));
  }

  void _loadUserFromDb(String email) {
    _pendingTrips.clear();
    _selectedTransitMode = null;
    final db = _getUsersDb();
    final user = db[email.trim().toLowerCase()];
    if (user != null && user is Map<String, dynamic>) {
      _userEmail = email.trim();
      _userName = user['displayName'] as String? ?? 'User';
      _userPassword = user['password'] as String? ?? '';
      _hasCompletedOnboarding =
          user['hasCompletedOnboarding'] as bool? ?? false;
      _greenPoints = user['greenPoints'] as int? ?? 0;
      _score = user['score'] as int? ?? 50;

      if (user['baseline'] != null) {
        _baseline = UserBaselineProfile.fromJson(
            Map<String, dynamic>.from(user['baseline']));
      } else {
        _baseline = UserBaselineProfile();
      }

      _plants.clear();
      if (user['plants'] != null && user['plants'] is List) {
        for (final p in user['plants']) {
          if (p is Map) {
            _plants
                .add(PlantGrowthRecord.fromJson(Map<String, dynamic>.from(p)));
          }
        }
      }

      _recentActivities.clear();
      if (user['activities'] != null && user['activities'] is List) {
        for (final a in user['activities']) {
          if (a is Map) {
            _recentActivities
                .add(ActivityLogItem.fromJson(Map<String, dynamic>.from(a)));
          }
        }
      }

      _isAuthenticated = true;
    } else {
      // Brand new user record: completely empty zero state
      _userEmail = email.trim();
      _userName = email.split('@').first;
      _userPassword = '';
      _hasCompletedOnboarding = false;
      _greenPoints = 0;
      _score = 50;
      _baseline = UserBaselineProfile();
      _plants.clear();
      _recentActivities.clear();
      _isAuthenticated = true;
      _saveCurrentUserToDb();
    }
    recalculateMetrics();
  }

  void _saveCurrentUserToDb() {
    if (_userEmail.isEmpty) return;
    final db = _getUsersDb();
    final emailKey = _userEmail.trim().toLowerCase();

    // Preserve existing password if not currently set in memory
    String passToSave = _userPassword;
    if (passToSave.isEmpty &&
        db[emailKey] != null &&
        db[emailKey]['password'] != null) {
      passToSave = db[emailKey]['password'] as String;
    }

    final userRecord = {
      'email': _userEmail,
      'displayName': _userName,
      'password': passToSave,
      'hasCompletedOnboarding': _hasCompletedOnboarding,
      'greenPoints': _greenPoints,
      'score': _score,
      'baseline': _baseline.toJson(),
      'plants': _plants.map((p) => p.toJson()).toList(),
      'activities': _recentActivities.map((a) => a.toJson()).toList(),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    db[emailKey] = userRecord;
    _saveUsersDb(db);
    _prefs?.setString('grevidea_current_user_email', _userEmail);
  }

  // ── Auth Actions ─────────────────────────────────────────────────
  bool login(String email, String password, {String? displayName}) {
    final cleanEmail = email.trim();
    final db = _getUsersDb();
    final emailKey = cleanEmail.toLowerCase();

    // Validate credentials if user exists and password is provided (skip for google oauth)
    if (db.containsKey(emailKey)) {
      final existingUser = db[emailKey];
      if (existingUser is Map<String, dynamic> &&
          existingUser['password'] != null &&
          (existingUser['password'] as String).isNotEmpty &&
          password != 'google_oauth_token') {
        if (existingUser['password'] != password) {
          debugPrint('Invalid password for user $cleanEmail');
          return false;
        }
      }
    }

    _loadUserFromDb(cleanEmail);
    if (password != 'google_oauth_token' && password.isNotEmpty) {
      _userPassword = password;
    }

    if (displayName != null && displayName.trim().isNotEmpty) {
      _userName = displayName.trim();
    }
    _isAuthenticated = true;
    _saveCurrentUserToDb();
    _locationService
        .bindAccount(_userEmail)
        .then((_) => _locationService.startSilentTracking());

    // Async sync with Axum
    _api.login(cleanEmail, password).then((res) {
      if (res != null && res['display_name'] != null) {
        _userName = res['display_name'];
        _saveCurrentUserToDb();
        notifyListeners();
      }
    });

    notifyListeners();
    return true;
  }

  bool signup(
      {required String name, required String email, required String password}) {
    final cleanEmail = email.trim();
    final emailKey = cleanEmail.toLowerCase();
    final db = _getUsersDb();

    // If user already exists in local database, log them in preserving their onboarding & plant status
    if (db.containsKey(emailKey)) {
      _loadUserFromDb(cleanEmail);
      if (password.isNotEmpty && password != 'google_oauth_token') {
        _userPassword = password;
      }
      if (name.trim().isNotEmpty) {
        _userName = name.trim();
      }
      _saveCurrentUserToDb();
      _api.login(cleanEmail, password);
      notifyListeners();
      return true;
    }

    _pendingTrips.clear();
    _selectedTransitMode = null;
    // Brand new user: empty zero-state
    _userEmail = cleanEmail;
    _userName =
        name.trim().isNotEmpty ? name.trim() : cleanEmail.split('@').first;
    _userPassword = password;
    _hasCompletedOnboarding = false;
    _greenPoints = 0;
    _plants.clear();
    _recentActivities.clear();
    _baseline = UserBaselineProfile();
    _isAuthenticated = true;

    _saveCurrentUserToDb();
    _locationService
        .bindAccount(_userEmail)
        .then((_) => _locationService.startSilentTracking());

    // Async sync with Axum
    _api.register(
        email: _userEmail, password: password, displayName: _userName);

    notifyListeners();
    return true;
  }

  void logout() {
    _pendingTrips.clear();
    _selectedTransitMode = null;
    _isAuthenticated = false;
    _locationService.bindAccount(null);
    _prefs?.remove('grevidea_current_user_email');
    _api.setAuthToken(null);
    notifyListeners();
  }

  bool changePassword(
      {required String currentPassword, required String newPassword}) {
    notifyListeners();
    return true;
  }
}
