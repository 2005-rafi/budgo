import 'package:flutter/material.dart';

/// Unified Material 3 Expressive motion, duration, and curve tokens.
abstract final class AppMotion {
  static const Duration instant = Duration.zero;
  static const Duration micro = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 220);
  static const Duration enter = Duration(milliseconds: 280);
  static const Duration exit = Duration(milliseconds: 200);
  static const Duration expressive = Duration(milliseconds: 380);
  static const Duration loading = Duration(milliseconds: 600);

  // Semantic curve tokens
  static const Curve curveEnter = Curves.easeOutCubic;
  static const Curve curveExit = Curves.easeIn;
  static const Curve curveStandard = Curves.easeInOutCubic;
  static const Curve curveExpressive = Curves.easeOutBack;
  static const Curve curveSpring = Curves.elasticOut;

  // Backwards compatibility aliases for AppDurations references
  static const Duration normal = standard;
  static const Duration slow = expressive;
  static const Duration verySlow = loading;
}

