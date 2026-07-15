import 'observer.dart';

/// Holds the observer associated with the currently executing synchronous
/// tracking scope.
abstract final class ReactiveTracking {
  static ReactiveObserver? _currentObserver;

  /// The observer receiving reads in the current synchronous tracking scope.
  static ReactiveObserver? get currentObserver => _currentObserver;

  /// Runs [body] while reads are attributed to [observer].
  ///
  /// Tracking is synchronous. Reads performed after an `await` are not part of
  /// this scope.
  static T track<T>(ReactiveObserver observer, T Function() body) {
    final previous = _currentObserver;
    _currentObserver = observer;
    try {
      return body();
    } finally {
      _currentObserver = previous;
    }
  }
}
