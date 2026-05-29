abstract final class AppDurations {
  static const Duration instant = Duration.zero;
  static const Duration micro = Duration(milliseconds: 100);      // Tap press feedback
  static const Duration fast = Duration(milliseconds: 150);       // Chip toggle, list item appear
  static const Duration standard = Duration(milliseconds: 250);   // Card transitions, AnimatedSwitcher
  static const Duration expressive = Duration(milliseconds: 400); // Screen transitions, sheets
  static const Duration loading = Duration(milliseconds: 600);    // Shimmer shimmer to loading

  // Backwards compatibility mappings
  static const Duration normal = standard;
  static const Duration slow = expressive;
  static const Duration verySlow = loading;
}
