import 'package:flutter/widgets.dart';

import 'observer_widget.dart';

/// An observation widget that creates and owns one long-lived [Model].
abstract class ObservationStatefulWidget<Model> extends StatefulWidget {
  const ObservationStatefulWidget({super.key});

  /// Creates the model owned by this location in the widget tree.
  Model createModel();

  /// Builds the widget tree while observable reads are tracked.
  Widget build(BuildContext context, Model model);

  /// Whether a widget configuration update should replace the current model.
  bool shouldRecreateModel(
    covariant ObservationStatefulWidget<Model> oldWidget,
  ) => false;

  /// Updates an existing model after the widget configuration changes.
  void didUpdateModel(
    covariant ObservationStatefulWidget<Model> oldWidget,
    Model model,
  ) {}

  /// Releases resources owned by [model].
  ///
  /// Override this when a hand-written Widget owns a model that needs cleanup.
  /// Generated `@ObservationWidget()` classes detect a zero-argument
  /// `dispose()` method at build time instead.
  void disposeModel(Model model) {}

  @override
  State<ObservationStatefulWidget<Model>> createState() =>
      _ObservationStatefulWidgetState<Model>();
}

final class _ObservationStatefulWidgetState<Model>
    extends State<ObservationStatefulWidget<Model>>
    with ObservationStateMixin<ObservationStatefulWidget<Model>> {
  late Model _model;

  @override
  void initState() {
    super.initState();
    _model = widget.createModel();
  }

  @override
  void didUpdateWidget(covariant ObservationStatefulWidget<Model> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldRecreateModel(oldWidget)) {
      stopObservation();
      oldWidget.disposeModel(_model);
      _model = widget.createModel();
    } else {
      widget.didUpdateModel(oldWidget, _model);
    }
  }

  @override
  Widget build(BuildContext context) {
    return buildObserved((context) => widget.build(context, _model));
  }

  @override
  void dispose() {
    stopObservation();
    try {
      widget.disposeModel(_model);
    } finally {
      super.dispose();
    }
  }
}
