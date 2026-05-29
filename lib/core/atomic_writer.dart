import 'dart:async';

class AtomicWriter {
  static final AtomicWriter instance = AtomicWriter._internal();

  AtomicWriter._internal();

  Future<void> _queue = Future.value();
  static final _zoneKey = Object();

  /// Enqueues a transaction action and executes it sequentially.
  /// Supports reentrancy: if already in an atomic execution, runs immediately.
  Future<T> execute<T>(Future<T> Function() action) {
    // Check if we are already in an AtomicWriter zone
    if (Zone.current[_zoneKey] == true) {
      return action();
    }

    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      await runZoned(() async {
        try {
          final result = await action();
          completer.complete(result);
        } catch (e, stackTrace) {
          completer.completeError(e, stackTrace);
        }
      }, zoneValues: {_zoneKey: true});
    });
    return completer.future;
  }
}
