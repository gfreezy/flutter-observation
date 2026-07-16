import 'dart:collection';

import 'callbacks.dart';
import 'observer.dart';

/// Coalesces observation invalidations produced by a group of mutations.
abstract final class ObservationTransaction {
  static int _depth = 0;
  static final LinkedHashSet<ObservationObserver> _pending = LinkedHashSet();

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

  static void invalidate(ObservationObserver observer) {
    if (_depth > 0) {
      _pending.add(observer);
    } else {
      observer.invalidate();
    }
  }

  static void _flush() {
    while (_pending.isNotEmpty) {
      final observers = List<ObservationObserver>.of(_pending);
      _pending.clear();
      runObservationCallbacks(observers.map((observer) => observer.invalidate));
    }
  }
}

/// Runs [body] as one observation transaction.
T observationTransaction<T>(T Function() body) =>
    ObservationTransaction.run(body);
