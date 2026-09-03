import 'package:flutter/material.dart';

/// Curated Royal Forest & Champagne Gold Color Palette for Grevidea
class AppColors {
  // ─── Core Brand Tokens ─────────────────────────────────────────────
  static const Color royalForest = Color(0xFF06261A);      // Primary dark container & nav
  static const Color deepForest = Color(0xFF031911);       // Darkest green / surfaces
  static const Color midnightObsidian = Color(0xFF05100B);  // Dark mode canvas
  
  // ─── Metallics & Accents ───────────────────────────────────────────
  static const Color champagneGold = Color(0xFFD4AF37);    // Polished gold primary
  static const Color goldLight = Color(0xFFE5C77A);        // Luminous champagne highlight
  static const Color polishedBrass = Color(0xFFB8860B);    // Deeper antique gold tone
  static const Color goldBorder = Color(0x33D4AF37);       // Subtle 20% gold border

  // ─── Light Mode Tokens ─────────────────────────────────────────────
  static const Color lightCanvas = Color(0xFFF8F6F0);       // Warm editorial ivory/cream
  static const Color lightSurface = Color(0xFFFFFFFF);      // Crisp pure white card
  static const Color lightSurfaceAlt = Color(0xFFF0ECE1);   // Light warm beige
  static const Color lightTextPrimary = Color(0xFF14241D);  // Deep forest charcoal
  static const Color lightTextSecondary = Color(0xFF5A6E64);// Muted sage grey
  static const Color lightCardBorder = Color(0xFFE5DFD1);   // Delicate cream border

  // ─── Dark Mode Tokens ──────────────────────────────────────────────
  static const Color darkCanvas = Color(0xFF05100B);        // Deep velvet forest obsidian
  static const Color darkSurface = Color(0xFF0C1D16);       // Elevated card surface
  static const Color darkSurfaceAlt = Color(0xFF122A20);    // Hover / secondary card surface
  static const Color darkTextPrimary = Color(0xFFF3F7F4);   // Soft pearl white
  static const Color darkTextSecondary = Color(0xFF8BA599); // Luminous sage
  static const Color darkCardBorder = Color(0x2BD4AF37);    // Glowing subtle gold border

  // ─── Functional Semantic Colors ────────────────────────────────────
  static const Color emerald = Color(0xFF10B981);           // Success / Good AQI
  static const Color amber = Color(0xFFF59E0B);             // Moderate / Warning
  static const Color coral = Color(0xFFEF4444);             // High impact / Hazard
  static const Color sapphire = Color(0xFF3B82F6);          // Informational / Energy
}
