import 'package:flutter/widgets.dart';

import 'observer.dart';
import 'registrar.dart';
import 'tracking.dart';

/// A widget with no owned business state whose observable reads are tracked.
///
/// Framework-internal subscription state is managed automatically.
abstract class ReactiveStatelessWidget extends StatefulWidget {
  const ReactiveStatelessWidget({super.key});

  Widget build(BuildContext context);

  @override
  State<ReactiveStatelessWidget> createState() =>
      _ReactiveStatelessWidgetState();
}

final class _ReactiveStatelessWidgetState extends State<ReactiveStatelessWidget>
    implements ReactiveObserver {
  final Set<ObservationRegistrar> _registrars = {};
  bool _invalidated = false;

  @override
  Widget build(BuildContext context) {
    _invalidated = false;
    _stopObserving();
    return ReactiveTracking.track(this, () => widget.build(context));
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
