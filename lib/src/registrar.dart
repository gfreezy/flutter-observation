import 'callbacks.dart';
import 'debug.dart';
import 'observer.dart';
import 'observation_key.dart';
import 'tracking.dart';
import 'transaction.dart';

/// Stores the property-to-observer relationships for one observable object.
final class ObservationRegistrar {
  final Map<Object, Set<ObservationObserver>> _observersByProperty = {};
  final Map<Object, int> _mutationDepthByProperty = {};

  /// Records a read of [property] by the current observer, if one exists.
  void access<T>(ObservationKey<T> property) {
    final observer = ObservationTracking.currentObserver;
    if (observer == null) return;

    _observersByProperty.putIfAbsent(property, () => {}).add(observer);
    observer.registerRegistrar(this);
    ObservationDebug.emit(
      kind: ObservationDebugEventKind.access,
      registrar: this,
      property: property,
      observerCount: _observersByProperty[property]!.length,
    );
  }

  /// Invalidates every observer that most recently read [property].
  void notify<T>(ObservationKey<T> property) {
    final observers = _observersByProperty[property];
    ObservationDebug.emit(
      kind: ObservationDebugEventKind.notify,
      registrar: this,
      property: property,
      observerCount: observers?.length ?? 0,
    );
    if (observers == null) return;

    // An invalidation may synchronously change subscriptions, so iterate over
    // a snapshot rather than the live set.
    runObservationCallbacks(
      List<ObservationObserver>.of(observers).map(
        (observer) =>
            () => ObservationTransaction.invalidate(observer),
      ),
    );
  }

  /// Marks the beginning of a manually managed mutation of [property].
  ///
  /// Pair this with [didSet]. Nested mutations of the same property produce a
  /// single notification when the outermost mutation completes.
  void willSet<T>(ObservationKey<T> property) {
    _mutationDepthByProperty.update(
      property,
      (depth) => depth + 1,
      ifAbsent: () => 1,
    );
  }

  /// Completes a mutation started by [willSet] and notifies observers.
  void didSet<T>(ObservationKey<T> property) {
    final depth = _mutationDepthByProperty[property];
    if (depth == null) {
      throw StateError(
        'didSet called without a matching willSet for $property',
      );
    }
    if (depth > 1) {
      _mutationDepthByProperty[property] = depth - 1;
      return;
    }
    _mutationDepthByProperty.remove(property);
    notify(property);
  }

  /// Runs [mutation] and notifies observers of [property] as one transaction.
  R withMutation<T, R>(ObservationKey<T> property, R Function() mutation) {
    return ObservationTransaction.run(() {
      willSet(property);
      try {
        return mutation();
      } finally {
        didSet(property);
      }
    });
  }

  /// Removes [observer] from every property in this registrar.
  void removeObserver(ObservationObserver observer) {
    _observersByProperty.removeWhere((_, observers) {
      observers.remove(observer);
      return observers.isEmpty;
    });
  }

  /// Whether [property] currently has one or more registered observers.
  bool hasObserversFor<T>(ObservationKey<T> property) {
    return _observersByProperty[property]?.isNotEmpty ?? false;
  }
}
