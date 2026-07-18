import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;

/// The kind of runtime event emitted by [ObservationDebug].
enum ObservationDebugEventKind {
  access,
  dependencyAdded,
  dependencyRemoved,
  notify,
  invalidate,
  rebuildStart,
  rebuildEnd,
  observationStart,
  observationEnd,
  transactionStart,
  transactionEnd,
}

/// A lightweight diagnostic event for observation tooling and tests.
final class ObservationDebugEvent {
  const ObservationDebugEvent({
    required this.kind,
    required this.sequence,
    required this.timestampMicros,
    this.registrar,
    this.property,
    this.observer,
    this.registrarId,
    this.sourceId,
    this.sourceType,
    this.propertyId,
    this.propertyLabel,
    this.observerId,
    this.observerLabel,
    this.observerCount = 0,
    this.transactionDepth = 0,
  });

  final ObservationDebugEventKind kind;
  final int sequence;
  final int timestampMicros;

  /// Runtime objects are available to in-process listeners only.
  ///
  /// Serialized DevTools records contain IDs and labels instead, so the event
  /// buffer does not retain application objects.
  final Object? registrar;
  final Object? property;
  final Object? observer;

  final int? registrarId;
  final int? sourceId;
  final String? sourceType;
  final int? propertyId;
  final String? propertyLabel;
  final int? observerId;
  final String? observerLabel;
  final int observerCount;
  final int transactionDepth;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'sequence': sequence,
    'timestampMicros': timestampMicros,
    'registrarId': ?registrarId,
    'sourceId': ?sourceId,
    'sourceType': ?sourceType,
    'propertyId': ?propertyId,
    'property': ?propertyLabel,
    'observerId': ?observerId,
    'observer': ?observerLabel,
    'observerCount': observerCount,
    if (transactionDepth > 0) 'transactionDepth': transactionDepth,
  };
}

/// A registrar-like object that can provide a serializable dependency graph.
///
/// This protocol is intended for Observation framework adapters. Application
/// code normally uses [ObservationDebug] rather than implementing it.
abstract interface class ObservationDebugSnapshotProvider {
  Map<String, Object?> createObservationDebugSnapshot();
}

/// A weakly registered Flutter element that can be selected in the Inspector.
abstract interface class ObservationInspectorTarget {
  Object get observationWidget;
  String get observationWidgetLabel;
  String get observationStateLabel;
  Iterable<({String name, Object? value})> get observationInspectorStates;
  bool selectInFlutterInspector();
}

/// A disposable registration returned by [ObservationDebug.addListener].
final class ObservationDebugListenerHandle {
  ObservationDebugListenerHandle._(this._listener);

  void Function(ObservationDebugEvent event)? _listener;

  bool get isDisposed => _listener == null;

  void dispose() {
    if (_listener == null) return;
    _listener = null;
    ObservationDebug._listeners.remove(this);
  }
}

/// Optional diagnostics used by in-process tooling and the DevTools extension.
///
/// No event objects are allocated when there are no listeners and recording is
/// disabled. Recorded events contain IDs and labels only; they never retain
/// application models, properties, or observers.
abstract final class ObservationDebug {
  static const int protocolVersion = 2;
  static const int defaultCapacity = 2000;
  static const int _maxValueLength = 240;
  static const int _maxCollectionItems = 20;
  static const bool isReleaseMode = bool.fromEnvironment('dart.vm.product');

  /// Backward-compatible single callback for lightweight local diagnostics.
  static void Function(ObservationDebugEvent event)? onEvent;

  static final Set<ObservationDebugListenerHandle> _listeners = {};
  static final ListQueue<Map<String, Object?>> _records = ListQueue();
  static final List<WeakReference<ObservationDebugSnapshotProvider>>
  _providers = [];
  static final Expando<int> _objectIds = Expando<int>('observationDebugId');
  static final Map<int, WeakReference<Object>> _objectsById = {};
  static final Expando<String> _observerLabels = Expando<String>(
    'observationObserverLabel',
  );
  static final Expando<String> _observerStateLabels = Expando<String>(
    'observationObserverStateLabel',
  );
  static final Map<int, WeakReference<ObservationInspectorTarget>>
  _inspectorTargets = {};
  static final Expando<WeakReference<ObservationInspectorTarget>>
  _inspectorTargetsByWidget =
      Expando<WeakReference<ObservationInspectorTarget>>(
        'observationInspectorTargetByWidget',
      );
  static final Expando<bool> _observableSources = Expando<bool>(
    'observationObservableSource',
  );

