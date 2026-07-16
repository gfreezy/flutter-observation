import 'registrar.dart';

/// A consumer that can be invalidated when one of its observed properties
/// changes.
abstract interface class ObservationObserver {
  /// Marks this consumer as needing to run again.
  void invalidate();

  /// Records a registrar used during the current tracking pass.
  ///
  /// This is called by [ObservationRegistrar] and is normally only relevant
  /// to framework integrations such as `ObservationStatelessWidget`.
  void registerRegistrar(ObservationRegistrar registrar);
}
