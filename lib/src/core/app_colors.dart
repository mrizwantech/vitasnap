import 'package:flutter/material.dart';

/// App-wide color constants for consistent theming.
///
/// Centralizes all color definitions for easier maintenance
/// and consistency across the app.
class AppColors {
  AppColors._();

  // ==================== Brand Colors ====================
  /// Primary brand green - used for main actions, headers, buttons
  static const Color primaryGreen = Color(0xFF1B8A4E);

  /// Accent green - used for logo, highlights, success states
  static const Color accentGreen = Color(0xFF00C17B);

  /// Light background - used for scaffold backgrounds
  static const Color backgroundLight = Color(0xFFF6FBF8);

  // ==================== Status Colors ====================
  /// Success/positive color
  static const Color success = Color(0xFF4CAF50);

  /// Warning color
  static const Color warning = Color(0xFFFFC107);

  /// Warning orange
  static const Color warningOrange = Color(0xFFFF9800);

  /// Error/danger color
  static const Color error = Color(0xFFE53E3E);

  /// Error red variant
  static const Color errorRed = Color(0xFFF44336);

  // ==================== Health Condition Colors ====================
  static const Color conditionPurple = Color(0xFF9C27B0);
  static const Color conditionRed = Color(0xFFE53935);
  static const Color conditionDarkRed = Color(0xFFD32F2F);
  static const Color conditionOrange = Color(0xFFFF9800);
  static const Color conditionBrown = Color(0xFF795548);
  static const Color conditionBlue = Color(0xFF2196F3);
  static const Color conditionGrey = Color(0xFF607D8B);

  // ==================== Score/Grade Colors ====================
  /// Grade A - Excellent
  static const Color gradeA = primaryGreen;

  /// Grade B - Good
  static const Color gradeB = Color(0xFF8BC34A);

  /// Grade C - Average
  static const Color gradeC = warningOrange;

  /// Grade D - Poor
  static const Color gradeD = Color(0xFFFF5722);

  /// Grade E - Bad
  static const Color gradeE = errorRed;

  // ==================== Text Colors ====================
  static const Color textPrimary = Colors.black87;
  static const Color textSecondary = Colors.black54;
  static const Color textLight = Colors.white;
}
