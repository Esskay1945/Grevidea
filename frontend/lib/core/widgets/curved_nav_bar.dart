import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CurvedNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onCenterCrestTap;

  const CurvedNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.onCenterCrestTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    // Android 3-button safe offset
    final double safeBottomOffset = bottomPadding > 20 ? bottomPadding : 12.0;

    return Container(
      height: 76.0 + safeBottomOffset,
      padding: EdgeInsets.only(bottom: safeBottomOffset),
      decoration: BoxDecoration(
        color: AppColors.royalForest,
        border: const Border(
          top: BorderSide(color: AppColors.goldBorder, width: 1.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 0: Overview (Home)
          _NavItem(
            icon: Icons.home_rounded,
            label: 'Home',
            isSelected: currentIndex == 0,
            onTap: () => onTabSelected(0),
          ),

          // 1: Tracker (Footprint)
          _NavItem(
            icon: Icons.pie_chart_outline_rounded,
            label: 'Tracker',
            isSelected: currentIndex == 1,
            onTap: () => onTabSelected(1),
          ),

          // 2: Center Elevated Champagne Gold Botanical Crest
          GestureDetector(
            onTap: onCenterCrestTap,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [
                    AppColors.goldLight,
                    AppColors.champagneGold,
                    AppColors.polishedBrass,
                  ],
                  stops: [0.0, 0.6, 1.0],
                ),
                border: Border.all(color: AppColors.royalForest, width: 3.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.champagneGold.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.eco_rounded,
                color: AppColors.royalForest,
                size: 30,
              ),
            ),
          ),

          // 3: Civic & Climate (AQI, Waste, Community)
          _NavItem(
            icon: Icons.public_rounded,
            label: 'Civic',
            isSelected: currentIndex == 3,
            onTap: () => onTabSelected(3),
          ),

          // 4: Profile & Settings
          _NavItem(
            icon: Icons.person_outline_rounded,
            label: 'Profile',
            isSelected: currentIndex == 4,
            onTap: () => onTabSelected(4),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? AppColors.champagneGold : Colors.white.withOpacity(0.6),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppColors.champagneGold : Colors.white.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
