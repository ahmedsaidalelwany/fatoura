import 'package:flutter/material.dart';

/// Central brand tokens as specified in Fatoura requirements.
class AppColors {
  AppColors._();

  // Brand Palette
  static const Color primary = Color(0xFF2563EB); // #2563EB
  static const Color secondary = Color(0xFF3B82F6); // #3B82F6
  static const Color lightBackground = Color(0xFFF1F5F9); // Light neutral bg
  static const Color lightSurface = Color(0xFFFFFFFF); // Pure white cards
  static const Color lightSurfaceSubtle = Color(0xFFF8FAFC);
  static const Color lightBorder = Color(0xFFE2E8F0);

  // Dark Palette
  static const Color darkBackground = Color(0xFF0B1220); // #0B1220
  static const Color darkSurface = Color(0xFF1E293B); // #1E293B
  static const Color darkSurfaceSubtle = Color(0xFF172033);
  static const Color darkBorder = Color(0xFF334155);

  // Text Tokens
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  // Semantic Indicators
  static const Color success = Color(0xFF10B981); // Paid, positive
  static const Color successBackground = Color(0xFFECFDF5);
  static const Color error = Color(0xFFEF4444); // Failures, overdue, cancel
  static const Color errorBackground = Color(0xFFFEF2F2);
  static const Color warning = Color(0xFFF59E0B); // Pending, caution
  static const Color warningBackground = Color(0xFFFFFBEB);
  static const Color info = Color(0xFF0284C7);
  static const Color infoBackground = Color(0xFFF0F9FF);
}

class AppDimensions {
  AppDimensions._();

  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;

  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;

  static const double buttonHeight = 48.0;
  static const double inputHeight = 50.0;
}
