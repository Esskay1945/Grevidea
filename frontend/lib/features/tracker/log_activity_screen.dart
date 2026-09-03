import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/grevidea_app_bar.dart';
import '../../core/widgets/feature_directory_drawer.dart';
import '../../state/app_state.dart';

class LogActivityScreen extends StatefulWidget {
  final AppState appState;
  const LogActivityScreen({super.key, required this.appState});

  @override
  State<LogActivityScreen> createState() => _LogActivityScreenState();
}

class _LogActivityScreenState extends State<LogActivityScreen> {
  void _openAddActivityModal() {
    String selectedCategory = 'Transport';
    String selectedMode = 'Metro';
    double amount = 10.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Log Environmental Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Category Selector
                  Row(
                    children: ['Transport', 'Energy', 'Food', 'Waste'].map((cat) {
                      final isSel = selectedCategory == cat;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: ChoiceChip(
                            label: Text(cat, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSel ? AppColors.champagneGold : null)),
                            selected: isSel,
                            selectedColor: AppColors.royalForest,
                            onSelected: (val) {
                              if (val) {
                                setModalState(() {
                                  selectedCategory = cat;
                                  if (cat == 'Transport') selectedMode = 'Metro';
                                  if (cat == 'Energy') selectedMode = 'Electricity (kWh)';
                                  if (cat == 'Food') selectedMode = 'Plant-based Meal';
                                  if (cat == 'Waste') selectedMode = 'Dry Recyclables (kg)';
                                });
                              }
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Quantity Slider
                  Text(
                    selectedCategory == 'Transport'
                        ? 'Distance: ${amount.toStringAsFixed(1)} km'
                        : (selectedCategory == 'Energy'
                            ? 'Electricity: ${amount.toStringAsFixed(1)} kWh'
                            : (selectedCategory == 'Food'
                                ? 'Meals: ${amount.toInt()} plant-based meals'
                                : 'Waste Recycled: ${amount.toStringAsFixed(1)} kg')),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  Slider(
                    value: amount,
                    min: 1.0,
                    max: 50.0,
                    activeColor: AppColors.emerald,
                    inactiveColor: Colors.grey.shade300,
                    onChanged: (val) => setModalState(() => amount = val),
                  ),

                  // Calculated Impact Preview
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.royalForest.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.emerald.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Estimated Emission:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Text(
                          selectedCategory == 'Transport'
                              ? '${(amount * 0.035).toStringAsFixed(2)} kg CO₂'
                              : (selectedCategory == 'Energy'
                                  ? '${(amount * 0.82).toStringAsFixed(2)} kg CO₂'
                                  : (selectedCategory == 'Food'
                                      ? '${(amount * 0.3).toStringAsFixed(2)} kg CO₂'
                                      : '-${(amount * 0.5).toStringAsFixed(2)} kg CO₂ Saved')),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.emerald),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        widget.appState.logActivity(
                          title: '$selectedMode Log',
                          category: selectedCategory,
                          subtitle: '${amount.toStringAsFixed(1)} units logged',
                          co2Kg: selectedCategory == 'Waste' ? -amount * 0.5 : amount * 0.08,
                          icon: selectedCategory == 'Transport'
                              ? Icons.directions_subway_rounded
                              : (selectedCategory == 'Energy' ? Icons.bolt_rounded : Icons.eco_rounded),
                          pointsEarned: 20,
                        );
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: AppColors.royalForest,
                            content: Text('✓ Activity logged successfully! +20 Points added.', style: TextStyle(color: AppColors.champagneGold)),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.royalForest,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Confirm & Log Activity (+20 pts)', style: TextStyle(color: AppColors.champagneGold, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkCanvas : AppColors.lightCanvas;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    final activities = widget.appState.recentActivities;

    return Scaffold(
      backgroundColor: bg,
      drawer: FeatureDirectoryDrawer(appState: widget.appState),
      appBar: GrevideaAppBar(
        title: 'Log Activity',
        subtitle: 'Daily Eco-Behavior Record',
        showBack: Navigator.of(context).canPop(),
        appState: widget.appState,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _openAddActivityModal,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                '+ Add Activity',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.royalForest,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section Title (Matching Screen 07)
          Text(
            'Recent Activities',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textColor),
          ),
          const SizedBox(height: 12),

          // Activity Cards List (Matching items in Screen 07)
          ...activities.map((act) => _buildActivityTile(act, cardBg, textColor, isDark)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildActivityTile(ActivityLogItem item, Color cardBg, Color textColor, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.royalForest.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: AppColors.emerald, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
              ],
            ),
          ),
          Text(
            item.co2Kg < 0
                ? '${item.co2Kg.abs().toStringAsFixed(1)} kg saved'
                : '${item.co2Kg.toStringAsFixed(1)} kg CO₂',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: item.co2Kg < 0 ? AppColors.emerald : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
