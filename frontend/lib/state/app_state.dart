import 'package:flutter/material.dart';

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

class AppState extends ChangeNotifier {
  // ── Theme State ──────────────────────────────────────────────────
  ThemeMode _themeMode = ThemeMode.dark;
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
  bool _isAuthenticated = true; // Set to true by default for immediate preview, but fully controllable
  bool get isAuthenticated => _isAuthenticated;

  String _userName = 'Yash';
  String get userName => _userName;

  String _userEmail = 'yash@grevidea.org';
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
    notifyListeners();
  }

  // ── Dashboard & Environmental Metrics ────────────────────────────
  int _score = 82;
  int get score => _score;

  double _co2SavedToday = 2.4;
  double get co2SavedToday => _co2SavedToday;

  int _streakDays = 14;
  int get streakDays => _streakDays;

  int _greenPoints = 812;
  int get greenPoints => _greenPoints;

  double _treesEquivalent = 2.6;
  double get treesEquivalent => _treesEquivalent;

  int _currentAqi = 38;
  int get currentAqi => _currentAqi;
  String _aqiCategory = 'Good';
  String get aqiCategory => _aqiCategory;

  bool _challengeAccepted = false;
  bool get challengeAccepted => _challengeAccepted;

  void acceptChallenge() {
    _challengeAccepted = true;
    _greenPoints += 50;
    notifyListeners();
  }

  // ── Auth Actions ─────────────────────────────────────────────────
  bool login(String email, String password) {
    _userEmail = email;
    _userName = email.split('@').first;
    _isAuthenticated = true;
    notifyListeners();
    return true;
  }

  bool signup({required String name, required String email, required String password}) {
    _userName = name;
    _userEmail = email;
    _isAuthenticated = true;
    notifyListeners();
    return true;
  }

  void logout() {
    _isAuthenticated = false;
    notifyListeners();
  }

  bool changePassword({required String currentPassword, required String newPassword}) {
    // In-memory verification simulation
    notifyListeners();
    return true;
  }
}
