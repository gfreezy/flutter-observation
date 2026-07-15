import 'dart:async';

import 'observer.dart';
import 'registrar.dart';
import 'tracking.dart';

/// Schedules a pending observation callback.
typedef ObservationScheduler = void Function(void Function() callback);

/// Common schedulers for continuous observation.
abstract final class ObservationSchedulers {
  /// Runs the callback immediately.
  static void immediate(void Function() callback) => callback();

  /// Runs the callback in a microtask and naturally coalesces synchronous
  /// changes made before that microtask.
  static void microtask(void Function() callback) =>
      scheduleMicrotask(callback);
}

/// A cancellable, continuously retracked observation.
final class ObservationSubscription<T> implements ReactiveObserver {
  ObservationSubscription._(this._read, this._onChange, this._scheduler);

  final T Function() _read;
  final void Function(T value) _onChange;
  final ObservationScheduler _scheduler;
  final Set<ObservationRegistrar> _registrars = {};

  late T _value;
  bool _disposed = false;
  bool _scheduled = false;

  /// The value returned by the most recent tracking pass.
  T get value => _value;

  /// Whether this subscription has been cancelled.
  bool get isDisposed => _disposed;

  void _initialize({required bool fireImmediately}) {
    try {
      _value = _track();
      if (fireImmediately) _onChange(_value);
    } catch (_) {
      dispose();
      rethrow;
    }
  }

  T _track() {
    _stopObserving();
    return ReactiveTracking.track(this, _read);
  }

  @override
  void registerRegistrar(ObservationRegistrar registrar) {
    _registrars.add(registrar);
  }

  @override
  void invalidate() {
    if (_disposed || _scheduled) return;
    _scheduled = true;
    _scheduler(_refresh);
  }

  void _refresh() {
    _scheduled = false;
    if (_disposed) return;
    _value = _track();
    _onChange(_value);
  }

  /// Immediately recollects dependencies and returns the new value.
  T refresh() {
    if (_disposed) {
      throw StateError('Cannot refresh a disposed observation.');
    }
    _scheduled = false;
    _value = _track();
    return _value;
  }

  /// Cancels observation and releases all registrar references.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _scheduled = false;
    _stopObserving();
  }

  void _stopObserving() {
    for (final registrar in _registrars) {
      registrar.removeObserver(this);
    }
    _registrars.clear();
  }
}

/// Continuously observes the properties read by [read].
///
/// Dependencies are recollected before every [onChange] call. Synchronous
/// invalidations are coalesced by the default microtask scheduler.
ObservationSubscription<T> observe<T>(
  T Function() read, {
  required void Function(T value) onChange,
  bool fireImmediately = false,
  ObservationScheduler scheduler = ObservationSchedulers.microtask,
}) {
  final subscription = ObservationSubscription<T>._(read, onChange, scheduler);
  subscription._initialize(fireImmediately: fireImmediately);
  return subscription;
}

/// Tracks accesses in [apply] and invokes [onChange] on the first change.
///
/// This is the one-shot primitive used by renderers that retrack after they
/// have scheduled another render.
T withObservationTracking<T>(
  T Function() apply, {
  required void Function() onChange,
}) {
  final observer = _OneShotObserver(onChange);
  try {
    return ReactiveTracking.track(observer, apply);
  } catch (_) {
    observer.dispose();
    rethrow;
  }
}

/// Creates a single-subscription stream of values derived by [read].
Stream<T> observeStream<T>(T Function() read, {bool emitInitial = true}) {
  ObservationSubscription<T>? subscription;
  late final StreamController<T> controller;
  controller = StreamController<T>(
    onListen: () {
      try {
        subscription = observe(
          read,
          onChange: controller.add,
          fireImmediately: emitInitial,
        );
      } catch (error, stackTrace) {
        controller.addError(error, stackTrace);
        controller.close();
      }
    },
    onCancel: () {
      subscription?.dispose();
      subscription = null;
    },
  );
  return controller.stream;
}

final class _OneShotObserver implements ReactiveObserver {
  _OneShotObserver(this._onChange);

  final void Function() _onChange;
  final Set<ObservationRegistrar> _registrars = {};
  bool _fired = false;

  @override
  void registerRegistrar(ObservationRegistrar registrar) {
    _registrars.add(registrar);
  }

  @override
  void invalidate() {
    if (_fired) return;
    _fired = true;
    dispose();
    _onChange();
  }

  void dispose() {
    for (final registrar in _registrars) {
      registrar.removeObserver(this);
    }
    _registrars.clear();
  }
}
