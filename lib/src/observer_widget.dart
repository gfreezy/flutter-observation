import 'package:flutter/widgets.dart';

import 'debug.dart';
import 'observation_stateless_widget.dart';
import 'observer.dart';
import 'registrar.dart';
import 'tracking.dart';

/// A small reactive region that can be embedded in an existing widget tree.
final class Observer extends ObservationStatelessWidget {
  const Observer({required this.builder, super.key});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => builder(context);
}

/// Adds observation tracking to an existing [State] subclass.
///
/// Wrap the observed portion of `build` with [buildObserved].
mixin ObservationStateMixin<T extends StatefulWidget> on State<T>
    implements ObservationObserver, ObservationInspectorTarget {
  final Set<ObservationRegistrar> _observationRegistrars = {};
  bool _observationInvalidated = false;

  /// Business state owned by this [State] and shown in Flutter's Inspector.
  ///
  /// Generated `@ObservationWidget()` State classes override this for every
  /// `@ObservableState()` and `@PlainState()` factory.
  @protected
  Iterable<({String name, Object? value})> get observationOwnedStates =>
      const [];

  /// Executes [builder] while tracking observable reads.
  Widget buildObserved(WidgetBuilder builder) {
    _observationInvalidated = false;
    stopObservation();
    final label = widget.runtimeType.toString();
    ObservationDebug.registerInspectorTarget(this);
    ObservationDebug.emit(
      kind: ObservationDebugEventKind.rebuildStart,
      observer: this,
      observerLabel: label,
    );
    try {
      return ObservationTracking.track(this, () => builder(context));
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
  String get observationStateLabel => runtimeType.toString();

  @override
  Object get observationWidget => widget;

  @override
  Iterable<({String name, Object? value})>
  get observationInspectorStates sync* {
    final ownedReferenceIds = <int>{};
    for (final state in observationOwnedStates) {
      final description = ObservationDebug.describeValue(state.value);
      final referenceId = description['referenceId'];
      if (referenceId is int) ownedReferenceIds.add(referenceId);
      yield (name: 'owned state · ${state.name}', value: state.value);
    }

    final observedSources = <int, Object>{};
    for (final registrar in _observationRegistrars) {
      final source = registrar.debugSource;
      if (source == null) continue;
      final sourceId = ObservationDebug.idFor(source);
      if (ownedReferenceIds.contains(sourceId)) continue;
      observedSources[sourceId] = source;
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
    _observationRegistrars.add(registrar);
  }

  @override
  void invalidate() {
    if (!mounted || _observationInvalidated) return;
    _observationInvalidated = true;
    setState(() {});
  }

  /// Cancels the dependencies collected by the latest reactive build.
  @protected
  void stopObservation() {
    for (final registrar in _observationRegistrars) {
      registrar.removeObserver(this);
    }
    _observationRegistrars.clear();
  }

  @override
  void dispose() {
    stopObservation();
    super.dispose();
  }
}
