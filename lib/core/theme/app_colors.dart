import 'package:flutter/material.dart';

/// Apple Cupertino Design System Tokens for Fatoura.
/// Refined dimensions, restrained neutral palette, and premium minimalism.
class AppColors {
  AppColors._();

  // Brand Palette - Light
  static const Color primary = Color(0xFF007AFF); // Cupertino System Blue
  static const Color primaryMuted = Color(0xFF4778C7);
  static const Color secondary = Color(0xFF5856D6); // Cupertino Indigo
  static const Color primaryLight = primary;

  // Backgrounds & Surfaces - Light
  static const Color lightBackground = Color(
    0xFFF5F5F7,
  ); // Apple Grouped Background
  static const Color lightSurface = Color(
    0xFFFFFFFF,
  ); // Pure white cards/containers
  static const Color lightSurfaceSubtle = Color(
    0xFFF0F0F2,
  ); // Inset controls, filled inputs
  static const Color lightBorder = Color(
    0xFFD2D2D7,
  ); // Cupertino separator hairline
  static const Color borderLight = lightBorder;

  // Backgrounds & Surfaces - Dark
  static const Color darkBackground = Color(
    0xFF151516,
  ); // Cupertino Dark grouped bg
  static const Color darkSurface = Color(
    0xFF1C1C1E,
  ); // Apple dark secondary grouped bg
  static const Color darkSurfaceSubtle = Color(
    0xFF28282A,
  ); // Inset controls dark
  static const Color darkBorder = Color(0xFF38383A); // Cupertino dark separator

  // Aliases for clean cross-theme references
  static const Color surfaceSubtle = lightSurfaceSubtle;
  static const Color surfaceSubtleDark = darkSurfaceSubtle;

  // Text Tokens - Light
  static const Color textPrimaryLight = Color(
    0xFF1D1D1F,
  ); // Apple high-contrast text
  static const Color textSecondaryLight = Color(
    0xFF6E6E73,
  ); // Apple secondary text
  static const Color textTertiaryLight = Color(0xFF86868B);

  // Text Tokens - Dark
  static const Color textPrimaryDark = Color(0xFFF5F5F7);
  static const Color textSecondaryDark = Color(0xFFA1A1A6);
  static const Color textTertiaryDark = Color(0xFF636366);

  // Semantic Indicators (Restrained & Calm)
  static const Color success = Color(0xFF34C759); // Apple system green
  static const Color successMuted = Color(0xFF39845A);
  static const Color successBackground = Color(0xFFEBF5F0);
  static const Color successBackgroundDark = Color(0xFF1B2E23);

  static const Color error = Color(0xFFFF3B30); // Apple system red
  static const Color errorMuted = Color(0xFFC44747);
  static const Color errorBackground = Color(0xFFFDF2F2);
  static const Color errorBackgroundDark = Color(0xFF301B1B);

  static const Color warning = Color(0xFFFF9500); // Apple system orange
  static const Color warningMuted = Color(0xFFA87524);
  static const Color warningBackground = Color(0xFFFDF6EC);
  static const Color warningBackgroundDark = Color(0xFF312513);

  static const Color info = Color(0xFF007AFF);
  static const Color infoBackground = Color(0xFFEFF6FF);
  static const Color infoBackgroundDark = Color(0xFF14243B);
}

/// 4-point spacing scale as specified in Apple Cupertino guidelines.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
}

/// Cupertino-inspired radius and element dimensions.
class AppDimensions {
  AppDimensions._();

  // Radius Hierarchy
  static const double radiusSmall = 8.0; // Badges, tags, chips
  static const double radiusMedium = 12.0; // Text fields, buttons, dropdowns
  static const double radiusControl =
      12.0; // Inset form controls, inputs, buttons
  static const double radiusCard = 16.0; // Cards, grouped panels, containers
  static const double radiusLarge = 16.0; // Backward-compatibility
  static const double radiusSheet = 20.0; // Bottom sheets, dialogs, modals
  static const double radiusPill = 20.0; // Cupertino status pills and badges

  // Padding
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;

  // Interactive Target Heights (Apple standard >= 44pt)
  static const double buttonHeight = 48.0;
  static const double inputHeight = 48.0;
}
