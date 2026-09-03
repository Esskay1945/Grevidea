import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/responsive_wrapper.dart';
import '../../core/widgets/gold_sparkline.dart';
import '../../state/app_state.dart';

class TrackerScreen extends StatefulWidget {
  final AppState appState;

  const TrackerScreen({super.key, required this.appState});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  int _selectedPeriod = 0; // 0: Day, 1: Week, 2: Month, 3: Year

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carbon Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined, color: AppColors.champagneGold),
            onPressed: () {},
          ),
        ],
      ),
      body: ResponsiveWrapper(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Period Selector Tabs
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                ),
                child: Row(
                  children: ['Day', 'Week', 'Month', 'Year'].asMap().entries.map((entry) {
                    final isSelected = _selectedPeriod == entry.key;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedPeriod = entry.key),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.royalForest : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: isSelected ? Border.all(color: AppColors.champagneGold, width: 1) : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            entry.value,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? AppColors.champagneGold : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 20),

              // Total CO2 Summary Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: AppColors.royalForest,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.goldBorder, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total CO₂ Footprint',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.champagneGold,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.emerald.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '↓ 18% vs avg',
                            style: TextStyle(fontSize: 11, color: AppColors.emerald, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '12.4',
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'kg CO₂ today',
                          style: TextStyle(fontSize: 14, color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const GoldSparkline(
                      data: [18.2, 16.5, 14.8, 15.2, 13.9, 12.8, 12.4],
                      height: 36,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Category Breakdown Bars
              Text(
                'Emissions by Category',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.royalForest,
                ),
              ),
              const SizedBox(height: 12),

              _CategoryProgressRow(
                icon: Icons.directions_car_outlined,
                category: 'Transport & Commute',
                kg: '5.2 kg',
                percentage: 0.42,
                color: AppColors.champagneGold,
              ),
              _CategoryProgressRow(
                icon: Icons.bolt_outlined,
                category: 'Household Energy',
                kg: '3.5 kg',
                percentage: 0.28,
                color: AppColors.emerald,
              ),
              _CategoryProgressRow(
                icon: Icons.restaurant_outlined,
                category: 'Food & Groceries',
                kg: '2.0 kg',
                percentage: 0.16,
                color: AppColors.amber,
              ),
              _CategoryProgressRow(
                icon: Icons.delete_outline_rounded,
                category: 'Waste & Packaging',
                kg: '1.0 kg',
                percentage: 0.08,
                color: AppColors.coral,
              ),

              const SizedBox(height: 24),

              // Green Commute Route Comparator Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.alt_route_rounded, color: AppColors.champagneGold, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Route Carbon Comparator',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Thane West → Bandra Kurla Complex (BKC)',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const Divider(height: 24),
                    const _CommuteOptionRow(mode: 'Metro Route 4+2', time: '42 min', co2: '0.4 kg', cost: '₹40', isRecommended: true),
                    const SizedBox(height: 10),
                    const _CommuteOptionRow(mode: 'Electric AC Bus', time: '1 hr 10m', co2: '1.1 kg', cost: '₹45', isRecommended: false),
                    const SizedBox(height: 10),
                    const _CommuteOptionRow(mode: 'Private Petrol Car', time: '55 min', co2: '4.8 kg', cost: '₹220', isRecommended: false),
                  ],
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

class _CategoryProgressRow extends StatelessWidget {
  final IconData icon;
  final String category;
  final String kg;
  final double percentage;
  final Color color;

  const _CategoryProgressRow({
    required this.icon,
    required this.category,
    required this.kg,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 8),
                  Text(category, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              Text(kg, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 6,
              backgroundColor: Colors.grey.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommuteOptionRow extends StatelessWidget {
  final String mode;
  final String time;
  final String co2;
  final String cost;
  final bool isRecommended;

  const _CommuteOptionRow({
    required this.mode,
    required this.time,
    required this.co2,
    required this.cost,
    required this.isRecommended,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isRecommended ? AppColors.royalForest.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isRecommended ? Border.all(color: AppColors.champagneGold, width: 1) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(mode, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              Text('$time • $cost', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          Text(
            co2,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isRecommended ? AppColors.emerald : AppColors.coral,
            ),
          ),
        ],
      ),
    );
  }
}
