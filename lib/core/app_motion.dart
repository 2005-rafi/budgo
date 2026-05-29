import 'package:flutter/material.dart';

abstract final class AppMotion {
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 220);
  static const Duration enter = Duration(milliseconds: 280);
  static const Duration exit = Duration(milliseconds: 200);

  static const Curve curveEnter = Curves.easeOut;
  static const Curve curveExit = Curves.easeIn;
  static const Curve curveStandard = Curves.easeInOut;
  static const Curve curveSpring = Curves.elasticOut;
}
