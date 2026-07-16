import 'package:flutter/widgets.dart';

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
    implements ObservationObserver {
  final Set<ObservationRegistrar> _observationRegistrars = {};
  bool _observationInvalidated = false;

  /// Executes [builder] while tracking observable reads.
  Widget buildObserved(WidgetBuilder builder) {
    _observationInvalidated = false;
    stopObservation();
    return ObservationTracking.track(this, () => builder(context));
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
