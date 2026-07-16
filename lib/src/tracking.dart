import 'observer.dart';

/// Holds the observer associated with the currently executing synchronous
/// tracking scope.
abstract final class ObservationTracking {
  static ObservationObserver? _currentObserver;

  /// The observer receiving reads in the current synchronous tracking scope.
  static ObservationObserver? get currentObserver => _currentObserver;

  /// Runs [body] while reads are attributed to [observer].
  ///
  /// Tracking is synchronous. Reads performed after an `await` are not part of
  /// this scope.
  static T track<T>(ObservationObserver observer, T Function() body) {
    final previous = _currentObserver;
    _currentObserver = observer;
    try {
      return body();
    } finally {
      _currentObserver = previous;
    }
  }
}
