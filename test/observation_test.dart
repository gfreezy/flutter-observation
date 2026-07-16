import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_observation/flutter_observation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Observable uses the same observation runtime as generated models', () {
    final value = Observable(1);
    final observer = _TestObserver();

    expect(value, isA<ObservableObject>());

    ObservationTracking.track(observer, () => value.value);
    value.value = 1;
    expect(observer.invalidations, 0);

    value.value = 2;
    expect(observer.invalidations, 1);

    observer.dispose();
  });

  test('registrar tracks observers independently per property', () {
    final model = _User();
    final nameObserver = _TestObserver();
    final ageObserver = _TestObserver();

    ObservationTracking.track(nameObserver, () => model.name);
    ObservationTracking.track(ageObserver, () => model.age);

    model.name = 'Tom';
    expect(nameObserver.invalidations, 1);
    expect(ageObserver.invalidations, 0);

    nameObserver.dispose();
    ageObserver.dispose();
  });

  test('tracking restores the previous observer when the body throws', () {
    final outer = _TestObserver();
    final inner = _TestObserver();

    ObservationTracking.track(outer, () {
      expect(ObservationTracking.currentObserver, same(outer));
      expect(
        () => ObservationTracking.track<void>(
          inner,
          () => throw StateError('boom'),
        ),
        throwsStateError,
      );
      expect(ObservationTracking.currentObserver, same(outer));
    });
    expect(ObservationTracking.currentObserver, isNull);
  });

  test('withObservationTracking fires once and releases dependencies', () {
    final model = _User();
    var changes = 0;

    final value = withObservationTracking(
      () => model.name,
      onChange: () => changes++,
    );
    expect(value, '');

    model.name = 'Alice';
    model.name = 'Tom';
    expect(changes, 1);
  });

  test(
    'cancellable one-shot tracking releases dependencies before a change',
    () {
      final model = _User();
      var changes = 0;
      final handle = withCancellableObservationTracking(
        () => model.name,
        onChange: () => changes++,
      );

      expect(handle.value, '');
      expect(handle.isActive, isTrue);
      handle.cancel();
      expect(handle.isActive, isFalse);

      model.name = 'Alice';
      expect(changes, 0);
    },
  );

  test('notification continues after an observer throws', () {
    final model = _User();
    final throwing = _TestObserver(
      onInvalidate: () => throw StateError('observer failed'),
    );
    final healthy = _TestObserver();

    ObservationTracking.track(throwing, () => model.name);
    ObservationTracking.track(healthy, () => model.name);

    expect(() => model.name = 'Alice', throwsStateError);
    expect(throwing.invalidations, 1);
    expect(healthy.invalidations, 1);

    throwing.dispose();
    healthy.dispose();
  });

  test(
    'runObservationCallbacks runs all callbacks and rethrows first error',
    () {
      final calls = <int>[];

      expect(
        () => runObservationCallbacks([
          () {
            calls.add(1);
            throw StateError('first');
          },
          () {
            calls.add(2);
            throw ArgumentError('second');
          },
          () => calls.add(3),
        ]),
        throwsStateError,
      );
      expect(calls, [1, 2, 3]);
    },
  );

  test('willSet and didSet expose a manual mutation boundary', () {
    final registrar = ObservationRegistrar();
    final key = ObservationKey<int>('manual.value');
    var value = 0;
    var changes = 0;

    withObservationTracking(() {
      registrar.access(key);
      return value;
    }, onChange: () => changes++);

    registrar.willSet(key);
    value = 1;
    registrar.didSet(key);
    expect(changes, 1);
  });

  test('observe continuously retracks and can be disposed', () async {
    final model = _User();
    final values = <String>[];
    final subscription = observe(
      () => model.name,
      onChange: values.add,
      fireImmediately: true,
    );

    expect(values, ['']);
    model.name = 'Alice';
    await _flushMicrotasks();
    expect(values, ['', 'Alice']);

    subscription.dispose();
    model.name = 'Tom';
    await _flushMicrotasks();
    expect(values, ['', 'Alice']);
  });

  test(
    'observe reports refresh errors and disposes its subscription',
    () async {
      final model = _User();
      Object? reportedError;
      StackTrace? reportedStackTrace;
      final subscription = observe(
        () {
          final name = model.name;
          if (name == 'bad') throw const FormatException('bad name');
          return name;
        },
        onChange: (_) {},
        onError: (error, stackTrace) {
          reportedError = error;
          reportedStackTrace = stackTrace;
        },
      );

      model.name = 'bad';
      await _flushMicrotasks();

      expect(reportedError, isA<FormatException>());
      expect(reportedStackTrace, isNotNull);
      expect(subscription.isDisposed, isTrue);
    },
  );

  test('ObservationValueListenable adapts a derived property', () async {
    final model = _User();
    final listenable = toValueListenable(() => model.name);
    var notifications = 0;
    listenable.addListener(() => notifications++);

    model.name = 'Alice';
    await _flushMicrotasks();

    expect(listenable.value, 'Alice');
    expect(notifications, 1);

    listenable.dispose();
    model.name = 'Tom';
    await _flushMicrotasks();
    expect(notifications, 1);
  });

  test('observationTransaction coalesces several property changes', () {
    final model = _User();
    var changes = 0;
    final subscription = observe(
      () => model.label,
      onChange: (_) => changes++,
      scheduler: ObservationSchedulers.immediate,
    );

    observationTransaction(() {
      model.name = 'Alice';
      model.age = 20;
    });

    expect(changes, 1);
    expect(subscription.value, 'Alice (20)');
    subscription.dispose();
  });

  test('ObservableList reports in-place mutations', () {
    final values = ObservableList<int>([1, 2]);
    var changes = 0;

    expect(values, isA<ObservableObject>());

    withObservationTracking(() => values.join(','), onChange: () => changes++);
    values.add(3);

    expect(changes, 1);
    expect(values, [1, 2, 3]);
  });

  test('ObservableList tracks direct indexes independently', () {
    final values = ObservableList<int>([1, 2]);
    var indexChanges = 0;

    withObservationTracking(() => values[0], onChange: () => indexChanges++);
    values[1] = 3;
    expect(indexChanges, 0);

    values[0] = 4;
    expect(indexChanges, 1);
  });

  test(
    'ObservableList invalidates indexes shifted by structural mutations',
    () {
      final values = ObservableList<String>(['a', 'b']);
      var indexChanges = 0;

      withObservationTracking(() => values[1], onChange: () => indexChanges++);
      values.insert(0, 'x');

      expect(indexChanges, 1);
      expect(values, ['x', 'a', 'b']);
    },
  );

  test('ObservableMap reports in-place mutations', () {
    final values = ObservableMap<String, int>({'count': 1});
    var changes = 0;

    expect(values, isA<ObservableObject>());

    withObservationTracking(() => values['count'], onChange: () => changes++);
    values['count'] = 2;

    expect(changes, 1);
    expect(values['count'], 2);
  });

  test('ObservableMap tracks direct keys independently', () {
    final values = ObservableMap<String, int>({'a': 1, 'b': 2});
    var keyChanges = 0;

    withObservationTracking(() => values['a'], onChange: () => keyChanges++);
    values['b'] = 3;
    expect(keyChanges, 0);

    values['a'] = 4;
    expect(keyChanges, 1);
  });

  test('ObservableMap iteration observes complete contents', () {
    final values = ObservableMap<String, int>({'a': 1, 'b': 2});
    var contentChanges = 0;

    withObservationTracking(
      () => values.values.join(','),
      onChange: () => contentChanges++,
    );
    values['b'] = 3;

    expect(contentChanges, 1);
  });

  test('ObservableSet reports in-place mutations', () {
    final values = ObservableSet<String>(['a']);
    var changes = 0;

    expect(values, isA<ObservableObject>());

    withObservationTracking(
      () => values.contains('b'),
      onChange: () => changes++,
    );
    values.add('b');

    expect(changes, 1);
    expect(values, contains('b'));
  });

  test('ObservableSet tracks direct membership independently', () {
    final values = ObservableSet<String>(['a']);
    var membershipChanges = 0;

    withObservationTracking(
      () => values.contains('a'),
      onChange: () => membershipChanges++,
    );
    values.add('b');
    expect(membershipChanges, 0);

    values.remove('a');
    expect(membershipChanges, 1);
  });

  test('ObservableSet supports removing itself', () {
    final values = ObservableSet<String>(['a', 'b']);
    var contentChanges = 0;

    withObservationTracking(
      () => values.join(','),
      onChange: () => contentChanges++,
    );
    values.removeAll(values);

    expect(values, isEmpty);
    expect(contentChanges, 1);
  });

  test('ObservationDebug reports tracked accesses and notifications', () {
    final value = Observable(1);
    final events = <ObservationDebugEvent>[];
    ObservationDebug.onEvent = events.add;

    try {
      withObservationTracking(() => value.value, onChange: () {});
      value.value = 2;
    } finally {
      ObservationDebug.onEvent = null;
    }

    expect(events.map((event) => event.kind), [
      ObservationDebugEventKind.access,
      ObservationDebugEventKind.notify,
    ]);
    expect(events.first.property.toString(), contains('Observable.value'));
    expect(events.first.observerCount, 1);
  });

  test('observeStream emits initial and subsequent derived values', () async {
    final model = _User();
    final values = <String>[];
    final done = Completer<void>();
    late StreamSubscription<String> streamSubscription;

    streamSubscription = observeStream(() => model.name).listen((value) {
      values.add(value);
      if (values.length == 3) {
        streamSubscription.cancel();
        done.complete();
      }
    });

    await _flushMicrotasks();
    model.name = 'Alice';
    await _flushMicrotasks();
    model.name = 'Tom';
    await done.future.timeout(const Duration(seconds: 1));

    expect(values, ['', 'Alice', 'Tom']);
  });

  test('observeStream forwards refresh errors and closes', () async {
    final model = _User();
    final values = <String>[];
    final errors = <Object>[];
    final done = Completer<void>();

    observeStream(() {
      final name = model.name;
      if (name == 'bad') throw const FormatException('bad name');
      return name;
    }).listen(values.add, onError: errors.add, onDone: done.complete);

    await _flushMicrotasks();
    model.name = 'bad';
    await done.future.timeout(const Duration(seconds: 1));

    expect(values, ['']);
    expect(errors.single, isA<FormatException>());
  });

  testWidgets(
    'ObservationStatelessWidget rebuilds after an observed property changes',
    (tester) async {
      final user = _User();
      var builds = 0;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: _NameWidget(user: user, onBuild: () => builds++),
        ),
      );
      expect(find.text(''), findsOneWidget);
      expect(builds, 1);

      user.name = 'Tom';
      await tester.pump();

      expect(find.text('Tom'), findsOneWidget);
      expect(builds, 2);
    },
  );

  testWidgets(
    'ObservationStatelessWidget coalesces changes before next frame',
    (tester) async {
      final user = _User();
      var builds = 0;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: _LabelWidget(user: user, onBuild: () => builds++),
        ),
      );

      user.name = 'Alice';
      user.age = 20;
      await tester.pump();

      expect(builds, 2);
      expect(find.text('Alice (20)'), findsOneWidget);
    },
  );

  testWidgets('ObservationStatelessWidget drops dependencies no longer read', (
    tester,
  ) async {
    final user = _User();
    final showName = Observable(true);
    var builds = 0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: _ConditionalWidget(
          user: user,
          showName: showName,
          onBuild: () => builds++,
        ),
      ),
    );

    showName.value = false;
    await tester.pump();
    expect(builds, 2);

    user.name = 'no longer observed';
    await tester.pump();
    expect(builds, 2);
  });

  testWidgets('Observer embeds a reactive region', (tester) async {
    final user = _User();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Observer(builder: (_) => Text(user.name)),
      ),
    );

    user.name = 'Alice';
    await tester.pump();
    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets('ObservationScope shares and replaces an observed model', (
    tester,
  ) async {
    final first = _User()..name = 'first';
    final second = _User()..name = 'second';

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ObservationScope<_User>(
          value: first,
          child: const _ScopedNameWidget(),
        ),
      ),
    );
    expect(find.text('first'), findsOneWidget);

    first.name = 'changed';
    await tester.pump();
    expect(find.text('changed'), findsOneWidget);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ObservationScope<_User>(
          value: second,
          child: const _ScopedNameWidget(),
        ),
      ),
    );
    expect(find.text('second'), findsOneWidget);

    first.name = 'stale';
    await tester.pump();
    expect(find.text('second'), findsOneWidget);
  });

  testWidgets('frame scheduler refreshes on the next Flutter frame', (
    tester,
  ) async {
    final model = _User();
    final values = <String>[];
    final subscription = observe(
      () => model.name,
      onChange: values.add,
      scheduler: ObservationSchedulers.frame,
    );

    model.name = 'Alice';
    expect(values, isEmpty);
    await tester.pump();
    expect(values, ['Alice']);
    subscription.dispose();
  });

  testWidgets('ObservationStateMixin tracks an existing State', (tester) async {
    final user = _User();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: _MixinWidget(user: user),
      ),
    );

    user.name = 'Alice';
    await tester.pump();
    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets(
    'ObservationStatefulWidget owns, updates, recreates, and disposes its model',
    (tester) async {
      final lifecycle = _ViewLifecycle();
      const key = ValueKey('reactive-view');

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: _UserView(
            key: key,
            initialName: 'Alice',
            lifecycle: lifecycle,
          ),
        ),
      );
      expect(lifecycle.created, 1);
      expect(find.text('Alice'), findsOneWidget);

      lifecycle.model!.name = 'Tom';
      await tester.pump();
      expect(find.text('Tom'), findsOneWidget);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: _UserView(
            key: key,
            initialName: 'Alice',
            lifecycle: lifecycle,
          ),
        ),
      );
      expect(lifecycle.created, 1);
      expect(lifecycle.updated, 1);
      expect(find.text('Tom'), findsOneWidget);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: _UserView(key: key, initialName: 'Bob', lifecycle: lifecycle),
        ),
      );
      expect(lifecycle.created, 2);
      expect(lifecycle.disposed, 1);
      expect(find.text('Bob'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      expect(lifecycle.disposed, 2);
    },
  );
}