  static int _nextObjectId = 1;
  static int _nextSequence = 1;
  static int _registrationsUntilPrune = 64;
  static int _inspectorRegistrationsUntilPrune = 64;
  static int _objectRegistrationsUntilPrune = 64;
  static bool _recording = false;
  static bool _includeAccessEvents = false;
  static bool _valueInspectionEnabled = false;
  static int _capacity = defaultCapacity;

  static bool get isRecording => _recording;
  static bool get includeAccessEvents => _includeAccessEvents;
  static bool get valueInspectionEnabled => _valueInspectionEnabled;
  static int get capacity => _capacity;
  static int get latestSequence => _nextSequence - 1;

  /// Adds a listener without replacing [onEvent].
  static ObservationDebugListenerHandle addListener(
    void Function(ObservationDebugEvent event) listener,
  ) {
    final handle = ObservationDebugListenerHandle._(listener);
    _listeners.add(handle);
    return handle;
  }

  /// Enables or disables the bounded, serializable event buffer.
  static void setRecording(
    bool enabled, {
    int capacity = defaultCapacity,
    bool includeAccessEvents = false,
  }) {
    if (isReleaseMode) return;
    if (capacity <= 0) {
      throw ArgumentError.value(capacity, 'capacity', 'Must be positive.');
    }
    _capacity = capacity;
    _includeAccessEvents = includeAccessEvents;
    _recording = enabled;
    _trimRecords();
  }

  /// Removes all buffered events without changing the recording state.
  static void clearEvents() => _records.clear();

  /// Enables or disables opt-in state value inspection for debug snapshots.
  static void setValueInspection(bool enabled) {
    if (isReleaseMode) return;
    _valueInspectionEnabled = enabled;
  }

  /// Returns buffered events newer than [afterSequence].
  static List<Map<String, Object?>> eventsAfter(
    int afterSequence, {
    int limit = 500,
  }) {
    if (limit <= 0) return const [];
    return _records
        .where((event) => (event['sequence']! as int) > afterSequence)
        .take(limit)
        .map(Map<String, Object?>.of)
        .toList(growable: false);
  }

  /// Returns the current dependency graph and optional opt-in state values.
  static Map<String, Object?> snapshot() {
    final sources = <Map<String, Object?>>[];
    _providers.removeWhere((reference) {
      final provider = reference.target;
      if (provider == null) return true;
      sources.add(provider.createObservationDebugSnapshot());
      return false;
    });
    return {
      'protocolVersion': protocolVersion,
      'recording': _recording,
      'includeAccessEvents': _includeAccessEvents,
      'valueInspectionEnabled': _valueInspectionEnabled,
      'capacity': _capacity,
      'latestSequence': latestSequence,
      'sources': sources,
    };
  }

  /// Returns a stable debug ID without retaining [object].
  static int idFor(Object object) {
    final existing = _objectIds[object];
    if (existing != null) {
      _objectsById[existing] ??= WeakReference(object);
      return existing;
    }
    final id = _nextObjectId++;
    _objectIds[object] = id;
    _objectsById[id] = WeakReference(object);
    _objectRegistrationsUntilPrune--;
    if (_objectRegistrationsUntilPrune == 0) {
      _objectRegistrationsUntilPrune = 64;
      _objectsById.removeWhere((_, reference) => reference.target == null);
    }
    return id;
  }

  /// Resolves a debug ID without keeping the referenced object alive.
  ///
  /// IDs are unique only within the current Dart isolate lifetime. This
  /// returns `null` after the object is collected or the isolate restarts.
  static Object? objectForId(int id) {
    if (isReleaseMode || id <= 0) return null;
    final reference = _objectsById[id];
    final object = reference?.target;
    if (reference != null && object == null) _objectsById.remove(id);
    return object;
  }

  /// Marks [source] as observable so value previews do not traverse it.
  static void markObservableSource(Object source) {
    if (isReleaseMode) return;
    _observableSources[source] = true;
  }

