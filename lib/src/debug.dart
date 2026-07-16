/// The kind of runtime event emitted by [ObservationDebug].
enum ObservationDebugEventKind { access, notify }

/// A lightweight diagnostic event for observation tooling and tests.
final class ObservationDebugEvent {
  const ObservationDebugEvent({
    required this.kind,
    required this.registrar,
    required this.property,
    required this.observerCount,
  });

  final ObservationDebugEventKind kind;
  final Object registrar;
  final Object property;
  final int observerCount;
}

/// Optional global hook used to inspect property access and invalidation.
///
/// No event objects are allocated while [onEvent] is `null`.
abstract final class ObservationDebug {
  static void Function(ObservationDebugEvent event)? onEvent;

  static void emit({
    required ObservationDebugEventKind kind,
    required Object registrar,
    required Object property,
    required int observerCount,
  }) {
    final callback = onEvent;
    if (callback == null) return;
    callback(
      ObservationDebugEvent(
        kind: kind,
        registrar: registrar,
        property: property,
        observerCount: observerCount,
      ),
    );
  }
}
