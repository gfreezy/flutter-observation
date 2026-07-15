import 'package:flutter/widgets.dart';

import 'observer.dart';
import 'reactive_stateless_widget.dart';
import 'registrar.dart';
import 'tracking.dart';

/// A small reactive region that can be embedded in an existing widget tree.
final class Observer extends ReactiveStatelessWidget {
  const Observer({required this.builder, super.key});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => builder(context);
}

/// Adds observation tracking to an existing [State] subclass.
///
/// Wrap the reactive portion of `build` with [buildReactive].
mixin ReactiveStateMixin<T extends StatefulWidget> on State<T>
    implements ReactiveObserver {
  final Set<ObservationRegistrar> _observationRegistrars = {};
  bool _observationInvalidated = false;

  /// Executes [builder] while tracking observable reads.
  Widget buildReactive(WidgetBuilder builder) {
    _observationInvalidated = false;
    stopReactiveObservation();
    return ReactiveTracking.track(this, () => builder(context));
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
  void stopReactiveObservation() {
    for (final registrar in _observationRegistrars) {
      registrar.removeObserver(this);
    }
    _observationRegistrars.clear();
  }

  @override
  void dispose() {
    stopReactiveObservation();
    super.dispose();
  }
}
