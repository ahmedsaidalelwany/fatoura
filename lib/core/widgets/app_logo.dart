import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';

/// Reusable AppLogo widget that renders the transparent official app logo (`app_logo.png`)
/// directly on top of the active background without any artificial container.
///
/// Supports optional App Name display underneath with adaptive typography for
/// both Light Mode (#0F172A) and Dark Mode (#FFFFFF).
class AppLogo extends StatelessWidget {
  /// Base size (used for both width and height unless overridden).
  final double size;

  /// Optional explicit width override.
  final double? width;

  /// Optional explicit height override.
  final double? height;

  /// Image fit for the logo asset. Defaults to [BoxFit.contain].
  final BoxFit fit;

  /// Whether to display the App Name underneath the logo.
  final bool showAppName;

  /// Custom app name string. If null, uses localized name from [AppLocalizations].
  final String? appName;

  /// Custom typography style for the app name.
  final TextStyle? appNameStyle;

  /// Spacing between the logo and the app name when [showAppName] is true.
  final double spacing;

  /// Optional subtitle or tagline displayed beneath the app name.
  final String? subtitle;

  /// Optional custom style for the subtitle.
  final TextStyle? subtitleStyle;

  /// Asset path for the logo. Defaults to `'assets/images/app_logo.png'`.
  final String assetPath;

  const AppLogo({
    super.key,
    this.size = 64.0,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.showAppName = false,
    this.appName,
    this.appNameStyle,
    this.spacing = 12.0,
    this.subtitle,
    this.subtitleStyle,
    this.assetPath = 'assets/images/app_logo.png',
  });

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = width ?? size;
    final effectiveHeight = height ?? size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final logoImage = Image.asset(
      assetPath,
      width: effectiveWidth,
      height: effectiveHeight,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return SizedBox(
          width: effectiveWidth,
          height: effectiveHeight,
          child: Icon(
            Icons.receipt_long_rounded,
            size: effectiveWidth * 0.7,
            color: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A),
          ),
        );
      },
    );

    if (!showAppName && subtitle == null) {
      return logoImage;
    }

    final l10n = AppLocalizations.of(context);
    final effectiveAppName = appName ?? l10n.appName;

    final defaultTextColor = isDark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF0F172A);

    final resolvedTextStyle = (appNameStyle ??
            TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
              color: defaultTextColor,
            ))
        .copyWith(
      color: appNameStyle?.color ?? defaultTextColor,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        logoImage,
        if (showAppName) ...[
          SizedBox(height: spacing),
          Text(
            effectiveAppName,
            textAlign: TextAlign.center,
            style: resolvedTextStyle,
          ),
        ],
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: subtitleStyle ??
                TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
          ),
        ],
      ],
    );
  }
}
