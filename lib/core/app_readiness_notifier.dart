import 'package:flutter/foundation.dart';

class AppReadinessNotifier extends ChangeNotifier {
  bool _isReady = false;

  bool get isReady => _isReady;

  void markReady() {
    if (!_isReady) {
      _isReady = true;
      notifyListeners();
    }
  }
}
