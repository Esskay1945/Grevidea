import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTypography {
  static const String fontFamilySans = 'Roboto'; // Standard system sans with crisp geometric fallbacks

  static TextStyle displayGold(BuildContext context, {double fontSize = 28, FontWeight fontWeight = FontWeight.w700}) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: AppColors.champagneGold,
      letterSpacing: -0.5,
    );
  }

  static TextStyle heading(BuildContext context, {double fontSize = 20, FontWeight fontWeight = FontWeight.w600, Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
      letterSpacing: -0.3,
    );
  }

  static TextStyle body(BuildContext context, {double fontSize = 14, FontWeight fontWeight = FontWeight.w400, Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
      height: 1.4,
    );
  }

  static TextStyle caption(BuildContext context, {double fontSize = 12, FontWeight fontWeight = FontWeight.w500, Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
      letterSpacing: 0.2,
    );
  }
}
