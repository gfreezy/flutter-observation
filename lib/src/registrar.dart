import 'callbacks.dart';
import 'debug.dart';
import 'observer.dart';
import 'observation_key.dart';
import 'tracking.dart';
import 'transaction.dart';

/// Stores the property-to-observer relationships for one observable object.
final class ObservationRegistrar implements ObservationDebugSnapshotProvider {
  ObservationRegistrar() {
    ObservationDebug.registerSnapshotProvider(this);
  }

  final Map<Object, Set<ObservationObserver>> _observersByProperty = {};
  final Map<Object, int> _mutationDepthByProperty = {};
  final Map<Object, Object? Function()> _debugValueReaders = {};
  WeakReference<Object>? _debugSource;

  /// Associates this registrar with its owning model for debug metadata.
  ///
  /// The owner is weakly referenced. State values are read only through
  /// explicitly registered backing-field readers while inspection is enabled.
  void attachDebugSource(Object source) {
    if (ObservationDebug.isReleaseMode) return;
    if (identical(_debugSource?.target, source)) return;
    _debugSource = WeakReference(source);
    ObservationDebug.markObservableSource(source);
  }

  /// Registers a backing-field reader used by opt-in DevTools inspection.
  void registerDebugProperty<T>(
    ObservationKey<T> property,
    T Function() reader,
  ) {
    if (ObservationDebug.isReleaseMode) return;
    _debugValueReaders[property] = reader;
  }

  Object get _eventSource => _debugSource?.target ?? this;

  /// Returns the weakly held observable source for Flutter diagnostics.
  ///
  /// Application code normally does not need this. Reading it never keeps the
  /// source alive beyond the returned reference.
  Object? get debugSource => _debugSource?.target;

  /// Records a read of [property] by the current observer, if one exists.
  void access<T>(ObservationKey<T> property) {
    final observer = ObservationTracking.currentObserver;
    if (observer == null) return;

    final observers = _observersByProperty.putIfAbsent(property, () => {});
    final added = observers.add(observer);
    observer.registerRegistrar(this);
    ObservationDebug.emit(
      kind: ObservationDebugEventKind.access,
      registrar: this,
      source: _eventSource,
      property: property,
      observer: observer,
      observerCount: observers.length,
    );
    if (added) {
      ObservationDebug.emit(
        kind: ObservationDebugEventKind.dependencyAdded,
        registrar: this,
        source: _eventSource,
        property: property,
        observer: observer,
        observerCount: observers.length,
      );
    }
  }

  /// Invalidates every observer that most recently read [property].
  void notify<T>(ObservationKey<T> property) {
    final observers = _observersByProperty[property];
    ObservationDebug.emit(
      kind: ObservationDebugEventKind.notify,
      registrar: this,
      source: _eventSource,
      property: property,
      observerCount: observers?.length ?? 0,
    );
    if (observers == null) return;

    // An invalidation may synchronously change subscriptions, so iterate over
    // a snapshot rather than the live set.
    runObservationCallbacks(
      List<ObservationObserver>.of(observers).map(
        (observer) => () {
          ObservationDebug.emit(
            kind: ObservationDebugEventKind.invalidate,
            registrar: this,
            source: _eventSource,
            property: property,
            observer: observer,
            observerCount: observers.length,
          );
          ObservationTransaction.invalidate(observer);
        },
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
    _observersByProperty.removeWhere((property, observers) {
      final removed = observers.remove(observer);
      if (removed) {
        ObservationDebug.emit(
          kind: ObservationDebugEventKind.dependencyRemoved,
          registrar: this,
          source: _eventSource,
          property: property,
          observer: observer,
          observerCount: observers.length,
        );
      }
      return observers.isEmpty;
    });
  }

  /// Whether [property] currently has one or more registered observers.
  bool hasObserversFor<T>(ObservationKey<T> property) {
    return _observersByProperty[property]?.isNotEmpty ?? false;
  }

  /// Reads the registered backing fields for Flutter Inspector diagnostics.
  ///
  /// This is debug-only tooling. Readers are generated from backing fields, so
  /// this does not invoke observable getters or create dependencies.
  List<({String label, Object? value, bool available})>
  readDebugPropertyValues() {
    if (ObservationDebug.isReleaseMode) return const [];
    return _debugValueReaders.entries
        .map((entry) {
          try {
            final property = entry.key;
            final label = property is ObservationKey
                ? property.debugLabel ?? property.toString()
                : property.toString();
            return (label: label, value: entry.value(), available: true);
          } catch (_) {
            return (label: entry.key.toString(), value: null, available: false);
          }
        })
        .toList(growable: false);
  }

  @override
  Map<String, Object?> createObservationDebugSnapshot() {
    final source = _debugSource?.target;
    final propertyKeys = <Object>{
      ..._debugValueReaders.keys,
      ..._observersByProperty.keys,
    };
    final properties =
        propertyKeys
            .map((property) {
              final observers = (_observersByProperty[property] ?? const {})
                  .map(ObservationDebug.describeObserver)
                  .toList(growable: false);
              final value = ObservationDebug.valueInspectionEnabled
                  ? _readDebugValue(property)
                  : null;
              return <String, Object?>{
                'id': ObservationDebug.idFor(property),
                'label': property.toString(),
                'observerCount': observers.length,
                'observers': observers,
                'value': ?value,
              };
            })
            .toList(growable: false)
          ..sort((a, b) {
            return (a['label']! as String).compareTo(b['label']! as String);
          });
    return {
      'id': ObservationDebug.idFor(source ?? this),
      'registrarId': ObservationDebug.idFor(this),
      'type': source?.runtimeType.toString() ?? 'ObservableObject',
      'propertyCount': _observersByProperty.length,
      'statePropertyCount': _debugValueReaders.length,
      'observerCount': _observersByProperty.values
          .expand((observers) => observers)
          .toSet()
          .length,
      'properties': properties,
    };
  }

  Map<String, Object?>? _readDebugValue(Object property) {
    final reader = _debugValueReaders[property];
    if (reader == null) return null;
    try {
      return ObservationDebug.describeValue(reader());
    } catch (error) {
      return {
        'kind': 'error',
        'type': error.runtimeType.toString(),
        'display': '<unavailable>',
      };
    }
  }
}
