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
    with ObservationStateMixin<LifecycleExample> {
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
    } catch (error, stackTrace) {
      runObservationCallbacks([
        () => Error.throwWithStackTrace(error, stackTrace),
        _disposeCreatedStates,
      ]);
    }
  }

  @override
  void didUpdateWidget(covariant LifecycleExample oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldRecreateStates(oldWidget)) {
      stopObservation();
      _disposeStates(oldWidget);
      _createStates();
    } else {
      widget.didUpdateStates(oldWidget, resource: _resource);
    }
  }

  @override
  Widget build(BuildContext context) {
    return buildObserved((context) {
      return widget.build(context, resource: _resource);
    });
  }

  void _disposeStates(LifecycleExample owner) {
    if (!_statesReady) return;
    _statesReady = false;
    runObservationCallbacks([
      () => owner.disposeStates(resource: _resource),
      _disposeCreatedStates,
    ]);
  }

  void _disposeCreatedStates() {
    runObservationCallbacks([
      if (_hasResource)
        () {
          _hasResource = false;
          _resource.dispose();
        },
    ]);
  }

  @override
  void dispose() {
    stopObservation();
    try {
      _disposeStates(widget);
    } finally {
      super.dispose();
    }
  }
}

abstract class _$CleanupLifecycleExample extends StatefulWidget {
  const _$CleanupLifecycleExample({super.key});

  Widget build(
    BuildContext context, {
    required ThrowingCleanupResource first,
    required ThrowingCleanupResource second,
  });

  bool shouldRecreateStates(covariant _$CleanupLifecycleExample oldWidget) =>
      false;

  void didUpdateStates(
    covariant _$CleanupLifecycleExample oldWidget, {
    required ThrowingCleanupResource first,
    required ThrowingCleanupResource second,
  }) {}

  void disposeStates({
    required ThrowingCleanupResource first,
    required ThrowingCleanupResource second,
  }) {}

  @override
  State<CleanupLifecycleExample> createState() =>
      _$CleanupLifecycleExampleState();
}

final class _$CleanupLifecycleExampleState
    extends State<CleanupLifecycleExample>
    with ObservationStateMixin<CleanupLifecycleExample> {
  late ThrowingCleanupResource _first;
  bool _hasFirst = false;
  late ThrowingCleanupResource _second;
  bool _hasSecond = false;
  bool _statesReady = false;

  @override
  void initState() {
    super.initState();
    _createStates();
  }

  void _createStates() {
    try {
      _first = widget.createFirst();
      _hasFirst = true;
      _second = widget.createSecond();
      _hasSecond = true;
      _statesReady = true;
    } catch (error, stackTrace) {
      runObservationCallbacks([
        () => Error.throwWithStackTrace(error, stackTrace),
        _disposeCreatedStates,
      ]);
    }
  }

  @override
  void didUpdateWidget(covariant CleanupLifecycleExample oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldRecreateStates(oldWidget)) {
      stopObservation();
      _disposeStates(oldWidget);
      _createStates();
    } else {
      widget.didUpdateStates(oldWidget, first: _first, second: _second);
    }
  }

  @override
  Widget build(BuildContext context) {
    return buildObserved((context) {
      return widget.build(context, first: _first, second: _second);
    });
  }

  void _disposeStates(CleanupLifecycleExample owner) {
    if (!_statesReady) return;
    _statesReady = false;
    runObservationCallbacks([
      () => owner.disposeStates(first: _first, second: _second),
      _disposeCreatedStates,
    ]);
  }

  void _disposeCreatedStates() {
    runObservationCallbacks([
      if (_hasSecond)
        () {
          _hasSecond = false;
          _second.dispose();
        },
      if (_hasFirst)
        () {
          _hasFirst = false;
          _first.dispose();
        },
    ]);
  }

  @override
  void dispose() {
    stopObservation();
    try {
      _disposeStates(widget);
    } finally {
      super.dispose();
    }
  }
}
