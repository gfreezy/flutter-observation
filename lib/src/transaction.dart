import 'dart:collection';

import 'observer.dart';

/// Coalesces observation invalidations produced by a group of mutations.
abstract final class ObservationTransaction {
  static int _depth = 0;
  static final LinkedHashSet<ReactiveObserver> _pending = LinkedHashSet();

  /// Runs [body] as one observation transaction.
  ///
  /// An observer invalidated by several properties during the transaction is
  /// invalidated once when the outermost transaction completes.
  static T run<T>(T Function() body) {
    _depth++;
    try {
      return body();
    } finally {
      _depth--;
      if (_depth == 0) _flush();
    }
  }

  static void invalidate(ReactiveObserver observer) {
    if (_depth > 0) {
      _pending.add(observer);
    } else {
      observer.invalidate();
    }
  }

  static void _flush() {
    while (_pending.isNotEmpty) {
      final observers = List<ReactiveObserver>.of(_pending);
      _pending.clear();
      for (final observer in observers) {
        observer.invalidate();
      }
    }
  }
}

/// Runs [body] as one observation transaction.
T observationTransaction<T>(T Function() body) =>
    ObservationTransaction.run(body);
