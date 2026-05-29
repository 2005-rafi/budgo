import 'package:flutter/material.dart';
import 'app_spacing.dart';

abstract final class AppBreakpoints {
  static const double compact = 360.0;  // Small phones
  static const double standard = 400.0; // Standard size phones
  static const double expanded = 480.0; // Large phones
}

abstract final class AppLayout {
  /// Returns responsive horizontal screen padding
  static double screenPadding(BuildContext ctx) {
    final w = MediaQuery.sizeOf(ctx).width;
    if (w < AppBreakpoints.compact) return AppSpacing.base;       // 16dp
    if (w < AppBreakpoints.expanded) return AppSpacing.screenHMed; // 20dp
    return AppSpacing.screenHLarge;                                // 24dp
  }

  /// Returns the maximum content width (centers content on very wide screens)
  static double maxContentWidth(BuildContext ctx) {
    final w = MediaQuery.sizeOf(ctx).width;
    return w.clamp(0.0, 480.0); // Never wider than large phone
  }

  /// Returns card horizontal margin (screen padding applied to cards)
  static EdgeInsets cardMargin(BuildContext ctx) {
    final h = screenPadding(ctx);
    return EdgeInsets.symmetric(horizontal: h);
  }

  /// Returns insight card width (responsive)
  static double insightCardWidth(BuildContext ctx) {
    final w = MediaQuery.sizeOf(ctx).width;
    if (w < AppBreakpoints.compact) return 180.0;
    if (w < AppBreakpoints.expanded) return 200.0;
    return 220.0;
  }

  /// Returns quick action grid column count
  static int quickActionColumns(BuildContext ctx) {
    final w = MediaQuery.sizeOf(ctx).width;
    return w >= AppBreakpoints.expanded ? 4 : 2;
  }

  /// Returns whether the screen is compact (affects some layout decisions)
  static bool isCompact(BuildContext ctx) =>
      MediaQuery.sizeOf(ctx).width < AppBreakpoints.compact;

  /// Returns standard bottom padding including system insets
  static double bottomPadding(BuildContext ctx) =>
      MediaQuery.viewPaddingOf(ctx).bottom + AppSpacing.md;
}
