import 'package:flutter/foundation.dart';
import 'package:expense/models/filter_criteria.dart';

class AppNavigationProvider extends ChangeNotifier {
  int _currentIndex = 0;
  FilterCriteria? _pendingActivityCriteria;

  int get currentIndex => _currentIndex;
  FilterCriteria? get pendingActivityCriteria => _pendingActivityCriteria;

  void setIndex(int index) {
    if (_currentIndex != index) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  /// Switches to the Activity tab cleanly inside [AppShell], optionally
  /// queueing a [FilterCriteria] handoff (e.g., from Reports drill-down).
  void openActivity({FilterCriteria? criteria}) {
    _pendingActivityCriteria = criteria;
    _currentIndex = 1;
    notifyListeners();
  }

  FilterCriteria? consumePendingActivityCriteria() {
    final pending = _pendingActivityCriteria;
    _pendingActivityCriteria = null;
    return pending;
  }
}
