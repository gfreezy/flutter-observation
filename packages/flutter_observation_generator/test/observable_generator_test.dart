import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:flutter_observation_generator/builder.dart';
import 'package:test/test.dart';

void main() {
  test('generates generic and annotated observable properties', () async {
    const package = 'flutter_observation_generator';
    const inputPath = 'lib/model.dart';
    const outputPath = 'lib/model.observable.g.part';
    final readerWriter = TestReaderWriter(rootPackage: package);
    await readerWriter.testing.loadIsolateSources();

    final result = await testBuilder(
      observableBuilder(BuilderOptions.empty),
      {
        '$package|$inputPath': r'''
library model;

import 'package:flutter_observation/flutter_observation.dart';

part 'model.g.dart';

class BuildContext {}
class Widget {}
class SizedBox extends Widget {
  const SizedBox();
}

@observableModel
class Box<T extends Object?> extends _$Box<T> {
  Box({
    required T value,
    @observationReadOnly required String id,
    @observationIgnored int cacheHits = 0,
    @observationAlwaysNotify int revision = 0,
  }) : super(value, id, cacheHits, revision);
}

@observationWidget
class ValueCard extends _$ValueCard {
  const ValueCard({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class Resource {
  void dispose() {}
}

class Settings {
  void dispose() {}
}

@observationWidget
class CounterPage extends _$CounterPage {
  const CounterPage({super.key});

  @observableState
  Observable<int> createCount() => Observable(0);

  @observableState
  Box<int> createBox() => Box(value: 0, id: 'counter');

  @observableState
  ObservableList<int> createItems() => ObservableList();

  @plainState
  Resource createResource() => Resource();

  @PlainState(name: 'settings', autoDispose: false)
  Settings makeSettings() => Settings();

  @override
  Widget build(
    BuildContext context, {
    required Observable<int> count,
    required Box<int> box,
    required ObservableList<int> items,
    required Resource resource,
    required Settings settings,
  }) => const SizedBox();
}
''',
      },
      readerWriter: readerWriter,
      outputs: null,
      flattenOutput: true,
    );

    final output = AssetId(package, outputPath);
    expect(result.outputs, contains(output));
    final generated = readerWriter.testing.readString(output);
    expect(
      generated,
      contains(
        'abstract class _\$Box<T extends Object?> with ObservableModelMixin',
      ),
    );
    expect(generated, contains('final ObservationKey<T> _valueKey'));
    expect(generated, contains('final String _id;'));
    expect(generated, isNot(contains('set id(')));
    expect(generated, isNot(contains('_cacheHitsKey')));
    expect(generated, contains('set cacheHits(int value)'));
    expect(generated, contains('set revision(int value)'));
    expect(generated, isNot(contains('if (_revision == value) return;')));
    expect(
      generated,
      contains('abstract class _\$ValueCard extends ReactiveStatelessWidget'),
    );
    expect(
      generated,
      contains('abstract class _\$CounterPage extends StatefulWidget'),
    );
    expect(generated, isNot(contains('Observable<int> createCount();')));
    expect(generated, isNot(contains('Box<int> createBox();')));
    expect(generated, isNot(contains('ObservableList<int> createItems();')));
    expect(generated, isNot(contains('Resource createResource();')));
    expect(generated, isNot(contains('Settings makeSettings();')));
    expect(generated, contains('State<CounterPage> createState()'));
    expect(generated, contains('extends State<CounterPage>'));
    expect(generated, contains('count: _count,'));
    expect(generated, contains('box: _box,'));
    expect(generated, contains('items: _items,'));
    expect(generated, contains('resource: _resource,'));
    expect(generated, contains('settings: _settings'));
    expect(generated, isNot(contains('_count.dispose();')));
    expect(generated, contains('_resource.dispose();'));
    expect(generated, isNot(contains('_settings.dispose();')));
    expect(generated, isNot(contains('disposeIfNeeded')));
  });

  test('rejects a non-observable @observableState return type', () async {
    const package = 'flutter_observation_generator';
    final readerWriter = TestReaderWriter(rootPackage: package);
    await readerWriter.testing.loadIsolateSources();
    final logs = <String>[];

    await testBuilder(
      observableBuilder(BuilderOptions.empty),
      {
        '$package|lib/invalid_state.dart': r'''
import 'package:flutter_observation/flutter_observation.dart';

part 'invalid_state.g.dart';

class BuildContext {}
class Widget {}

class Resource {}

@observationWidget
class InvalidPage extends _$InvalidPage {
  const InvalidPage({super.key});

  @observableState
  Resource createResource() => Resource();

  @override
  Widget build(BuildContext context, {required Resource resource}) => Widget();
}
''',
      },
      readerWriter: readerWriter,
      outputs: null,
      flattenOutput: true,
      onLog: (record) => logs.add(record.message),
    );

    expect(
      logs.join('\n'),
      contains('@observableState factories must return an ObservableObject'),
    );
  });

  test('rejects an observable @plainState return type', () async {
    const package = 'flutter_observation_generator';
    final readerWriter = TestReaderWriter(rootPackage: package);
    await readerWriter.testing.loadIsolateSources();
    final logs = <String>[];

    await testBuilder(
      observableBuilder(BuilderOptions.empty),
      {
        '$package|lib/invalid_plain_state.dart': r'''
import 'package:flutter_observation/flutter_observation.dart';

part 'invalid_plain_state.g.dart';

class BuildContext {}
class Widget {}

@observationWidget
class InvalidPage extends _$InvalidPage {
  const InvalidPage({super.key});

  @plainState
  Observable<int> createCount() => Observable(0);

  @override
  Widget build(
    BuildContext context, {
    required Observable<int> count,
  }) => Widget();
}
''',
      },
      readerWriter: readerWriter,
      outputs: null,
      flattenOutput: true,
      onLog: (record) => logs.add(record.message),
    );

    expect(
      logs.join('\n'),
      contains('@plainState factories must return a non-ObservableObject'),
    );
  });
}
