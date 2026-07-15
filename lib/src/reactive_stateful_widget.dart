import 'package:flutter/widgets.dart';

import 'observer_widget.dart';

/// A reactive widget that creates and owns one long-lived [Model].
abstract class ReactiveStatefulWidget<Model> extends StatefulWidget {
  const ReactiveStatefulWidget({super.key});

  /// Creates the model owned by this location in the widget tree.
  Model createModel();

  /// Builds the widget tree while observable reads are tracked.
  Widget build(BuildContext context, Model model);

  /// Whether a widget configuration update should replace the current model.
  bool shouldRecreateModel(covariant ReactiveStatefulWidget<Model> oldWidget) =>
      false;

  /// Updates an existing model after the widget configuration changes.
  void didUpdateModel(
    covariant ReactiveStatefulWidget<Model> oldWidget,
    Model model,
  ) {}

  /// Releases resources owned by [model].
  ///
  /// Override this when a hand-written Widget owns a model that needs cleanup.
  /// Generated `@observationWidget` classes detect a zero-argument `dispose()`
  /// method at build time instead.
  void disposeModel(Model model) {}

  @override
  State<ReactiveStatefulWidget<Model>> createState() =>
      _ReactiveStatefulWidgetState<Model>();
}

final class _ReactiveStatefulWidgetState<Model>
    extends State<ReactiveStatefulWidget<Model>>
    with ReactiveStateMixin<ReactiveStatefulWidget<Model>> {
  late Model _model;

  @override
  void initState() {
    super.initState();
    _model = widget.createModel();
  }

  @override
  void didUpdateWidget(covariant ReactiveStatefulWidget<Model> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldRecreateModel(oldWidget)) {
      stopReactiveObservation();
      oldWidget.disposeModel(_model);
      _model = widget.createModel();
    } else {
      widget.didUpdateModel(oldWidget, _model);
    }
  }

  @override
  Widget build(BuildContext context) {
    return buildReactive((context) => widget.build(context, _model));
  }

  @override
  void dispose() {
    stopReactiveObservation();
    try {
      widget.disposeModel(_model);
    } finally {
      super.dispose();
    }
  }
}
