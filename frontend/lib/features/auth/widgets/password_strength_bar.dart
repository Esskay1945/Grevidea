import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';

class PasswordStrengthBar extends StatelessWidget {
  final PasswordStrength strength;

  const PasswordStrengthBar({super.key, required this.strength});

  @override
  Widget build(BuildContext context) {
    if (strength == PasswordStrength.none) {
      return const SizedBox.shrink();
    }

    Color color;
    String label;
    int filledBars;

    switch (strength) {
      case PasswordStrength.easy:
        color = AppColors.coral;
        label = 'Easy (Minimum 8 chars needed)';
        filledBars = 1;
        break;
      case PasswordStrength.medium:
        color = AppColors.amber;
        label = 'Medium (Mix letters & numbers)';
        filledBars = 2;
        break;
      case PasswordStrength.difficult:
        color = AppColors.champagneGold;
        label = 'Difficult / Strong (Optimal protection)';
        filledBars = 3;
        break;
      case PasswordStrength.none:
        color = Colors.transparent;
        label = '';
        filledBars = 0;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(3, (index) {
              final isFilled = index < filledBars;
              return Expanded(
                child: Container(
                  height: 4.5,
                  margin: EdgeInsets.only(right: index < 2 ? 6.0 : 0.0),
                  decoration: BoxDecoration(
                    color: isFilled ? color : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: isFilled
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.3),
                              blurRadius: 4,
                            )
                          ]
                        : null,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              Text(
                '${filledBars}/3',
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
