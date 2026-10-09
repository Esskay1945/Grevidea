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
  late String _selectedDiet;
  late double _monthlyKwh;
  late String _dwellingType;
  late bool _hasSolar;

  // ── 1. Extensive Localities (Thane & MMR) ──────────────────────────────────
  final List<String> _cities = [
    'Thane West (Majiwada / Ghodbunder)',
    'Thane West (Panchpakhadi / Naupada)',
    'Thane West (Vartak Nagar / Pokhran)',
    'Thane West (Hiranandani Estate / Waghbil)',
    'Thane West (Kasarvadavali / Owale)',
    'Thane East (Kopri / Anand Nagar)',
    'Kalwa & Mumbra Ward, Thane',
    'Wagle Industrial Estate, Thane',
    'Mumbai Suburban (Bandra West / BKC)',
    'Mumbai Suburban (Andheri / Juhu)',
    'Mumbai Suburban (Borivali / Kandivali)',
    'Mumbai Suburban (Powai / Hiranandani)',
    'Mumbai Suburban (Ghatkopar / Mulund)',
    'South Mumbai (Colaba / Nariman Point)',
    'South Mumbai (Dadar / Prabhadevi)',
    'Navi Mumbai (Vashi / Sanpada)',
    'Navi Mumbai (Belapur / Nerul)',
    'Navi Mumbai (Kharghar / Panvel)',
    'Kalyan-Dombivli Municipal Corp',
    'Mira-Bhayander Municipal Corp',
    'Pune Municipal Corp (Kothrud / Baner)',
    'Bengaluru Urban (Indiranagar / Whitefield)',
    'Delhi NCR (Dwarka / South Ext)',
  ];

  // ── 2. Multi-Commute Modes with Per-Mode Distances ─────────────────────────
  final List<String> _allCommuteModes = [
    'Metro',
    'Local Train',
    'City Bus (BEST / TMT)',
    'EV 2-Wheeler (e-Scooter)',
    'Petrol 2-Wheeler',
    'EV Car',
    'Petrol / Diesel Car',
    'Auto Rickshaw',
    'Shared Cab / Carpool',
    'Bicycle',
    'Walking',
  ];

  // Map storing selected mode -> distance in km
  final Map<String, double> _selectedCommuteDistances = {
    'Metro': 14.0,
    'Auto Rickshaw': 4.5,
  };

  // ── 3. Dietary Preferences ────────────────────────────────────────────────
  final List<String> _dietOptions = [
    'Vegetarian (Traditional Indian)',
    'Vegan (Plant-Based)',
    'Eggetarian',
    'Non-Vegetarian (Frequent Poultry/Meat)',
  ];

  // ── 4. Dwelling & Clean Energy ─────────────────────────────────────────────
  final List<String> _dwellingTypes = [
    'Apartment in High-Rise Gated Society',
    'Cooperative Housing Society (CHS Flat)',
    'Standalone Independent House',
    'Row House / Private Villa',
    'Shared Rental / PG Accommodation',
  ];

  final List<String> _cleanEnergyOptions = [
    'Standard Utility Grid Electricity',
    'Rooftop Solar PV Installed (Net-Metered)',
    'Hybrid Solar Inverter + Battery Storage',
    '100% Green Tariff from Discom',
    'Solar Water Heater Only',
  ];
  String _selectedCleanEnergy = 'Rooftop Solar PV Installed (Net-Metered)';

  @override
  void initState() {
    super.initState();
    final b = widget.appState.baseline;
    _selectedCity = b.cityWard;
    _selectedDiet = b.dietaryPreference;
    _monthlyKwh = b.monthlyElectricityKwh;
    _dwellingType = b.dwellingType;
    _hasSolar = b.hasRooftopSolar;

    if (!_cities.contains(_selectedCity)) _selectedCity = _cities.first;
    if (!_dietOptions.contains(_selectedDiet))
      _selectedDiet = _dietOptions.first;
    if (!_dwellingTypes.contains(_dwellingType))
      _dwellingType = _dwellingTypes.first;

    _selectedCleanEnergy = _hasSolar
        ? _cleanEnergyOptions[1]
        : _cleanEnergyOptions.first;
    if (b.commuteDistances.isNotEmpty) {
      _selectedCommuteDistances
        ..clear()
        ..addAll(b.commuteDistances);
    }
    // Parse initial commute modes if available
    if (b.primaryCommute.isNotEmpty && _selectedCommuteDistances.isEmpty) {
      _selectedCommuteDistances[b.primaryCommute] = b.dailyCommuteKm;
    }
  }

  double get _totalDailyCommuteKm {
    if (_selectedCommuteDistances.isEmpty) return 0.0;
    return _selectedCommuteDistances.values.fold(0.0, (sum, val) => sum + val);
  }

  void _showSolarInfoModal(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.accentOf(context), width: 1.5),
        ),
        title: Row(
          children: [
            Icon(
              Icons.solar_power_rounded,
              color: AppColors.accentOf(context),
              size: 28,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'What are Rooftop Solar Panels?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rooftop solar panels are installed on top of your home or building terrace to generate clean power from the sun.\n',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            _infoBullet(
              'Clean Power',
              'Converts sunlight directly into electricity, saving costs and cutting fossil power use.',
            ),
            const SizedBox(height: 6),
            _infoBullet(
              'Lower Footprint',
              'Significantly lowers your monthly home carbon footprint in Grevidea.',
            ),
            const SizedBox(height: 6),
            _infoBullet(
              'Bonus Points',
              'Gives you +150 bonus Green Points and unlocks the Solar Champion badge.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Understood',
              style: TextStyle(
                color: AppColors.accentOf(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBullet(String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '• ',
          style: TextStyle(
            color: AppColors.leafOf(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style:  TextStyle(
                fontSize: 12,
                color: AppColors.mutedOf(context),
                height: 1.3,
              ),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: TextStyle(
                    color: AppColors.accentOf(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleSave() async {
    if (_formKey.currentState?.validate() ?? false) {
      final commuteSummary = _selectedCommuteDistances.entries
          .map((e) => '${e.key} (${e.value.toStringAsFixed(1)} km)')
          .join(', ');

      widget.appState.updateBaseline(
        cityWard: _selectedCity,
        primaryCommute: commuteSummary.isNotEmpty ? commuteSummary : 'Metro',
        dailyCommuteKm: _totalDailyCommuteKm,
        commuteDistances: Map.of(_selectedCommuteDistances),
        dietaryPreference: _selectedDiet,
        monthlyElectricityKwh: _monthlyKwh,
        dwellingType: _dwellingType,
        hasRooftopSolar: _hasSolar,
        primaryGoal: 'Carbon Reduction & Civic Action',
      );

      if (widget.isInitialSetup) {
        final enableTracking = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Automatically measure green travel'),
            content: const Text(
              'Grevidea uses your location to measure travel distance and estimate your footprint as you move. Android shows a tracking notification. You can skip this and log trips manually.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Skip for now'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Enable tracking'),
              ),
            ],
          ),
        );
        if (enableTracking == true)
          await widget.appState.locationService.requestOnboardingPermission();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            settings: const RouteSettings(name: '/dashboard'),
            builder: (_) => DashboardScreen(appState: widget.appState),
          ),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.royalForest,
            content: Text(
              '✓ Profile and environmental baseline updated successfully',
              style: TextStyle(
                color: AppColors.champagneGold,
                fontWeight: FontWeight.w600,
              ),
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
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.inkOf(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isInitialSetup ? 'Your Green Profile' : 'Update Profile',
        ),
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
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: AppColors.royalForest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.goldBorder, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.tune_rounded,
                        color: AppColors.champagneGold,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your Green Profile',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.champagneGold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Help Grevidea personalize your daily eco tips, clean travel routes, and carbon savings.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.8),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── 1. City & Neighborhood ───────────────────────────────────
                _SectionTitle(title: '1. Your City & Neighborhood'),
                DropdownButtonFormField<String>(
                  value: _selectedCity,
                  isExpanded: true,
                  items: _cities
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(
                            c,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCity = v!),
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.location_on_outlined,
                      color: AppColors.accentOf(context),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                // ── 2. How Do You Travel? (Multi-Select) ────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _SectionTitle(title: '2. How Do You Travel?'),
                    Text(
                      'Select how you travel every day',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.mutedOf(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Commute Mode Selection Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _allCommuteModes.map((mode) {
                    final isSelected = _selectedCommuteDistances.containsKey(
                      mode,
                    );
                    return FilterChip(
                      label: Text(
                        mode,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? AppColors.accentOf(context)
                              : textColor,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.royalForest,
                      checkmarkColor: AppColors.accentOf(context),
                      backgroundColor: cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.accentOf(context)
                              : (isDark
                                    ? AppColors.darkCardBorder
                                    : AppColors.lightCardBorder),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedCommuteDistances[mode] = 8.0;
                          } else {
                            if (_selectedCommuteDistances.length > 1) {
                              _selectedCommuteDistances.remove(mode);
                            }
                          }
                        });
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 14),

                // Per-Mode Distance Text Boxes (Replaced Sliders with Clean Text Input)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkCardBorder
                          : AppColors.lightCardBorder,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Daily Distance for Each Mode:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Total: ${_totalDailyCommuteKm.toStringAsFixed(1)} km/day',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.leafOf(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 16),
                      ..._selectedCommuteDistances.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: TextFormField(
                            key: ValueKey('commute_dist_${entry.key}'),
                            initialValue: entry.value.toStringAsFixed(1),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                            decoration: InputDecoration(
                              labelText: '${entry.key} distance',
                              hintText: 'e.g. 10.0',
                              suffixText: 'km / day',
                              suffixStyle: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.accentOf(context),
                              ),
                              prefixIcon: Icon(
                                Icons.directions_rounded,
                                color: AppColors.accentOf(context),
                                size: 20,
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? AppColors.darkSurfaceAlt
                                  : AppColors.lightSurfaceAlt,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? AppColors.darkCardBorder
                                      : AppColors.lightCardBorder,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? AppColors.darkCardBorder
                                      : AppColors.lightCardBorder,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.accentOf(context),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            validator: (val) {
                              final number = double.tryParse(
                                (val ?? '').trim(),
                              );
                              if (number == null ||
                                  !number.isFinite ||
                                  number < 0 ||
                                  number > 2000)
                                return 'Enter 0–2000 km';
                              return null;
                            },
                            onChanged: (val) {
                              final parsed = double.tryParse(val.trim());
                              if (parsed != null &&
                                  parsed.isFinite &&
                                  parsed >= 0 &&
                                  parsed <= 2000) {
                                setState(() {
                                  _selectedCommuteDistances[entry.key] = parsed;
                                });
                              }
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // ── 3. Diet & Eating Habits ──────────────────────────────────
                _SectionTitle(title: '3. What Kind of Food Do You Eat?'),
                DropdownButtonFormField<String>(
                  value: _selectedDiet,
                  isExpanded: true,
                  items: _dietOptions
                      .map(
                        (d) => DropdownMenuItem(
                          value: d,
                          child: Text(
                            d,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedDiet = v!),
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.restaurant_outlined,
                      color: AppColors.accentOf(context),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                // ── 4. Household Electricity ─────────────────────────────────
                _SectionTitle(
                  title: '4. Monthly Electricity Consumption (kWh)',
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Estimated monthly power usage:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${_monthlyKwh.round()} kWh',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentOf(context),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _monthlyKwh,
                  min: 30.0,
                  max: 600.0,
                  divisions: 57,
                  activeColor: AppColors.accentOf(context),
                  inactiveColor: AppColors.accentOf(context)
                      .withValues(alpha: 0.2),
                  onChanged: (v) => setState(() => _monthlyKwh = v),
                ),

                const SizedBox(height: 20),

                // ── 5. Residence & Clean Energy ──────────────────────────────
                Row(
                  children: [
                    _SectionTitle(title: '5. Home Type & Clean Energy'),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _showSolarInfoModal(isDark),
                      child: Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.accentOf(context),
                        size: 18,
                      ),
                    ),
                  ],
                ),
                DropdownButtonFormField<String>(
                  value: _dwellingType,
                  isExpanded: true,
                  items: _dwellingTypes
                      .map(
                        (d) => DropdownMenuItem(
                          value: d,
                          child: Text(
                            d,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _dwellingType = v!),
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.home_outlined,
                      color: AppColors.accentOf(context),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Clean Energy Source Selector
                DropdownButtonFormField<String>(
                  value: _selectedCleanEnergy,
                  isExpanded: true,
                  items: _cleanEnergyOptions
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(
                            e,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedCleanEnergy = v!;
                      _hasSolar = v.contains('Solar');
                    });
                  },
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.solar_power_outlined,
                      color: AppColors.accentOf(context),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Interactive Solar Toggle with Info Icon
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkCardBorder
                          : AppColors.lightCardBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Flexible(
                                  child: Text(
                                    'Rooftop Solar Panels',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => _showSolarInfoModal(isDark),
                                  child: Icon(
                                    Icons.info_outline_rounded,
                                    color: AppColors.accentOf(context),
                                    size: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Produces clean solar power and reduces your energy footprint',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.mutedOf(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _hasSolar,
                        activeThumbColor: AppColors.accentOf(context),
                        activeTrackColor: AppColors.royalForest,
                        onChanged: (v) {
                          setState(() {
                            _hasSolar = v;
                            if (v && !_selectedCleanEnergy.contains('Solar')) {
                              _selectedCleanEnergy =
                                  'Rooftop Solar PV Installed (Net-Metered)';
                            }
                          });
                        },
                      ),
                    ],
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
                      widget.isInitialSetup
                          ? 'Save Profile & Open App'
                          : 'Save Changes',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
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
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.accentOf(context),
        ),
      ),
    );
  }
}
