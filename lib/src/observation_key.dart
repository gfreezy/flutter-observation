/// A typed identity used to distinguish one observable property from another.
///
/// Keys compare by identity. Keep one stable key for the lifetime of a
/// property, normally as a `static final` field.
final class ObservationKey<T> {
  const ObservationKey([this.debugLabel]);

  /// An optional label used by diagnostics and debuggers.
  final String? debugLabel;

  @override
  String toString() => debugLabel == null
      ? 'ObservationKey<$T>'
      : 'ObservationKey<$T>($debugLabel)';
}
