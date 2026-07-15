// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lifecycle_example.dart';

// **************************************************************************
// ObservationWidgetGenerator
// **************************************************************************

abstract class _$LifecycleExample extends StatefulWidget {
  const _$LifecycleExample({super.key});

  Widget build(BuildContext context, {required LifecycleResource resource});

  bool shouldRecreateStates(covariant _$LifecycleExample oldWidget) => false;

  void didUpdateStates(
    covariant _$LifecycleExample oldWidget, {
    required LifecycleResource resource,
  }) {}

  void disposeStates({required LifecycleResource resource}) {}

  @override
  State<LifecycleExample> createState() => _$LifecycleExampleState();
}

final class _$LifecycleExampleState extends State<LifecycleExample>
    with ReactiveStateMixin<LifecycleExample> {
  late LifecycleResource _resource;
  bool _hasResource = false;
  bool _statesReady = false;

  @override
  void initState() {
    super.initState();
    _createStates();
  }

  void _createStates() {
    try {
      _resource = widget.createResource();
      _hasResource = true;
      _statesReady = true;
    } catch (_) {
      _disposeCreatedStates();
      rethrow;
    }
  }

  @override
  void didUpdateWidget(covariant LifecycleExample oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldRecreateStates(oldWidget)) {
      stopReactiveObservation();
      _disposeStates(oldWidget);
      _createStates();
    } else {
      widget.didUpdateStates(oldWidget, resource: _resource);
    }
  }

  @override
  Widget build(BuildContext context) {
    return buildReactive((context) {
      return widget.build(context, resource: _resource);
    });
  }

  void _disposeStates(LifecycleExample owner) {
    if (!_statesReady) return;
    _statesReady = false;
    try {
      owner.disposeStates(resource: _resource);
    } finally {
      _disposeCreatedStates();
    }
  }

  void _disposeCreatedStates() {
    if (_hasResource) {
      _hasResource = false;
      _resource.dispose();
    }
  }

  @override
  void dispose() {
    stopReactiveObservation();
    try {
      _disposeStates(widget);
    } finally {
      super.dispose();
    }
  }
}
