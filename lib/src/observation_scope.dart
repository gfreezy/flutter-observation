import 'package:flutter/widgets.dart';

/// Makes one model available to a descendant observation widget subtree.
///
/// Reading observable properties still requires an [Observer], an
/// `@ObservationWidget()` class, or another observation-tracking build scope.
final class ObservationScope<T> extends InheritedWidget {
  const ObservationScope({
    required this.value,
    required super.child,
    super.key,
  });

  /// The model shared with descendants.
  final T value;

  /// Returns the nearest scoped value and subscribes to instance replacement.
  static T of<T>(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ObservationScope<T>>();
    if (scope == null) {
      throw FlutterError('No ObservationScope<$T> found in this context.');
    }
    return scope.value;
  }

  /// Returns the nearest scoped value, or `null` when no matching scope exists.
  static T? maybeOf<T>(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ObservationScope<T>>()
        ?.value;
  }

  @override
  bool updateShouldNotify(ObservationScope<T> oldWidget) {
    return !identical(value, oldWidget.value);
  }
}