  /// Converts a state value into a bounded JSON-safe debug description.
  ///
  /// This never calls `toString()` on arbitrary application objects.
  static Map<String, Object?> describeValue(Object? value) {
    if (value == null) {
      return const {'kind': 'null', 'type': 'Null', 'display': 'null'};
    }
    if (value is String) {
      final encoded = jsonEncode(value);
      final truncated = encoded.length > _maxValueLength;
      return {
        'kind': 'string',
        'type': value.runtimeType.toString(),
        'display': _truncate(encoded),
        if (truncated) 'truncated': true,
      };
    }
    if (value is num || value is bool) {
      return {
        'kind': 'scalar',
        'type': value.runtimeType.toString(),
        'display': '$value',
      };
    }
    if (value is Enum) {
      return {
        'kind': 'enum',
        'type': value.runtimeType.toString(),
        'display': value.name,
      };
    }
    if (value is DateTime ||
        value is Duration ||
        value is Uri ||
        value is RegExp) {
      return {
        'kind': 'scalar',
        'type': value.runtimeType.toString(),
        'display': _truncate('$value'),
      };
    }
    if (_observableSources[value] == true) {
      final referenceId = idFor(value);
      return {
        'kind': 'observable',
        'type': value.runtimeType.toString(),
        'display': '${value.runtimeType} #$referenceId',
        'referenceId': referenceId,
      };
    }
    if (value is Map) return _describeMap(value);
    if (value is List) return _describeIterable(value, '[', ']');
    if (value is Set) return _describeIterable(value, '{', '}');
    final referenceId = idFor(value);
    return {
      'kind': 'object',
      'type': value.runtimeType.toString(),
      'display': '${value.runtimeType} #$referenceId',
      'referenceId': referenceId,
    };
  }

  static Map<String, Object?> _describeIterable(
    Iterable<Object?> values,
    String opening,
    String closing,
  ) {
    try {
      final preview = values
          .take(_maxCollectionItems)
          .map(_previewValue)
          .join(', ');
      final truncated = values.length > _maxCollectionItems;
      return {
        'kind': 'collection',
        'type': values.runtimeType.toString(),
        'display': '$opening$preview${truncated ? ', …' : ''}$closing',
        if (truncated) 'truncated': true,
      };
    } catch (error) {
      return _describeValueError(error);
    }
  }

  static Map<String, Object?> _describeMap(Map<Object?, Object?> values) {
    try {
      final entries = values.entries
          .take(_maxCollectionItems)
          .map((entry) {
            return '${_previewValue(entry.key)}: ${_previewValue(entry.value)}';
          })
          .join(', ');
      final truncated = values.length > _maxCollectionItems;
      return {
        'kind': 'collection',
        'type': values.runtimeType.toString(),
        'display': '{$entries${truncated ? ', …' : ''}}',
        if (truncated) 'truncated': true,
      };
    } catch (error) {
      return _describeValueError(error);
    }
  }

  static String _previewValue(Object? value) {
    if (value == null) return 'null';
    if (value is String) return _truncate(jsonEncode(value), limit: 60);
    if (value is num || value is bool) return '$value';
    if (value is Enum) return value.name;
    return '${value.runtimeType} #${idFor(value)}';
  }

  static Map<String, Object?> _describeValueError(Object error) => {
    'kind': 'error',
    'type': error.runtimeType.toString(),
    'display': '<unavailable>',
  };

  static String _truncate(String value, {int limit = _maxValueLength}) {
    if (value.length <= limit) return value;
    return '${value.substring(0, limit - 1)}…';
  }

  /// Sets the user-facing label used for an observer in events and snapshots.
  static void labelObserver(Object observer, String label) {
    if (isReleaseMode) return;
    _observerLabels[observer] = label;
  }

  static String observerLabel(Object observer) {
    return _observerLabels[observer] ?? observer.runtimeType.toString();
  }

  /// Registers a weak Flutter Inspector target for an observation owner.
  static void registerInspectorTarget(ObservationInspectorTarget target) {
    if (isReleaseMode) return;
    labelObserver(target, target.observationWidgetLabel);
    _observerStateLabels[target] = target.observationStateLabel;
    _inspectorTargets[idFor(target)] = WeakReference(target);
    _inspectorTargetsByWidget[target.observationWidget] = WeakReference(target);
    _inspectorRegistrationsUntilPrune--;
    if (_inspectorRegistrationsUntilPrune == 0) {
      _inspectorRegistrationsUntilPrune = 64;
      _inspectorTargets.removeWhere((_, reference) => reference.target == null);
    }
  }

