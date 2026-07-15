import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_observation/flutter_observation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Observable uses the same observation runtime as generated models', () {
    final value = Observable(1);
    final observer = _TestObserver();

    expect(value, isA<ObservableObject>());

    ReactiveTracking.track(observer, () => value.value);
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

    ReactiveTracking.track(nameObserver, () => model.name);
    ReactiveTracking.track(ageObserver, () => model.age);

    model.name = 'Tom';
    expect(nameObserver.invalidations, 1);
    expect(ageObserver.invalidations, 0);

    nameObserver.dispose();
    ageObserver.dispose();
  });

  test('tracking restores the previous observer when the body throws', () {
    final outer = _TestObserver();
    final inner = _TestObserver();

    ReactiveTracking.track(outer, () {
      expect(ReactiveTracking.currentObserver, same(outer));
      expect(
        () =>
            ReactiveTracking.track<void>(inner, () => throw StateError('boom')),
        throwsStateError,
      );
      expect(ReactiveTracking.currentObserver, same(outer));
    });
    expect(ReactiveTracking.currentObserver, isNull);
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

  test('ObservableMap reports in-place mutations', () {
    final values = ObservableMap<String, int>({'count': 1});
    var changes = 0;

    expect(values, isA<ObservableObject>());

    withObservationTracking(() => values['count'], onChange: () => changes++);
    values['count'] = 2;

    expect(changes, 1);
    expect(values['count'], 2);
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

  testWidgets(
    'ReactiveStatelessWidget rebuilds after an observed property changes',
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

  testWidgets('ReactiveStatelessWidget coalesces changes before next frame', (
    tester,
  ) async {
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
  });

  testWidgets('ReactiveStatelessWidget drops dependencies no longer read', (
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

  testWidgets('ReactiveStateMixin tracks an existing State', (tester) async {
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
    'ReactiveStatefulWidget owns, updates, recreates, and disposes its model',
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

final class _TestObserver implements ReactiveObserver {
  int invalidations = 0;
  final Set<ObservationRegistrar> _registrars = {};

  @override
  void invalidate() => invalidations++;

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

final class _NameWidget extends ReactiveStatelessWidget {
  const _NameWidget({required this.user, required this.onBuild});

  final _User user;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild();
    return Text(user.name);
  }
}

final class _LabelWidget extends ReactiveStatelessWidget {
  const _LabelWidget({required this.user, required this.onBuild});

  final _User user;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild();
    return Text(user.label);
  }
}

final class _ConditionalWidget extends ReactiveStatelessWidget {
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
    with ReactiveStateMixin<_MixinWidget> {
  @override
  Widget build(BuildContext context) {
    return buildReactive((_) => Text(widget.user.name));
  }
}

final class _ViewLifecycle {
  int created = 0;
  int updated = 0;
  int disposed = 0;
  _User? model;
}

final class _UserView extends ReactiveStatefulWidget<_User> {
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
