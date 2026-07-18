import 'observation_key.dart';
import 'registrar.dart';

/// Common protocol implemented by generated and manually observable models.
abstract interface class ObservableObject {
  ObservationRegistrar get observationRegistrar;
}

/// Adds an [ObservationRegistrar] and manual tracking helpers to a class.
///
/// This can be mixed into an existing class when code generation cannot own
/// its superclass slot.
mixin ObservableModelMixin implements ObservableObject {
  @override
  final ObservationRegistrar observationRegistrar = ObservationRegistrar();

  /// Registers a backing-field reader for opt-in debug state inspection.
  void observationRegisterDebugProperty<T>(
    ObservationKey<T> property,
    T Function() reader,
  ) {
    observationRegistrar.attachDebugSource(this);
    observationRegistrar.registerDebugProperty(property, reader);
  }

  /// Records a read of [property].
  void observationAccess<T>(ObservationKey<T> property) {
    observationRegistrar.attachDebugSource(this);
    observationRegistrar.access(property);
  }

  /// Runs [mutation] and notifies observers of [property].
  R observationMutation<T, R>(
    ObservationKey<T> property,
    R Function() mutation,
  ) {
    observationRegistrar.attachDebugSource(this);
    return observationRegistrar.withMutation(property, mutation);
  }

  /// Explicitly notifies observers after an externally managed mutation.
  void observationNotify<T>(ObservationKey<T> property) {
    observationRegistrar.attachDebugSource(this);
    observationRegistrar.notify(property);
  }
}