Future<void> _flushMicrotasks() => Future<void>.delayed(Duration.zero);

final class _TestObserver implements ObservationObserver {
  _TestObserver({this.onInvalidate});

  final void Function()? onInvalidate;
  int invalidations = 0;
  final Set<ObservationRegistrar> _registrars = {};

  @override
  void invalidate() {
    invalidations++;
    onInvalidate?.call();
  }

  @override
  void registerRegistrar(ObservationRegistrar registrar) {
    _registrars.add(registrar);
  }

  void dispose() {
    for (final registrar in _registrars) {
      registrar.removeObserver(this);
    }
    _registrars.clear();
  }
}

final class _User with ObservableModelMixin {
  static final ObservationKey<String> _nameKey = ObservationKey('User.name');
  static final ObservationKey<int> _ageKey = ObservationKey('User.age');

  String _name = '';
  int _age = 18;

  String get name {
    observationAccess(_nameKey);
    return _name;
  }

  set name(String value) {
    if (_name == value) return;
    observationMutation(_nameKey, () => _name = value);
  }

  int get age {
    observationAccess(_ageKey);
    return _age;
  }

  set age(int value) {
    if (_age == value) return;
    observationMutation(_ageKey, () => _age = value);
  }

  String get label => '$name ($age)';
}

final class _NameWidget extends ObservationStatelessWidget {
  const _NameWidget({required this.user, required this.onBuild});

