import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Lora',
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightCanvas,
      textTheme: ThemeData(useMaterial3: true, brightness: Brightness.light)
          .textTheme
          .apply(
            fontFamily: 'Lora',
            bodyColor: AppColors.lightTextPrimary,
            displayColor: AppColors.lightTextPrimary,
          ),
      iconTheme: const IconThemeData(color: AppColors.lightTextPrimary),
      dividerColor: AppColors.lightCardBorder,
      canvasColor: AppColors.lightSurfaceAlt,
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.lightSurfaceAlt,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.lightSurfaceAlt,
      ),
      colorScheme: const ColorScheme.light(
        primary: AppColors.royalForest,
        onPrimary: AppColors.champagneGold,
        secondary: AppColors.emerald,
        surface: AppColors.lightSurface,
        surfaceContainerLowest: AppColors.lightSurface,
        surfaceContainerLow: AppColors.lightSurface,
        surfaceContainer: AppColors.lightSurfaceAlt,
        surfaceContainerHigh: AppColors.lightSurfaceAlt,
        surfaceContainerHighest: AppColors.lightSurfaceAlt,
        onSurface: AppColors.lightTextPrimary,
        onSurfaceVariant: AppColors.lightTextSecondary,
        outline: AppColors.lightCardBorder,
        error: AppColors.coral,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: AppColors.lightTextPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.royalForest,
          foregroundColor: AppColors.champagneGold,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.royalForest, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        hintStyle: TextStyle(
          color: AppColors.lightTextSecondary.withValues(alpha: 0.85),
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.lightCardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.lightCardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.royalForest,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.coral, width: 1.5),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Lora',
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkCanvas,
      textTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark)
          .textTheme
          .apply(
            fontFamily: 'Lora',
            bodyColor: AppColors.darkTextPrimary,
            displayColor: AppColors.darkTextPrimary,
          ),
      iconTheme: const IconThemeData(color: AppColors.darkTextPrimary),
      dividerColor: AppColors.darkCardBorder,
      canvasColor: AppColors.darkSurfaceAlt,
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.darkSurfaceAlt,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkSurfaceAlt,
      ),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFF2B47F),
        onPrimary: AppColors.midnightObsidian,
        secondary: Color(0xFFC1D29B),
        surface: AppColors.darkSurface,
        surfaceContainerLowest: AppColors.darkSurface,
        surfaceContainerLow: AppColors.darkSurface,
        surfaceContainer: AppColors.darkSurfaceAlt,
        surfaceContainerHigh: AppColors.darkSurfaceAlt,
        surfaceContainerHighest: AppColors.darkSurfaceAlt,
        onSurface: AppColors.darkTextPrimary,
        onSurfaceVariant: AppColors.darkTextSecondary,
        outline: AppColors.darkCardBorder,
        error: AppColors.coral,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.royalForest,
          foregroundColor: AppColors.champagneGold,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.champagneGold, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        hintStyle: TextStyle(
          color: AppColors.darkTextSecondary.withValues(alpha: 0.85),
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.darkCardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.darkCardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: const Color(0xFFF2B47F),
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.coral, width: 1.5),
        ),
      ),
    );
  }
}
