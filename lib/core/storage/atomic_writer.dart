import 'dart:async';

class AtomicWriter {
  static final AtomicWriter instance = AtomicWriter._internal();

  AtomicWriter._internal();

  Future<void>? _tail;
  static final _zoneKey = Object();

  /// Enqueues a transaction action and executes it sequentially under a strict
  /// FIFO mutex lock without leaking Zone-bound futures across completed batches.
  /// Supports reentrancy: if already in an AtomicWriter zone, runs immediately.
  Future<T> execute<T>(Future<T> Function() action) async {
    // Check if we are already in an AtomicWriter zone
    if (Zone.current[_zoneKey] == true) {
      return action();
    }

    final prev = _tail;
    final gate = Completer<void>();
    _tail = gate.future;

    if (prev != null) {
      await prev;
    }

    try {
      return await runZoned(action, zoneValues: {_zoneKey: true});
    } finally {
      gate.complete();
      if (identical(_tail, gate.future)) {
        _tail = null;
      }
    }
  }
}
