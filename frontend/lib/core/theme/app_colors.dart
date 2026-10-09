import 'package:flutter/material.dart';

/// Autumn palette shared by every feature, dialog, drawer and navigation row.
/// Legacy token names remain for source compatibility; no forest colors remain.
class AppColors {
  static const Color royalForest = Color(0xFFA84F2E);
  static const Color deepForest = Color(0xFF623823);
  static const Color midnightObsidian = Color(0xFF21150F);
  static const Color champagneGold = Color(0xFFFFEAD4);
  static const Color goldLight = Color(0xFFFFF5E6);
  static const Color polishedBrass = Color(0xFFC28E53);
  static const Color goldBorder = Color(0x55A84F2E);
  static const Color lightCanvas = Colors.transparent;
  static const Color lightSurface = Color(0xFAFFFAF3);
  static const Color lightSurfaceAlt = Color(0xFAF2E4D4);
  static const Color lightTextPrimary = Color(0xFF34231B);
  static const Color lightTextSecondary = Color(0xFF715747);
  static const Color lightCardBorder = Color(0x55A84F2E);
  static const Color darkCanvas = Colors.transparent;
  static const Color darkSurface = Color(0xF52B1C14);
  static const Color darkSurfaceAlt = Color(0xF536241A);
  static const Color darkTextPrimary = Color(0xFFFFEBD6);
  static const Color darkTextSecondary = Color(0xFFE0C2A5);
  static const Color darkCardBorder = Color(0x66E5AA77);
  static const Color emerald = Color(0xFF586B3A);
  static const Color amber = Color(0xFFB16A20);
  static const Color coral = Color(0xFFB8392E);
  static const Color sapphire = Color(0xFF436B87);

  static Color accentOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFF2B47F)
      : royalForest;
  static Color leafOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFC1D29B)
      : emerald;
  static Color inkOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkTextPrimary
      : lightTextPrimary;
  static Color mutedOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkTextSecondary
      : lightTextSecondary;
}
