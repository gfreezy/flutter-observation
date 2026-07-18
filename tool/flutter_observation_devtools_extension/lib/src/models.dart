final class ObservationSnapshot {
  const ObservationSnapshot({
    required this.protocolVersion,
    required this.recording,
    required this.includeAccessEvents,
    required this.valueInspectionEnabled,
    required this.capacity,
    required this.latestSequence,
    required this.sources,
  });

  factory ObservationSnapshot.fromJson(Map<String, Object?> json) {
    return ObservationSnapshot(
      protocolVersion: _int(json['protocolVersion']),
      recording: json['recording'] == true,
      includeAccessEvents: json['includeAccessEvents'] == true,
      valueInspectionEnabled: json['valueInspectionEnabled'] == true,
      capacity: _int(json['capacity']),
      latestSequence: _int(json['latestSequence']),
      sources: _list(json['sources'])
          .map((value) => ObservationSourceSnapshot.fromJson(_map(value)))
          .toList(growable: false),
    );
  }

  final int protocolVersion;
  final bool recording;
  final bool includeAccessEvents;
  final bool valueInspectionEnabled;
  final int capacity;
  final int latestSequence;
  final List<ObservationSourceSnapshot> sources;

  int get propertyCount => sources.fold(
    0,
    (total, source) =>
        total +
        source.properties.where((property) => property.isObserved).length,
  );

  int get statePropertyCount =>
      sources.fold(0, (total, source) => total + source.properties.length);

  int get observerCount => {
    for (final source in sources)
      for (final property in source.properties)
        for (final observer in property.observers) observer.id,
  }.length;
}

final class ObservationSourceSnapshot {
  const ObservationSourceSnapshot({
    required this.id,
    required this.registrarId,
    required this.type,
    required this.properties,
  });

  factory ObservationSourceSnapshot.fromJson(Map<String, Object?> json) {
    return ObservationSourceSnapshot(
      id: _int(json['id']),
      registrarId: _int(json['registrarId']),
      type: json['type'] as String? ?? 'ObservableObject',
      properties: _list(json['properties'])
          .map((value) => ObservationPropertySnapshot.fromJson(_map(value)))
          .toList(growable: false),
    );
  }

  final int id;
  final int registrarId;
  final String type;
  final List<ObservationPropertySnapshot> properties;
}

final class ObservationPropertySnapshot {
  const ObservationPropertySnapshot({
    required this.id,
    required this.label,
    required this.observers,
    this.value,
  });

  factory ObservationPropertySnapshot.fromJson(Map<String, Object?> json) {
    return ObservationPropertySnapshot(
      id: _int(json['id']),
      label: cleanObservationLabel(json['label'] as String?),
      observers: _list(json['observers'])
          .map((value) => ObservationObserverSnapshot.fromJson(_map(value)))
          .toList(growable: false),
      value: json['value'] == null
          ? null
          : ObservationValueSnapshot.fromJson(_map(json['value'])),
    );
  }

  final int id;
  final String label;
  final List<ObservationObserverSnapshot> observers;
  final ObservationValueSnapshot? value;

  bool get isObserved => observers.isNotEmpty;
}

final class ObservationValueSnapshot {
  const ObservationValueSnapshot({
    required this.kind,
    required this.type,
    required this.display,
    required this.truncated,
    this.referenceId,
  });

  factory ObservationValueSnapshot.fromJson(Map<String, Object?> json) {
    return ObservationValueSnapshot(
      kind: json['kind'] as String? ?? 'unknown',
      type: json['type'] as String? ?? 'Object',
      display: json['display'] as String? ?? '<unavailable>',
      truncated: json['truncated'] == true,
      referenceId: _nullableInt(json['referenceId']),
    );
  }

  final String kind;
  final String type;
  final String display;
  final bool truncated;
  final int? referenceId;
}

final class ObservationObserverSnapshot {
  const ObservationObserverSnapshot({
    required this.id,
    required this.label,
    required this.canInspect,
    this.stateLabel,
  });

  factory ObservationObserverSnapshot.fromJson(Map<String, Object?> json) {
    return ObservationObserverSnapshot(
      id: _int(json['id']),
      label: json['label'] as String? ?? 'ObservationObserver',
      stateLabel: json['stateLabel'] as String?,
      canInspect: json['canInspect'] == true,
    );
  }

  final int id;
  final String label;
  final String? stateLabel;
  final bool canInspect;
}

final class ObservationEventRecord {
  const ObservationEventRecord({
    required this.sequence,
    required this.timestampMicros,
    required this.kind,
    required this.observerCount,
    this.sourceId,
    this.sourceType,
    this.propertyId,
    this.property,
    this.observerId,
    this.observer,
  });

  factory ObservationEventRecord.fromJson(Map<String, Object?> json) {
    return ObservationEventRecord(
      sequence: _int(json['sequence']),
      timestampMicros: _int(json['timestampMicros']),
      kind: json['kind'] as String? ?? 'unknown',
      observerCount: _int(json['observerCount']),
      sourceId: _nullableInt(json['sourceId']),
      sourceType: json['sourceType'] as String?,
      propertyId: _nullableInt(json['propertyId']),
      property: cleanObservationLabel(json['property'] as String?),
      observerId: _nullableInt(json['observerId']),
      observer: json['observer'] as String?,
    );
  }

  final int sequence;
  final int timestampMicros;
  final String kind;
  final int observerCount;
  final int? sourceId;
  final String? sourceType;
  final int? propertyId;
  final String? property;
  final int? observerId;
  final String? observer;

  DateTime get timestamp =>
      DateTime.fromMicrosecondsSinceEpoch(timestampMicros);

  String get searchableText => [
    kind,
    sourceType,
    property,
    observer,
    if (sourceId != null) '#$sourceId',
    if (propertyId != null) '#$propertyId',
    if (observerId != null) '#$observerId',
  ].whereType<String>().join(' ').toLowerCase();
}

String cleanObservationLabel(String? value) {
  if (value == null || value.isEmpty) return '—';
  final match = RegExp(r'^ObservationKey<.*>\((.*)\)$').firstMatch(value);
  return match?.group(1) ?? value;
}

Map<String, Object?> _map(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, value) => MapEntry('$key', value));
}

List<Object?> _list(Object? value) {
  return value is List ? value.cast<Object?>() : const [];
}

int _int(Object? value) => _nullableInt(value) ?? 0;

int? _nullableInt(Object? value) {
  return switch (value) {
    int value => value,
    num value => value.toInt(),
    String value => int.tryParse(value),
    _ => null,
  };
}
