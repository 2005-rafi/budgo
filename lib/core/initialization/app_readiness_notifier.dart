import 'package:flutter/foundation.dart';

enum BootStatus { booting, ready, failed }

/// Tracks phased cold-start bootstrap state, plain-language status updates,
/// non-fatal OS warnings, and recoverable startup failure telemetry.
class AppReadinessNotifier extends ChangeNotifier {
  BootStatus _status = BootStatus.booting;
  double _progress = 0.05;
  String _statusMessage = 'Warming up your workspace';
  String? _errorTitle;
  String? _errorGuidance;
  bool _isRetrying = false;
  final List<String> _nonFatalWarnings = [];
  Future<void> Function()? _onRetry;

  BootStatus get status => _status;
  double get progress => _progress;
  String get statusMessage => _statusMessage;
  String? get errorTitle => _errorTitle;
  String? get errorGuidance => _errorGuidance;
  bool get isRetrying => _isRetrying;
  List<String> get nonFatalWarnings => List.unmodifiable(_nonFatalWarnings);

  bool get isReady => _status == BootStatus.ready;
  bool get hasFailed => _status == BootStatus.failed;

  void attachRetryCallback(Future<void> Function() callback) {
    _onRetry = callback;
  }

  Future<void> retry() async {
    resetForRetry();
    if (_onRetry != null) {
      await _onRetry!.call();
    }
  }

  void updateProgress(double value, String message) {
    if (_status == BootStatus.ready) return;
    _status = BootStatus.booting;
    _progress = value.clamp(0.0, 1.0);
    _statusMessage = message;
    _isRetrying = false;
    notifyListeners();
  }

  void addWarning(String warning) {
    _nonFatalWarnings.add(warning);
    notifyListeners();
  }

  void markFailed({
    required String title,
    required String guidance,
  }) {
    _status = BootStatus.failed;
    _errorTitle = title;
    _errorGuidance = guidance;
    _isRetrying = false;
    notifyListeners();
  }

  void resetForRetry() {
    _status = BootStatus.booting;
    _progress = 0.05;
    _statusMessage = 'Reconnecting your workspace';
    _errorTitle = null;
    _errorGuidance = null;
    _isRetrying = true;
    _nonFatalWarnings.clear();
    notifyListeners();
  }

  void markReady() {
    _status = BootStatus.ready;
    _progress = 1.0;
    _statusMessage = 'Your financial assistant is ready';
    _errorTitle = null;
    _errorGuidance = null;
    _isRetrying = false;
    notifyListeners();
  }
}
