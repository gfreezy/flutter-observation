import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'debug.dart';
import 'model.dart';

/// Adds Observation business state as top-level Flutter Inspector properties.
///
/// Generated `@ObservationWidget()` classes include this automatically.
mixin ObservationWidgetDiagnostics on Widget {
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    if (ObservationDebug.isReleaseMode) return;

    for (final state in ObservationDebug.describeInspectorStates(this)) {
      final inspectorValue = _ObservationInspectorValue(
        value: state.value,
        display: state.display,
      );
      properties.add(
        DiagnosticsProperty<Object?>(
          state.name,
          inspectorValue,
          description: state.display,
          expandableValue: true,
        ),
      );
    }
  }
}

/// Debug-only access to Observation state for Flutter's selected Widget.
///
/// This is primarily intended for expressions entered in the DevTools Console.
abstract final class ObservationInspector {
  /// Returns the business state attached to Flutter Inspector's selection.
  static Map<String, Object?> get selectedStates {
    if (ObservationDebug.isReleaseMode) return const {};
    final widget =
        WidgetInspectorService.instance.selection.currentElement?.widget;
    return widget == null ? const {} : statesFor(widget);
  }

  /// Returns the business state attached to [widget], keyed by diagnostic name.
  static Map<String, Object?> statesFor(Widget widget) {
    if (ObservationDebug.isReleaseMode) return const {};
    final result = <String, Object?>{};
    for (final state in ObservationDebug.describeInspectorStates(widget)) {
      final type = state.value?.runtimeType.toString() ?? 'Null';
      final baseName = state.name == 'observed state'
          ? '${state.name} · $type'
          : state.name;
      var name = baseName;
      var suffix = 2;
      while (result.containsKey(name)) {
        name = '$baseName ($suffix)';
        suffix++;
      }
      result[name] = state.value;
    }
    return Map.unmodifiable(result);
  }

  /// Returns the first selected business state assignable to [T].
  static T? selectedStateOf<T>() {
    for (final value in selectedStates.values) {
      if (value is T) return value;
    }
    return null;
  }

  /// Resolves a displayed `#id` to its live debug object.
  ///
  /// Returns `null` when the type does not match [T], the object was collected,
  /// or the ID belongs to another isolate or application run.
  static T? stateById<T>(int id) {
    final value = ObservationDebug.objectForId(id);
    return value is T ? value : null;
  }
}

final class _ObservationInspectorValue extends DiagnosticableTree {
  _ObservationInspectorValue({
    required Object? value,
    required String display,
  }) {
    _data[this] = (value: value ?? _nullValue, display: display);
  }

  static final Expando<({Object value, String display})> _data =
      Expando<({Object value, String display})>('observationInspectorValue');
  static final Object _nullValue = Object();

  Object? get _value {
    final value = _data[this]!.value;
    return identical(value, _nullValue) ? null : value;
  }

  @override
  String toStringShort() => _data[this]!.display;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    final source = _value;
    if (source is! ObservableObject) return;

    for (final property
        in source.observationRegistrar.readDebugPropertyValues()) {
      if (!property.available) {
        properties.add(
          StringProperty(
            property.label,
            '<unavailable>',
            quoted: false,
            level: DiagnosticLevel.error,
          ),
        );
        continue;
      }

      final description = ObservationDebug.describeValue(property.value);
      final nestedValue = property.value is ObservableObject
          ? _ObservationInspectorValue(
              value: property.value,
              display: description['display']! as String,
            )
          : property.value;
      properties.add(
        DiagnosticsProperty<Object?>(
          property.label,
          nestedValue,
          description: description['display']! as String,
          expandableValue: nestedValue is _ObservationInspectorValue,
        ),
      );
    }
  }
}
