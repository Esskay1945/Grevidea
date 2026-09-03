import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/responsive_wrapper.dart';
import '../../state/app_state.dart';

class CivicScreen extends StatefulWidget {
  final AppState appState;

  const CivicScreen({super.key, required this.appState});

  @override
  State<CivicScreen> createState() => _CivicScreenState();
}

class _CivicScreenState extends State<CivicScreen> {
  final _descController = TextEditingController();
  String _selectedWasteType = 'Plastic Dumping';
  bool _photoAttached = false;
  bool _isSubmitting = false;

  final List<String> _wasteTypes = [
    'Plastic Dumping',
    'Open Garbage Burning (Toxic Smog)',
    'Construction Debris',
    'E-Waste Hazard',
    'Sewage / Water Contamination',
  ];

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  void _handleSubmitReport() {
    setState(() => _isSubmitting = true);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _descController.clear();
        _photoAttached = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.royalForest,
          content: Text(
            '✓ Incident report dispatched to Thane Municipal Corporation! (+50 Green Points)',
            style: TextStyle(color: AppColors.champagneGold, fontWeight: FontWeight.w600),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Civic & Climate Radar'),
      ),
      body: ResponsiveWrapper(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Hyperlocal AQI Station Card ──────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18.0),
                decoration: BoxDecoration(
                  color: AppColors.royalForest,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.goldBorder, width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.air_rounded, color: AppColors.champagneGold, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Air Quality (Thane Station)',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.emerald.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.emerald, width: 0.8),
                          ),
                          child: const Text('LIVE CPCB', style: TextStyle(fontSize: 10, color: AppColors.emerald, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text('38', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: AppColors.emerald)),
                                SizedBox(width: 8),
                                Text('Good', style: TextStyle(fontSize: 16, color: AppColors.emerald, fontWeight: FontWeight.w700)),
                              ],
                            ),
                            Text('Satisfactory air quality for outdoor workouts', style: TextStyle(fontSize: 12, color: Colors.white70)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _PollutantPill(label: 'PM2.5', value: '21 µg/m³'),
                        _PollutantPill(label: 'PM10', value: '38 µg/m³'),
                        _PollutantPill(label: 'O₃', value: '28 µg/m³'),
                        _PollutantPill(label: 'NO₂', value: '14 ppb'),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Report Waste & Civic Hazards ──────────────────────────────
              Text(
                'Citizen Waste & Hazard Reporter',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.royalForest,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Help keep your neighborhood clean. Reports route directly to municipal clean-up squads.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),

              const SizedBox(height: 18),

              // Incident Type
              const Text('Incident / Waste Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedWasteType,
                items: _wasteTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 14)))).toList(),
                onChanged: (v) => setState(() => _selectedWasteType = v!),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.delete_sweep_outlined, color: AppColors.champagneGold),
                ),
              ),

              const SizedBox(height: 16),

              // Location Geotag
              const Text('Geotagged Location', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.my_location_rounded, color: AppColors.emerald, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.appState.baseline.cityWard,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Text('GPS Lock', style: TextStyle(fontSize: 11, color: AppColors.emerald, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Photo Attachment Stub
              const Text('Evidence Photo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => setState(() => _photoAttached = !_photoAttached),
                child: Container(
                  height: 100,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _photoAttached ? AppColors.emerald : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                      width: _photoAttached ? 1.5 : 1.0,
                    ),
                  ),
                  child: _photoAttached
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_rounded, color: AppColors.emerald, size: 24),
                            SizedBox(width: 8),
                            Text('1 Photo Attached (Tap to remove)', style: TextStyle(color: AppColors.emerald, fontWeight: FontWeight.w600)),
                          ],
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt_outlined, color: AppColors.champagneGold, size: 28),
                            SizedBox(height: 6),
                            Text('Attach Camera Photo of Waste Hotspot', style: TextStyle(fontSize: 13, color: Colors.grey)),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Description
              const Text('Description (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _descController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'e.g. Near Majiwada flyover construction zone, large pile of unsegregated plastic.',
                ),
              ),

              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmitReport,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: AppColors.champagneGold, strokeWidth: 2.5),
                        )
                      : const Text('Dispatch Municipal Report (+50 Points)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _PollutantPill extends StatelessWidget {
  final String label;
  final String value;

  const _PollutantPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