  /// Returns the business-state diagnostics for a registered Flutter Widget.
  ///
  /// Both the Widget and its State target are weakly held. The returned values
  /// are intended to be wrapped in transient Flutter [DiagnosticsNode]s.
  static List<({String name, Object? value, String display})>
  describeInspectorStates(Object widget) {
    if (isReleaseMode) return const [];
    final target = _inspectorTargetsByWidget[widget]?.target;
    if (target == null) return const [];
    return target.observationInspectorStates
        .map((state) {
          final description = describeValue(state.value);
          return (
            name: state.name,
            value: state.value,
            display: description['display']! as String,
          );
        })
        .toList(growable: false);
  }

  /// Returns serializable Widget and State metadata for [observer].
  static Map<String, Object?> describeObserver(Object observer) {
    final id = idFor(observer);
    return {
      'id': id,
      'label': observerLabel(observer),
      'stateLabel': ?_observerStateLabels[observer],
      'canInspect': _inspectorTargets[id]?.target != null,
    };
  }

  /// Selects a registered observation owner in Flutter's Widget Inspector.
  static bool selectInspectorTarget(int observerId) {
    if (isReleaseMode) return false;
    final target = _inspectorTargets[observerId]?.target;
    if (target == null) {
      _inspectorTargets.remove(observerId);
      return false;
    }
    return target.selectInFlutterInspector();
  }

  /// Registers a weak snapshot provider and initializes the VM service bridge.
  static void registerSnapshotProvider(
    ObservationDebugSnapshotProvider provider,
  ) {
    if (isReleaseMode) return;
    ObservationDevTools.initialize();
    _registrationsUntilPrune--;
    if (_registrationsUntilPrune == 0) {
      _registrationsUntilPrune = 64;
      _providers.removeWhere((reference) => reference.target == null);
    }
    _providers.add(WeakReference(provider));
  }

  /// Emits one event when diagnostics are active.
  static void emit({
    required ObservationDebugEventKind kind,
    Object? registrar,
    Object? source,
    Object? property,
    Object? observer,
    String? observerLabel,
    int observerCount = 0,
    int transactionDepth = 0,
  }) {
    if (isReleaseMode) return;
    if (observer != null && observerLabel != null) {
      _observerLabels[observer] = observerLabel;
    }
    final callback = onEvent;
    final hasListeners = callback != null || _listeners.isNotEmpty;
    final shouldRecord =
        _recording &&
        (kind != ObservationDebugEventKind.access || _includeAccessEvents);
    if (!hasListeners && !shouldRecord) return;

    final event = ObservationDebugEvent(
      kind: kind,
      sequence: _nextSequence++,
      timestampMicros: DateTime.now().microsecondsSinceEpoch,
      registrar: registrar,
      property: property,
      observer: observer,
      registrarId: registrar == null ? null : idFor(registrar),
      sourceId: source == null ? null : idFor(source),
      sourceType: source?.runtimeType.toString(),
      propertyId: property == null ? null : idFor(property),
      propertyLabel: property?.toString(),
      observerId: observer == null ? null : idFor(observer),
      observerLabel: observer == null
          ? null
          : ObservationDebug.observerLabel(observer),
      observerCount: observerCount,
      transactionDepth: transactionDepth,
    );

    if (shouldRecord) {
      _records.addLast(event.toJson());
      _trimRecords();
    }
    if (callback != null) _invokeListener(callback, event);
    for (final handle in List.of(_listeners)) {
      final listener = handle._listener;
      if (listener != null) _invokeListener(listener, event);
    }
  }

  static void _invokeListener(
    void Function(ObservationDebugEvent) listener,
    ObservationDebugEvent event,
  ) {
    try {
      listener(event);
    } catch (_) {
      // Diagnostics must never break application mutations or lifecycle work.
    }
  }

  static void _trimRecords() {
    while (_records.length > _capacity) {
      _records.removeFirst();
    }
  }
}

