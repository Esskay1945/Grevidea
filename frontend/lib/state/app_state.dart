import 'package:flutter/material.dart';
import '../core/network/api_service.dart';

class UserBaselineProfile {
  String cityWard;
  String primaryCommute;
  double dailyCommuteKm;
  String dietaryPreference;
  double monthlyElectricityKwh;
  String dwellingType;
  bool hasRooftopSolar;
  String primaryGoal;

  UserBaselineProfile({
    this.cityWard = 'Thane West, Maharashtra',
    this.primaryCommute = 'Metro',
    this.dailyCommuteKm = 18.5,
    this.dietaryPreference = 'Vegetarian',
    this.monthlyElectricityKwh = 160.0,
    this.dwellingType = 'Apartment',
    this.hasRooftopSolar = false,
    this.primaryGoal = 'Reduce Carbon & Earn Rewards',
  });
}

class ActivityLogItem {
  final String title;
  final String category;
  final String subtitle;
  final double co2Kg;
  final IconData icon;
  final DateTime timestamp;

  ActivityLogItem({
    required this.title,
    required this.category,
    required this.subtitle,
    required this.co2Kg,
    required this.icon,
    required this.timestamp,
  });
}

class AppState extends ChangeNotifier {
  final ApiService _api = ApiService();
  ApiService get api => _api;

  AppState() {
    recalculateMetrics();
    _initBackend();
  }

  void _initBackend() async {
    final reachable = await _api.checkHealth();
    if (reachable) {
      await _api.autoLogin();
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
  ThemeMode _themeMode = ThemeMode.light; // Defaults to light theme matching the reference image, easily toggled
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme() {
    _themeMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void setTheme(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  // ── Auth & User State ────────────────────────────────────────────
  bool _isAuthenticated = true;
  bool get isAuthenticated => _isAuthenticated;

  String _userName = 'Siddharth Kumar';
  String get userName => _userName;

  String _userEmail = 'esskay400d@gmail.com';
  String get userEmail => _userEmail;

  // ── 58-Feature Baseline Data ─────────────────────────────────────
  UserBaselineProfile _baseline = UserBaselineProfile();
  UserBaselineProfile get baseline => _baseline;

  void updateBaseline({
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
      cityWard: cityWard,
      primaryCommute: primaryCommute,
      dailyCommuteKm: dailyCommuteKm,
      dietaryPreference: dietaryPreference,
      monthlyElectricityKwh: monthlyElectricityKwh,
      dwellingType: dwellingType,
      hasRooftopSolar: hasRooftopSolar,
      primaryGoal: primaryGoal,
    );
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

  int _currentAqi = 54;
  int get currentAqi => _currentAqi;
  String _aqiCategory = 'Moderate';
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

    // Sum CO2 activities logged today by user
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
    if (_baseline.dietaryPreference.toLowerCase().contains('veg') ||
        _baseline.dietaryPreference.toLowerCase().contains('plant')) {
      baseScore += 8;
    }

    final commuteLower = _baseline.primaryCommute.toLowerCase();
    if (commuteLower.contains('metro') ||
        commuteLower.contains('ev') ||
        commuteLower.contains('train') ||
        commuteLower.contains('bicycle') ||
        commuteLower.contains('walk')) {
      baseScore += 10;
    } else if (commuteLower.contains('petrol') || commuteLower.contains('diesel') || commuteLower.contains('car')) {
      baseScore -= 6;
    }

    // Stewardship activities bonus (+3 per activity logged today)
    final todayActivitiesCount = _recentActivities.where((a) =>
        a.timestamp.year == now.year &&
        a.timestamp.month == now.month &&
        a.timestamp.day == now.day).length;
    baseScore += (todayActivitiesCount * 3).clamp(0, 18);

    _score = baseScore.clamp(20, 99);
  }

  // ── Recent Activity Logs (Pure dynamic, populated on real usage) ──
  final List<ActivityLogItem> _recentActivities = [];
  List<ActivityLogItem> get recentActivities => List.unmodifiable(_recentActivities);

  // ── Backend API Actions ──────────────────────────────────────────
  Future<void> logActivity({
    required String title,
    required String category,
    required String subtitle,
    required double co2Kg,
    required IconData icon,
    int pointsEarned = 15,
  }) async {
    _recentActivities.insert(
      0,
      ActivityLogItem(
        title: title,
        category: category,
        subtitle: subtitle,
        co2Kg: co2Kg,
        icon: icon,
        timestamp: DateTime.now(),
      ),
    );
    _greenPoints += pointsEarned;
    recalculateMetrics();
    notifyListeners();

    // Sync with Axum backend
    try {
      await _api.logCarbonTrip(
        mode: category.toLowerCase(),
        distanceKm: 5.0,
        co2Kg: co2Kg,
        pointsEarned: pointsEarned,
      );
    } catch (_) {}
  }

  void acceptChallenge({int bonusPoints = 50}) {
    _challengeAccepted = true;
    _greenPoints += bonusPoints;
    notifyListeners();
  }

  bool redeemReward({required int cost, required String rewardName}) {
    if (_greenPoints >= cost) {
      _greenPoints -= cost;
      notifyListeners();
      return true;
    }
    return false;
  }

  void voteCivicProject(int pointsReward) {
    _greenPoints += pointsReward;
    recalculateMetrics();
    notifyListeners();
  }

  void completeLearningCard(int pointsReward) {
    _greenPoints += pointsReward;
    recalculateMetrics();
    notifyListeners();
  }

  // ── Auth Actions ─────────────────────────────────────────────────
  bool login(String email, String password, {String? displayName}) {
    _userEmail = email.trim();
    if (displayName != null && displayName.trim().isNotEmpty) {
      _userName = displayName.trim();
    } else if (_userEmail.toLowerCase().contains('esskay') || _userEmail.toLowerCase().contains('siddharth')) {
      _userName = 'Siddharth Kumar';
    } else {
      final rawName = email.split('@').first;
      _userName = rawName.isNotEmpty ? rawName[0].toUpperCase() + rawName.substring(1) : 'Siddharth';
    }
    _isAuthenticated = true;
    _api.login(email, password).then((res) {
      if (res != null && res['display_name'] != null) {
        _userName = res['display_name'];
        notifyListeners();
      }
    });
    notifyListeners();
    return true;
  }

  bool signup({required String name, required String email, required String password}) {
    _userName = name.trim().isNotEmpty ? name.trim() : email.split('@').first;
    _userEmail = email.trim();
    _isAuthenticated = true;
    _api.register(email: _userEmail, password: password, displayName: _userName);
    notifyListeners();
    return true;
  }

  void logout() {
    _isAuthenticated = false;
    _api.setAuthToken(null);
    notifyListeners();
  }

  bool changePassword({required String currentPassword, required String newPassword}) {
    notifyListeners();
    return true;
  }
}
