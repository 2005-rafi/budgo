import 'package:flutter/material.dart';
import 'package:expense/design/tokens/app_spacing.dart';

abstract final class AppBreakpoints {
  static const double compact = 360.0;
  static const double standard = 400.0;
  static const double expanded = 480.0;
}

abstract final class AppLayout {
  static double screenPadding(BuildContext ctx) {
    final w = MediaQuery.sizeOf(ctx).width;
    if (w < AppBreakpoints.compact) return AppSpacing.base;
    if (w < AppBreakpoints.expanded) return AppSpacing.screenHMed;
    return AppSpacing.screenHLarge;
  }

  static double maxContentWidth(BuildContext ctx) {
    final w = MediaQuery.sizeOf(ctx).width;
    return w.clamp(0.0, 480.0);
  }

  static EdgeInsets cardMargin(BuildContext ctx) {
    final h = screenPadding(ctx);
    return EdgeInsets.symmetric(horizontal: h);
  }

  static double insightCardWidth(BuildContext ctx) {
    final w = MediaQuery.sizeOf(ctx).width;
    if (w < AppBreakpoints.compact) return 180.0;
    if (w < AppBreakpoints.expanded) return 200.0;
    return 220.0;
  }

  static int quickActionColumns(BuildContext ctx) {
    final w = MediaQuery.sizeOf(ctx).width;
    return w >= AppBreakpoints.expanded ? 4 : 2;
  }

  static bool isCompact(BuildContext ctx) =>
      MediaQuery.sizeOf(ctx).width < AppBreakpoints.compact;

  static double bottomPadding(BuildContext ctx) =>
      MediaQuery.viewPaddingOf(ctx).bottom + AppSpacing.md;
}
