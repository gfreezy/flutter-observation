import 'package:flutter/material.dart';
import 'package:flutter_observation/flutter_observation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_observation_example/advanced_models.dart';
import 'package:flutter_observation_example/lifecycle_example.dart';
import 'package:flutter_observation_example/main.dart';
import 'package:flutter_observation_example/user.dart';

void main() {
  testWidgets('generated model rebuilds reactive Widget by property', (
    tester,
  ) async {
    final user = User(
      name: 'Alice',
      address: Address(),
      tags: ObservableList(),
    );
    var nameBuilds = 0;
    var ageBuilds = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            _Value(read: () => user.name, onBuild: () => nameBuilds++),
            _Value(read: () => '${user.age}', onBuild: () => ageBuilds++),
          ],
        ),
      ),
    );

    user.name = 'Tom';
    await tester.pump();
    expect(find.text('Tom'), findsOneWidget);
    expect(nameBuilds, 2);
    expect(ageBuilds, 1);

    user.celebrateBirthday();
    await tester.pump();
    expect(find.text('19'), findsOneWidget);
    expect(nameBuilds, 2);
    expect(ageBuilds, 2);
  });

  testWidgets('tracks nested changes and a replaced nested model', (
    tester,
  ) async {
    final oldAddress = Address();
    final user = User(address: oldAddress, tags: ObservableList());
    var builds = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: _Value(
          read: () => '${user.address.city}, ${user.address.district}',
          onBuild: () => builds++,
        ),
      ),
    );

    oldAddress.city = 'Hangzhou';
    await tester.pump();
    expect(find.text('Hangzhou, Pudong'), findsOneWidget);
    expect(builds, 2);

    user.address = Address(city: 'Shenzhen', district: 'Nanshan');
    await tester.pump();
    expect(find.text('Shenzhen, Nanshan'), findsOneWidget);
    expect(builds, 3);

    user.replaceAddress();
    await tester.pump();
    expect(find.text('Beijing, Chaoyang'), findsOneWidget);
    expect(builds, 4);

    oldAddress.city = 'Beijing';
    await tester.pump();
    expect(builds, 4);
  });

  testWidgets('generated model observes collection mutations in place', (
    tester,
  ) async {
    final user = User(address: Address(), tags: ObservableList(['Flutter']));

    await tester.pumpWidget(
      MaterialApp(
        home: _Value(read: () => user.tags.join(', '), onBuild: () {}),
      ),
    );

    user.addTag();
    await tester.pump();
    expect(find.text('Flutter, Tag 2'), findsOneWidget);
  });

  test('generator supports generic and annotated properties', () {
    final box = Box<int>(value: 1, id: 'counter');
    expect(box, isA<ObservableObject>());
    expect(box.description, 'counter: 1');

    var derivedChanges = 0;
    withObservationTracking(
      () => box.description,
      onChange: () => derivedChanges++,
    );
    box.value = 2;
    expect(derivedChanges, 1);

    var ignoredChanges = 0;
    withObservationTracking(
      () => box.cacheHits,
      onChange: () => ignoredChanges++,
    );
    box.cacheHits++;
    expect(ignoredChanges, 0);

    var alwaysNotifyChanges = 0;
    withObservationTracking(
      () => box.revision,
      onChange: () => alwaysNotifyChanges++,
    );
    box.revision = 0;
    expect(alwaysNotifyChanges, 1);

    var externalChanges = 0;
    withObservationTracking(
      () => box.externalStatus,
      onChange: () => externalChanges++,
    );
    box.externalStatus = 'ready';
    expect(externalChanges, 1);
  });

  test('generated model exposes opt-in read-only DevTools state', () {
    final user = User(
      name: 'Alice',
      age: 20,
      address: Address(),
      tags: ObservableList(['Flutter']),
    );
    ObservationDebug.setValueInspection(true);

    try {
      Map<String, Object?> userSnapshot() {
        final sources =
            ObservationDebug.snapshot()['sources']!
                as List<Map<String, Object?>>;
        return sources.firstWhere(
          (source) => source['id'] == ObservationDebug.idFor(user),
        );
      }

      Map<String, Object?> property(String label) {
        final properties =
            userSnapshot()['properties']! as List<Map<String, Object?>>;
        return properties.firstWhere(
          (property) => property['label'].toString().contains(label),
        );
      }

      expect(
        (property('User.name')['value']! as Map<String, Object?>)['display'],
        '"Alice"',
      );
      expect(
        (property('User.age')['value']! as Map<String, Object?>)['display'],
        '20',
      );

      user.name = 'Tom';
      expect(
        (property('User.name')['value']! as Map<String, Object?>)['display'],
        '"Tom"',
      );
    } finally {
      ObservationDebug.setValueInspection(false);
    }
  });

  testWidgets('generated Widget owns, observes, and disposes @PlainState', (
    tester,
  ) async {
    final tracker = LifecycleTracker();

    await tester.pumpWidget(LifecycleExample(id: 'first', tracker: tracker));
    expect(find.text('first'), findsOneWidget);
    expect(tracker.created, 1);
    expect(tracker.disposed, 0);

    tracker.current!.label.value = 'changed';
    await tester.pump();
    expect(find.text('changed'), findsOneWidget);

    await tester.pumpWidget(LifecycleExample(id: 'first', tracker: tracker));
    expect(tracker.created, 1);
    expect(tracker.updated, 1);
    expect(tracker.disposed, 0);

    await tester.pumpWidget(LifecycleExample(id: 'second', tracker: tracker));
    expect(find.text('second'), findsOneWidget);
    expect(tracker.created, 2);
    expect(tracker.disposed, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(tracker.disposed, 2);
  });

  testWidgets('generated Widget exposes named state in Flutter diagnostics', (
    tester,
  ) async {
    await tester.pumpWidget(const ObservationExample());

    final widget = tester.widget<ObservationExample>(
      find.byType(ObservationExample),
    );
    final userState = widget.toDiagnosticsNode().getProperties().singleWhere(
      (property) => property.name == 'owned state · user',
    );

    expect(userState.toDescription(), startsWith('User #'));
  });

  testWidgets('generated cleanup continues after a dispose error', (
    tester,
  ) async {
    final tracker = CleanupTracker();

    await tester.pumpWidget(CleanupLifecycleExample(tracker: tracker));
    await tester.pumpWidget(const SizedBox.shrink());

    expect(tracker.disposed, ['second', 'first']);
    expect(tester.takeException(), isA<StateError>());
  });
}

final class _Value extends ObservationStatelessWidget {
  const _Value({required this.read, required this.onBuild});

  final String Function() read;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild();
    return Text(read());
  }
}