/// Debug/profile VM Service bridge consumed by the Flutter DevTools extension.
abstract final class ObservationDevTools {
  static const String getSnapshotMethod = 'ext.flutter_observation.getSnapshot';
  static const String getEventsMethod = 'ext.flutter_observation.getEvents';
  static const String setRecordingMethod =
      'ext.flutter_observation.setRecording';
  static const String setValueInspectionMethod =
      'ext.flutter_observation.setValueInspection';
  static const String selectInspectorTargetMethod =
      'ext.flutter_observation.selectInspectorTarget';
  static const String clearEventsMethod = 'ext.flutter_observation.clearEvents';

  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  /// Registers the Observation service protocol once in the current isolate.
  static void initialize() {
    if (ObservationDebug.isReleaseMode || _initialized) return;
    _initialized = true;
    developer.registerExtension(getSnapshotMethod, _getSnapshot);
    developer.registerExtension(getEventsMethod, _getEvents);
    developer.registerExtension(setRecordingMethod, _setRecording);
    developer.registerExtension(setValueInspectionMethod, _setValueInspection);
    developer.registerExtension(
      selectInspectorTargetMethod,
      _selectInspectorTarget,
    );
    developer.registerExtension(clearEventsMethod, _clearEvents);
  }

  static Future<developer.ServiceExtensionResponse> _getSnapshot(
    String method,
    Map<String, String> parameters,
  ) async {
    return _result(ObservationDebug.snapshot());
  }

  static Future<developer.ServiceExtensionResponse> _getEvents(
    String method,
    Map<String, String> parameters,
  ) async {
    final after = int.tryParse(parameters['after'] ?? '0');
    final limit = int.tryParse(parameters['limit'] ?? '500');
    if (after == null || limit == null || limit <= 0) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.invalidParams,
        '`after` must be an integer and `limit` must be positive.',
      );
    }
    return _result({
      'protocolVersion': ObservationDebug.protocolVersion,
      'latestSequence': ObservationDebug.latestSequence,
      'events': ObservationDebug.eventsAfter(
        after,
        limit: limit.clamp(1, 1000),
      ),
    });
  }

  static Future<developer.ServiceExtensionResponse> _setRecording(
    String method,
    Map<String, String> parameters,
  ) async {
    final enabled = switch (parameters['enabled']) {
      'true' => true,
      'false' => false,
      _ => null,
    };
    final capacity = int.tryParse(
      parameters['capacity'] ?? '${ObservationDebug.defaultCapacity}',
    );
    final includeAccessEvents = parameters['includeAccessEvents'] == 'true';
    if (enabled == null || capacity == null || capacity <= 0) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.invalidParams,
        '`enabled` must be true/false and `capacity` must be positive.',
      );
    }
    ObservationDebug.setRecording(
      enabled,
      capacity: capacity,
      includeAccessEvents: includeAccessEvents,
    );
    return _result(ObservationDebug.snapshot());
  }

  static Future<developer.ServiceExtensionResponse> _clearEvents(
    String method,
    Map<String, String> parameters,
  ) async {
    ObservationDebug.clearEvents();
    return _result({
      'protocolVersion': ObservationDebug.protocolVersion,
      'latestSequence': ObservationDebug.latestSequence,
    });
  }

  static Future<developer.ServiceExtensionResponse> _selectInspectorTarget(
    String method,
    Map<String, String> parameters,
  ) async {
    final observerId = int.tryParse(parameters['observerId'] ?? '');
    if (observerId == null || observerId <= 0) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.invalidParams,
        '`observerId` must be a positive integer.',
      );
    }
    return _result({
      'protocolVersion': ObservationDebug.protocolVersion,
      'selected': ObservationDebug.selectInspectorTarget(observerId),
    });
  }

  static Future<developer.ServiceExtensionResponse> _setValueInspection(
    String method,
    Map<String, String> parameters,
  ) async {
    final enabled = switch (parameters['enabled']) {
      'true' => true,
      'false' => false,
      _ => null,
    };
    if (enabled == null) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.invalidParams,
        '`enabled` must be true or false.',
      );
    }
    ObservationDebug.setValueInspection(enabled);
    return _result(ObservationDebug.snapshot());
  }

  static developer.ServiceExtensionResponse _result(
    Map<String, Object?> value,
  ) {
    return developer.ServiceExtensionResponse.result(jsonEncode(value));
  }
}
