/// Marks a concrete model for observation code generation.
class ObservableModel {
  const ObservableModel();
}

/// Excludes a generated constructor property from observation tracking.
class ObservationIgnored {
  const ObservationIgnored();
}

/// Generates a getter without a public setter for a constructor property.
class ObservationReadOnly {
  const ObservationReadOnly();
}

/// Notifies after every assignment without comparing the previous value.
class ObservationAlwaysNotify {
  const ObservationAlwaysNotify();
}

/// Marks a Widget for reactive source generation.
///
/// Classes without [PlainState] or [ObservableState] factories generate a
/// reactive stateless base. Classes with one or more state factories generate
/// owned lifecycle state.
class ObservationWidget {
  const ObservationWidget();
}

/// Common configuration shared by the two state annotations.
sealed class StateAnnotation {
  const StateAnnotation({this.name, this.autoDispose = true});

  /// The name injected into the generated `build` method.
  ///
  /// When omitted, `createUser` becomes `user` and other method names are used
  /// unchanged.
  final String? name;

  /// Whether generated lifecycle code calls an available zero-argument
  /// `dispose()` method on this state.
  final bool autoDispose;
}

/// Marks an owned state factory whose return type must not be an
/// `ObservableObject`.
///
/// Use [ObservableState] when the returned state is itself observable.
final class PlainState extends StateAnnotation {
  const PlainState({super.name, super.autoDispose});
}

/// Marks an owned state factory whose return type must be an
/// `ObservableObject`.
///
/// This has the same lifecycle behavior and options as [PlainState], while
/// adding a generator-time check that the state itself is observable.
final class ObservableState extends StateAnnotation {
  const ObservableState({super.name, super.autoDispose});
}
