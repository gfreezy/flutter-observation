import 'package:flutter/widgets.dart';
import 'package:flutter_observation/flutter_observation.dart';

part 'lifecycle_example.g.dart';

/// Records the generated Widget lifecycle for the integration test.
final class LifecycleTracker {
  int created = 0;
  int updated = 0;
  int disposed = 0;
  LifecycleResource? current;
}

final class LifecycleResource {
  LifecycleResource(this.id, this.tracker) : label = Observable<String>(id) {
    tracker.created++;
    tracker.current = this;
  }

  final String id;
  final LifecycleTracker tracker;
  final Observable<String> label;

  void dispose() {
    tracker.disposed++;
  }
}

final class CleanupTracker {
  final List<String> disposed = [];
}

final class ThrowingCleanupResource {
  ThrowingCleanupResource(this.name, this.tracker);

  final String name;
  final CleanupTracker tracker;

  void dispose() {
    tracker.disposed.add(name);
    throw StateError('$name cleanup failed');
  }
}

@ObservationWidget()
class LifecycleExample extends _$LifecycleExample {
  const LifecycleExample({required this.id, required this.tracker, super.key});

  final String id;
  final LifecycleTracker tracker;

  @PlainState()
  LifecycleResource createResource() => LifecycleResource(id, tracker);

  @override
  Widget build(BuildContext context, {required LifecycleResource resource}) {
    return Text(resource.label.value, textDirection: TextDirection.ltr);
  }

  @override
  bool shouldRecreateStates(covariant LifecycleExample oldWidget) {
    return oldWidget.id != id;
  }

  @override
  void didUpdateStates(
    covariant LifecycleExample oldWidget, {
    required LifecycleResource resource,
  }) {
    tracker.updated++;
  }
}

@ObservationWidget()
class CleanupLifecycleExample extends _$CleanupLifecycleExample {
  const CleanupLifecycleExample({required this.tracker, super.key});

  final CleanupTracker tracker;

  @PlainState()
  ThrowingCleanupResource createFirst() {
    return ThrowingCleanupResource('first', tracker);
  }

  @PlainState()
  ThrowingCleanupResource createSecond() {
    return ThrowingCleanupResource('second', tracker);
  }

  @override
  Widget build(
    BuildContext context, {
    required ThrowingCleanupResource first,
    required ThrowingCleanupResource second,
  }) {
    return const SizedBox.shrink();
  }
}
