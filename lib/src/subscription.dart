import 'dart:async';

import 'package:flutter/scheduler.dart';

import 'debug.dart';
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

  /// Runs the callback at the beginning of the next Flutter frame.
  static void frame(void Function() callback) {
    SchedulerBinding.instance.scheduleFrameCallback((_) => callback());
  }
}

/// A cancellable, continuously retracked observation.
final class ObservationSubscription<T> implements ObservationObserver {
  ObservationSubscription._(
    this._read,
    this._onChange,
    this._onError,
    this._scheduler,
  );

  final T Function() _read;
  final void Function(T value) _onChange;
  final void Function(Object error, StackTrace stackTrace)? _onError;
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
    ObservationDebug.labelObserver(this, 'ObservationSubscription<$T>');
    ObservationDebug.emit(
      kind: ObservationDebugEventKind.observationStart,
      observer: this,
    );
    try {
      return ObservationTracking.track(this, _read);
    } finally {
      ObservationDebug.emit(
        kind: ObservationDebugEventKind.observationEnd,
        observer: this,
      );
    }
  }

  @override
  void registerRegistrar(ObservationRegistrar registrar) {
    _registrars.add(registrar);
  }

  @override
  void invalidate() {
    if (_disposed || _scheduled) return;
    _scheduled = true;
    try {
      _scheduler(_refresh);
    } catch (error, stackTrace) {
      _scheduled = false;
      _handleRefreshError(error, stackTrace);
    }
  }

  void _refresh() {
    _scheduled = false;
    if (_disposed) return;
    try {
      _value = _track();
      _onChange(_value);
    } catch (error, stackTrace) {
      _handleRefreshError(error, stackTrace);
    }
  }

  void _handleRefreshError(Object error, StackTrace stackTrace) {
    dispose();
    final onError = _onError;
    if (onError != null) {
      onError(error, stackTrace);
    } else {
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Immediately recollects dependencies and returns the new value.
  T refresh() {
    if (_disposed) {
      throw StateError('Cannot refresh a disposed observation.');
    }
    _scheduled = false;
    try {
      _value = _track();
      return _value;
    } catch (_) {
      dispose();
      rethrow;
    }
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
  void Function(Object error, StackTrace stackTrace)? onError,
  bool fireImmediately = false,
  ObservationScheduler scheduler = ObservationSchedulers.microtask,
}) {
  final subscription = ObservationSubscription<T>._(
    read,
    onChange,
    onError,
    scheduler,
  );
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
  return withCancellableObservationTracking(apply, onChange: onChange).value;
}

/// Tracks accesses like [withObservationTracking] and also returns a handle
/// that can cancel the one-shot observation before a change occurs.
ObservationTrackingHandle<T> withCancellableObservationTracking<T>(
  T Function() apply, {
  required void Function() onChange,
}) {
  final observer = _OneShotObserver(onChange);
  ObservationDebug.labelObserver(observer, 'One-shot observation');
  try {
    final value = ObservationTracking.track(observer, apply);
    return ObservationTrackingHandle<T>._(value, observer);
  } catch (_) {
    observer.dispose();
    rethrow;
  }
}

/// The value and cancellation handle produced by one-shot tracking.
final class ObservationTrackingHandle<T> {
  const ObservationTrackingHandle._(this.value, this._observer);

  /// The value produced by the tracked closure.
  final T value;
  final _OneShotObserver _observer;

  /// Whether this handle is still waiting for its first invalidation.
  bool get isActive => _observer.isActive;

  /// Stops tracking if the first invalidation has not happened yet.
  void cancel() => _observer.dispose();
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
          onError: (error, stackTrace) {
            controller.addError(error, stackTrace);
            controller.close();
          },
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

final class _OneShotObserver implements ObservationObserver {
  _OneShotObserver(this._onChange);

  final void Function() _onChange;
  final Set<ObservationRegistrar> _registrars = {};
  bool _fired = false;

  bool get isActive => !_fired && _registrars.isNotEmpty;

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
    _fired = true;
    for (final registrar in _registrars) {
      registrar.removeObserver(this);
    }
    _registrars.clear();
  }
}