  final _User user;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild();
    return Text(user.name);
  }
}

final class _LabelWidget extends ObservationStatelessWidget {
  const _LabelWidget({required this.user, required this.onBuild});

  final _User user;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild();
    return Text(user.label);
  }
}

final class _ScopedNameWidget extends ObservationStatelessWidget {
  const _ScopedNameWidget();

  @override
  Widget build(BuildContext context) {
    return Text(ObservationScope.of<_User>(context).name);
  }
}

final class _ConditionalWidget extends ObservationStatelessWidget {
  const _ConditionalWidget({
    required this.user,
    required this.showName,
    required this.onBuild,
  });

  final _User user;
  final Observable<bool> showName;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild();
    return Text(showName.value ? user.name : 'hidden');
  }
}

final class _MixinWidget extends StatefulWidget {
  const _MixinWidget({required this.user});

  final _User user;

  @override
  State<_MixinWidget> createState() => _MixinWidgetState();
}

final class _MixinWidgetState extends State<_MixinWidget>
    with ObservationStateMixin<_MixinWidget> {
  @override
  Widget build(BuildContext context) {
    return buildObserved((_) => Text(widget.user.name));
  }
}

final class _ViewLifecycle {
  int created = 0;
  int updated = 0;
  int disposed = 0;
  _User? model;
}

final class _UserView extends ObservationStatefulWidget<_User> {
  const _UserView({
    required this.initialName,
    required this.lifecycle,
    super.key,
  });

  final String initialName;
  final _ViewLifecycle lifecycle;

  @override
  _User createModel() {
    lifecycle.created++;
    final model = _User()..name = initialName;
    lifecycle.model = model;
    return model;
  }

  @override
  Widget build(BuildContext context, _User model) => Text(model.name);

  @override
  bool shouldRecreateModel(covariant _UserView oldWidget) {
    return oldWidget.initialName != initialName;
  }

  @override
  void didUpdateModel(covariant _UserView oldWidget, _User model) {
    lifecycle.updated++;
  }

  @override
  void disposeModel(_User model) {
    lifecycle.disposed++;
  }
}
