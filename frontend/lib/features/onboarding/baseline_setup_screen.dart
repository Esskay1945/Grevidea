import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/responsive_wrapper.dart';
import '../../state/app_state.dart';
import '../dashboard/dashboard_screen.dart';

class BaselineSetupScreen extends StatefulWidget {
  final AppState appState;
  final bool isInitialSetup;

  const BaselineSetupScreen({
    super.key,
    required this.appState,
    this.isInitialSetup = false,
  });

  @override
  State<BaselineSetupScreen> createState() => _BaselineSetupScreenState();
}

class _BaselineSetupScreenState extends State<BaselineSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  late String _selectedCity;
  late String _selectedCommute;
  late double _commuteKm;
  late String _selectedDiet;
  late double _monthlyKwh;
  late String _dwellingType;
  late bool _hasSolar;
  late String _selectedGoal;

  final List<String> _cities = [
    'Thane West, Maharashtra',
    'Thane East, Maharashtra',
    'Mumbai Suburban (Bandra/BKC)',
    'South Mumbai (Colaba/Nariman Point)',
    'Navi Mumbai (Vashi/Belapur)',
    'Pune Municipal Corporation',
    'Delhi NCR (Anand Vihar/Dwarka)',
    'Bengaluru Urban',
  ];

  final List<String> _commuteModes = [
    'Metro',
    'Electric Bus / City Bus',
    'Petrol / Diesel Car',
    'Motorcycle / Scooter',
    'Bicycle / Walking',
    'Carpool / Shared Cab',
  ];

  final List<String> _dietOptions = [
    'Vegetarian (Traditional Indian)',
    'Vegan (Plant-Based)',
    'Eggetarian',
    'Non-Vegetarian (Frequent Poultry/Meat)',
  ];

  final List<String> _dwellingTypes = [
    'Apartment (High-rise Gated Society)',
    'Independent House / Villa',
    'Row House / Bungalow',
  ];

  final List<String> _goals = [
    'Reduce Carbon Footprint & Earn Points',
    'Lower Electricity Bills & Home Energy',
    'Civic Hazard Reporting & Cleanups',
    'Compete in Community Leaderboards',
  ];

  @override
  void initState() {
    super.initState();
    final b = widget.appState.baseline;
    _selectedCity = b.cityWard;
    _selectedCommute = b.primaryCommute;
    _commuteKm = b.dailyCommuteKm;
    _selectedDiet = b.dietaryPreference;
    _monthlyKwh = b.monthlyElectricityKwh;
    _dwellingType = b.dwellingType;
    _hasSolar = b.hasRooftopSolar;
    _selectedGoal = b.primaryGoal;

    if (!_cities.contains(_selectedCity)) _selectedCity = _cities.first;
    if (!_commuteModes.contains(_selectedCommute)) _selectedCommute = _commuteModes.first;
    if (!_dietOptions.contains(_selectedDiet)) _selectedDiet = _dietOptions.first;
    if (!_dwellingTypes.contains(_dwellingType)) _dwellingType = _dwellingTypes.first;
    if (!_goals.contains(_selectedGoal)) _selectedGoal = _goals.first;
  }

  void _handleSave() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.appState.updateBaseline(
        cityWard: _selectedCity,
        primaryCommute: _selectedCommute,
        dailyCommuteKm: _commuteKm,
        dietaryPreference: _selectedDiet,
        monthlyElectricityKwh: _monthlyKwh,
        dwellingType: _dwellingType,
        hasRooftopSolar: _hasSolar,
        primaryGoal: _selectedGoal,
      );

      if (widget.isInitialSetup) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => DashboardScreen(appState: widget.appState),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.royalForest,
            content: Text(
              '✓ Profile and environmental baseline updated successfully',
              style: TextStyle(color: AppColors.champagneGold, fontWeight: FontWeight.w600),
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isInitialSetup ? 'Environmental Setup' : 'Update Profile Baseline'),
        leading: widget.isInitialSetup
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
      ),
      body: ResponsiveWrapper(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18.0),
                  decoration: BoxDecoration(
                    color: AppColors.royalForest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.goldBorder, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.tune_rounded, color: AppColors.champagneGold, size: 30),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Baseline Telemetry Engine',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.champagneGold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Powers your daily AQI, commute recommendations, and 58 carbon tracking tools.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.75),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── 1. City & Ward ───────────────────────────────────────────
                _SectionTitle(title: '1. Municipal Ward & Location'),
                DropdownButtonFormField<String>(
                  value: _selectedCity,
                  items: _cities.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14)))).toList(),
                  onChanged: (v) => setState(() => _selectedCity = v!),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.location_on_outlined, color: AppColors.champagneGold),
                  ),
                ),

                const SizedBox(height: 22),

                // ── 2. Commute & Daily Distance ──────────────────────────────
                _SectionTitle(title: '2. Daily Commute Mode'),
                DropdownButtonFormField<String>(
                  value: _selectedCommute,
                  items: _commuteModes.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 14)))).toList(),
                  onChanged: (v) => setState(() => _selectedCommute = v!),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.directions_subway_outlined, color: AppColors.champagneGold),
                  ),
                ),

                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Estimated Daily Distance:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    Text('${_commuteKm.toStringAsFixed(1)} km', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.champagneGold)),
                  ],
                ),
                Slider(
                  value: _commuteKm,
                  min: 1.0,
                  max: 80.0,
                  divisions: 79,
                  activeColor: AppColors.champagneGold,
                  inactiveColor: AppColors.champagneGold.withOpacity(0.2),
                  onChanged: (v) => setState(() => _commuteKm = v),
                ),

                const SizedBox(height: 18),

                // ── 3. Dietary Profile ───────────────────────────────────────
                _SectionTitle(title: '3. Dietary Profile'),
                DropdownButtonFormField<String>(
                  value: _selectedDiet,
                  items: _dietOptions.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 14)))).toList(),
                  onChanged: (v) => setState(() => _selectedDiet = v!),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.restaurant_outlined, color: AppColors.champagneGold),
                  ),
                ),

                const SizedBox(height: 22),

                // ── 4. Household Electricity ─────────────────────────────────
                _SectionTitle(title: '4. Average Monthly Electricity (kWh)'),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Monthly consumption:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    Text('${_monthlyKwh.round()} kWh', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.champagneGold)),
                  ],
                ),
                Slider(
                  value: _monthlyKwh,
                  min: 30.0,
                  max: 600.0,
                  divisions: 57,
                  activeColor: AppColors.champagneGold,
                  inactiveColor: AppColors.champagneGold.withOpacity(0.2),
                  onChanged: (v) => setState(() => _monthlyKwh = v),
                ),

                const SizedBox(height: 18),

                // ── 5. Dwelling Type & Solar ─────────────────────────────────
                _SectionTitle(title: '5. Residence & Clean Energy'),
                DropdownButtonFormField<String>(
                  value: _dwellingType,
                  items: _dwellingTypes.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 14)))).toList(),
                  onChanged: (v) => setState(() => _dwellingType = v!),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.home_outlined, color: AppColors.champagneGold),
                  ),
                ),

                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Rooftop Solar PV Installed', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Reduces grid emission multipliers in calculations', style: TextStyle(fontSize: 12)),
                  value: _hasSolar,
                  activeColor: AppColors.champagneGold,
                  onChanged: (v) => setState(() => _hasSolar = v),
                ),

                const SizedBox(height: 18),

                // ── 6. Primary Climate Objective ─────────────────────────────
                _SectionTitle(title: '6. Primary Climate Objective'),
                DropdownButtonFormField<String>(
                  value: _selectedGoal,
                  items: _goals.map((g) => DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(fontSize: 14)))).toList(),
                  onChanged: (v) => setState(() => _selectedGoal = v!),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.flag_outlined, color: AppColors.champagneGold),
                  ),
                ),

                const SizedBox(height: 32),

                // ── Save Button ──────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _handleSave,
                    child: Text(
                      widget.isInitialSetup ? 'Complete Setup & Open Dashboard' : 'Save Baseline Profile',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.champagneGold,
        ),
      ),
    );
  }
}
