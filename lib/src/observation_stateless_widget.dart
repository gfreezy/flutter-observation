import 'package:flutter/widgets.dart';

import 'debug.dart';
import 'observer.dart';
import 'registrar.dart';
import 'tracking.dart';
import 'widget_diagnostics.dart';

/// A widget with no owned business state whose observable reads are tracked.
///
/// Framework-internal subscription state is managed automatically.
abstract class ObservationStatelessWidget extends StatefulWidget
    with ObservationWidgetDiagnostics {
  const ObservationStatelessWidget({super.key});

  Widget build(BuildContext context);

  @override
  State<ObservationStatelessWidget> createState() =>
      _ObservationStatelessWidgetState();
}

final class _ObservationStatelessWidgetState
    extends State<ObservationStatelessWidget>
    implements ObservationObserver, ObservationInspectorTarget {
  final Set<ObservationRegistrar> _registrars = {};
  bool _invalidated = false;

  @override
  Widget build(BuildContext context) {
    _invalidated = false;
    _stopObserving();
    final label = widget.runtimeType.toString();
    ObservationDebug.registerInspectorTarget(this);
    ObservationDebug.emit(
      kind: ObservationDebugEventKind.rebuildStart,
      observer: this,
      observerLabel: label,
    );
    try {
      return ObservationTracking.track(this, () => widget.build(context));
    } finally {
      ObservationDebug.emit(
        kind: ObservationDebugEventKind.rebuildEnd,
        observer: this,
        observerLabel: label,
      );
    }
  }

  @override
  String get observationWidgetLabel => widget.runtimeType.toString();

  @override
  String get observationStateLabel => '${widget.runtimeType} State';

  @override
  Object get observationWidget => widget;

  @override
  Iterable<({String name, Object? value})>
  get observationInspectorStates sync* {
    final observedSources = <int, Object>{};
    for (final registrar in _registrars) {
      final source = registrar.debugSource;
      if (source == null) continue;
      observedSources[ObservationDebug.idFor(source)] = source;
    }
    for (final source in observedSources.values) {
      yield (name: 'observed state', value: source);
    }
  }

  @override
  bool selectInFlutterInspector() {
    if (!mounted) return false;
    // ignore: invalid_use_of_protected_member
    WidgetInspectorService.instance.setSelection(context);
    return true;
  }

  @override
  void registerRegistrar(ObservationRegistrar registrar) {
    _registrars.add(registrar);
  }

  @override
  void invalidate() {
    if (!mounted || _invalidated) return;
    _invalidated = true;
    setState(() {});
  }

  void _stopObserving() {
    for (final registrar in _registrars) {
      registrar.removeObserver(this);
    }
    _registrars.clear();
  }

  @override
  void dispose() {
    _stopObserving();
    super.dispose();
  }
}
