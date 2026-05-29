import 'package:flutter/material.dart';

abstract final class AppCurves {
  static const Curve standard = Curves.easeInOutCubic;   // Symmetric transitions
  static const Curve decelerate = Curves.easeOutCubic;   // Entering elements
  static const Curve accelerate = Curves.easeInCubic;    // Leaving elements
  static const Curve spring = Curves.easeOutBack;        // Bottom sheet overshoot
}
