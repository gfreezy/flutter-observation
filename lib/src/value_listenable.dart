import 'package:flutter/foundation.dart';

import 'subscription.dart';

/// Adapts a derived observation value to Flutter's [ValueListenable] API.
///
/// The adapter owns a continuous observation subscription and must be disposed
/// when it is no longer used.
final class ObservationValueListenable<T> extends ChangeNotifier
    implements ValueListenable<T> {
  ObservationValueListenable(
    this.read, {
    this.notifyOnEqual = false,
    ObservationScheduler scheduler = ObservationSchedulers.microtask,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) {
    _subscription = observe(
      read,
      onChange: _handleChange,
      onError: onError,
      scheduler: scheduler,
    );
    _lastValue = _subscription.value;
  }

  /// Reads the current projected value from its observable source.
  final T Function() read;

  /// Whether dependency invalidations notify listeners when the derived value
  /// still compares equal to its previous value.
  final bool notifyOnEqual;

  late final ObservationSubscription<T> _subscription;
  late T _lastValue;

  @override
  T get value => read();

  void _handleChange(T value) {
    final changed = notifyOnEqual || _lastValue != value;
    _lastValue = value;
    if (changed) notifyListeners();
  }

  @override
  void dispose() {
    _subscription.dispose();
    super.dispose();
  }
}

/// Creates a disposable [ValueListenable] projection of observed properties.
ObservationValueListenable<T> toValueListenable<T>(
  T Function() read, {
  bool notifyOnEqual = false,
  ObservationScheduler scheduler = ObservationSchedulers.microtask,
  void Function(Object error, StackTrace stackTrace)? onError,
}) {
  return ObservationValueListenable<T>(
    read,
    notifyOnEqual: notifyOnEqual,
    scheduler: scheduler,
    onError: onError,
  );
}
