import 'package:flutter/material.dart';

import 'app_logo.dart';

/// Full-screen In-App Splash Screen that displays the official transparent app logo
/// directly on top of the active Scaffold background with adaptive typography and colors.
///
/// Light Mode: #FFFFFF background, #0F172A text
/// Dark Mode:  #0F172A background, #FFFFFF text
class SplashScreen extends StatelessWidget {
  /// Whether to show a subtle loading spinner at the bottom.
  final bool showProgress;

  /// Optional custom app name or title text.
  final String? appName;

  /// Optional subtitle or version string.
  final String? subtitle;

  /// Custom logo size, defaults to 140.0.
  final double logoSize;

  const SplashScreen({
    super.key,
    this.showProgress = false,
    this.appName,
    this.subtitle,
    this.logoSize = 140.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Light: #FFFFFF / #F8FAFC, Dark: #0F172A
    final backgroundColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFFFFFFF);

    // Light: #0F172A, Dark: #FFFFFF
    final appNameColor = isDark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppLogo(
                size: logoSize,
                showAppName: true,
                appName: appName,
                subtitle: subtitle,
                spacing: 20.0,
                appNameStyle: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: appNameColor,
                ),
              ),
              if (showProgress) ...[
                const SizedBox(height: 36),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
