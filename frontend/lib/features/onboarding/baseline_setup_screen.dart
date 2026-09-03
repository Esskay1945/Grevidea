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
    if (!_dietOptions.contains(_selectedDiet)) _selectedDiet = _dietOptions.first;
    if (!_dwellingTypes.contains(_dwellingType)) _dwellingType = _dwellingTypes.first;

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
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.champagneGold, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.solar_power_rounded, color: AppColors.champagneGold, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'What is Rooftop Solar PV?',
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
              'Rooftop Solar Photovoltaic (PV) systems consist of solar panels mounted on top of your residential building, society terrace, or home roof.\n',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            _infoBullet('Zero-Emission Power', 'Directly converts sunlight into electricity, offsetting coal-fired thermal grid power.'),
            const SizedBox(height: 6),
            _infoBullet('Calculated Emission Credits', 'Reduces your household Scope 2 emission factor in Grevidea from 0.82 kg CO₂/kWh down to ~0.05 kg CO₂/kWh.'),
            const SizedBox(height: 6),
            _infoBullet('Grevidea Green Points', 'Enabling this automatically awards +150 bonus Green Points and unlocks the Solar Champion badge.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Understood',
              style: TextStyle(color: AppColors.champagneGold, fontWeight: FontWeight.bold),
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
        const Text('• ', style: TextStyle(color: AppColors.emerald, fontWeight: FontWeight.bold)),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.3),
              children: [
                TextSpan(text: '$title: ', style: const TextStyle(color: AppColors.champagneGold, fontWeight: FontWeight.bold)),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _handleSave() {
    if (_formKey.currentState?.validate() ?? false) {
      final commuteSummary = _selectedCommuteDistances.entries
          .map((e) => '${e.key} (${e.value.toStringAsFixed(1)} km)')
          .join(', ');

      widget.appState.updateBaseline(
        cityWard: _selectedCity,
        primaryCommute: commuteSummary.isNotEmpty ? commuteSummary : 'Metro',
        dailyCommuteKm: _totalDailyCommuteKm > 0 ? _totalDailyCommuteKm : 10.0,
        dietaryPreference: _selectedDiet,
        monthlyElectricityKwh: _monthlyKwh,
        dwellingType: _dwellingType,
        hasRooftopSolar: _hasSolar,
        primaryGoal: 'Carbon Reduction & Civic Action',
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
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

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
                      const Icon(Icons.tune_rounded, color: AppColors.champagneGold, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Baseline Telemetry Engine',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.champagneGold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Calibrates your local AQI, commute recommendations, and 58 carbon tracking tools.',
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

                // ── 1. Municipal Ward & Location ─────────────────────────────
                _SectionTitle(title: '1. Municipal Ward & Location'),
                DropdownButtonFormField<String>(
                  value: _selectedCity,
                  isExpanded: true,
                  items: _cities
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(
                              c,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCity = v!),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.location_on_outlined, color: AppColors.champagneGold),
                  ),
                ),

                const SizedBox(height: 22),

                // ── 2. Daily Commute Mode (Multi-Select) ─────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _SectionTitle(title: '2. Daily Commute Modes'),
                    Text(
                      'Select all that apply',
                      style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Commute Mode Selection Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _allCommuteModes.map((mode) {
                    final isSelected = _selectedCommuteDistances.containsKey(mode);
                    return FilterChip(
                      label: Text(
                        mode,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppColors.champagneGold : textColor,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.royalForest,
                      checkmarkColor: AppColors.champagneGold,
                      backgroundColor: cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isSelected ? AppColors.champagneGold : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
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

                // Per-Mode Distance Sliders
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Daily Distance per Mode:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Total: ${_totalDailyCommuteKm.toStringAsFixed(1)} km/day',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.emerald),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      ..._selectedCommuteDistances.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      entry.key,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '${entry.value.toStringAsFixed(1)} km',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.champagneGold),
                                  ),
                                ],
                              ),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                ),
                                child: Slider(
                                  value: entry.value,
                                  min: 0.5,
                                  max: 50.0,
                                  divisions: 99,
                                  activeColor: AppColors.champagneGold,
                                  inactiveColor: AppColors.champagneGold.withValues(alpha: 0.2),
                                  onChanged: (newDist) {
                                    setState(() {
                                      _selectedCommuteDistances[entry.key] = newDist;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // ── 3. Dietary Profile ───────────────────────────────────────
                _SectionTitle(title: '3. Dietary Profile'),
                DropdownButtonFormField<String>(
                  value: _selectedDiet,
                  isExpanded: true,
                  items: _dietOptions
                      .map((d) => DropdownMenuItem(
                            value: d,
                            child: Text(d, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
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
                  inactiveColor: AppColors.champagneGold.withValues(alpha: 0.2),
                  onChanged: (v) => setState(() => _monthlyKwh = v),
                ),

                const SizedBox(height: 20),

                // ── 5. Residence & Clean Energy ──────────────────────────────
                Row(
                  children: [
                    _SectionTitle(title: '5. Residence & Clean Energy'),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _showSolarInfoModal(isDark),
                      child: const Icon(Icons.info_outline_rounded, color: AppColors.champagneGold, size: 18),
                    ),
                  ],
                ),
                DropdownButtonFormField<String>(
                  value: _dwellingType,
                  isExpanded: true,
                  items: _dwellingTypes
                      .map((d) => DropdownMenuItem(
                            value: d,
                            child: Text(d, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _dwellingType = v!),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.home_outlined, color: AppColors.champagneGold),
                  ),
                ),

                const SizedBox(height: 12),

                // Clean Energy Source Selector
                DropdownButtonFormField<String>(
                  value: _selectedCleanEnergy,
                  isExpanded: true,
                  items: _cleanEnergyOptions
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(e, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedCleanEnergy = v!;
                      _hasSolar = v.contains('Solar');
                    });
                  },
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.solar_power_outlined, color: AppColors.champagneGold),
                  ),
                ),

                const SizedBox(height: 12),

                // Interactive Solar PV Toggle with Info Icon
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
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
                                    'Rooftop Solar PV Installed',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => _showSolarInfoModal(isDark),
                                  child: const Icon(Icons.info_outline_rounded, color: AppColors.champagneGold, size: 16),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Offsets coal grid emission multipliers (-75%)',
                              style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _hasSolar,
                        activeThumbColor: AppColors.champagneGold,
                        activeTrackColor: AppColors.royalForest,
                        onChanged: (v) {
                          setState(() {
                            _hasSolar = v;
                            if (v && !_selectedCleanEnergy.contains('Solar')) {
                              _selectedCleanEnergy = 'Rooftop Solar PV Installed (Net-Metered)';
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
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.champagneGold,
        ),
      ),
    );
  }
}
