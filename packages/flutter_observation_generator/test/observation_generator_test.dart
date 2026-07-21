import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:flutter_observation_generator/flutter_observation_generator.dart';
import 'package:test/test.dart';

void main() {
  test('generates observable models and observation widgets', () async {
    const package = 'flutter_observation_generator';
    const inputPath = 'lib/model.dart';
    const outputPath = 'lib/model.observation.g.part';
    final readerWriter = TestReaderWriter(rootPackage: package);
    await readerWriter.testing.loadIsolateSources();

    final result = await testBuilder(
      observationBuilder(BuilderOptions.empty),
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

@ObservableModel()
class Box<T extends Object?> extends _$Box<T> {
  Box({
    required T super.value,
    @ObservationReadOnly() required String super.id,
    @ObservationIgnored() int super.cacheHits = 0,
    @ObservationAlwaysNotify() int super.revision = 0,
  });
}

@ObservableModel()
class LegacyModel extends _$LegacyModel {
  LegacyModel({String title = '', int count = 0}) : super(title, count);
}

@ObservationWidget()
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

@ObservationWidget()
class CounterPage extends _$CounterPage {
  const CounterPage({super.key});

  @ObservableState()
  Observable<int> createCount() => Observable(0);

  @ObservableState()
  Box<int> createBox() => Box(value: 0, id: 'counter');

  @ObservableState()
  ObservableList<int> createItems() => ObservableList();

  @PlainState()
  Resource createResource() => Resource();

  @PlainState()
  Resource createSecondaryResource() => Resource();

  @PlainState(name: 'settings', autoDispose: false)
  Settings makeSettings() => Settings();

  @override
  Widget build(
    BuildContext context, {
    required Observable<int> count,
    required Box<int> box,
    required ObservableList<int> items,
    required Resource resource,
    required Resource secondaryResource,
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
    expect(
      generated,
      matches(
        RegExp(
          r'_\$Box\(\{\s*required T value,\s*required String id,\s*'
          r'required int cacheHits,\s*required int revision,\s*\}\)',
        ),
      ),
    );
    expect(
      generated,
      contains('abstract class _\$LegacyModel with ObservableModelMixin'),
    );
    expect(
      generated,
      matches(RegExp(r'_\$LegacyModel\(String title,\s*int count\)')),
    );
    expect(generated, contains('final ObservationKey<T> _valueKey'));
    expect(
      generated,
      contains('observationRegisterDebugProperty(_valueKey, () => _value);'),
    );
    expect(
      generated,
      isNot(
        contains(
          'observationRegisterDebugProperty(_cacheHitsKey, () => _cacheHits);',
        ),
      ),
    );
    expect(generated, contains('final String _id;'));
    expect(generated, isNot(contains('set id(')));
    expect(generated, isNot(contains('_cacheHitsKey')));
    expect(generated, contains('set cacheHits(int value)'));
    expect(generated, contains('set revision(int value)'));
    expect(generated, isNot(contains('if (_revision == value) return;')));
    expect(
      generated,
      contains(
        'abstract class _\$ValueCard extends ObservationStatelessWidget',
      ),
    );
    expect(
      generated,
      matches(
        RegExp(
          r'abstract class _\$CounterPage extends StatefulWidget\s+'
          r'with ObservationWidgetDiagnostics',
        ),
      ),
    );
    expect(generated, isNot(contains('Observable<int> createCount();')));
    expect(generated, isNot(contains('Box<int> createBox();')));
    expect(generated, isNot(contains('ObservableList<int> createItems();')));
    expect(generated, isNot(contains('Resource createResource();')));
    expect(generated, isNot(contains('Resource createSecondaryResource();')));
    expect(generated, isNot(contains('Settings makeSettings();')));
    expect(generated, contains('State<CounterPage> createState()'));
    expect(generated, contains('extends State<CounterPage>'));
    expect(
      generated,
      contains("if (_hasCount) (name: 'count', value: _count),"),
    );
    expect(
      generated,
      contains("if (_hasResource) (name: 'resource', value: _resource),"),
    );
    expect(generated, contains('count: _count,'));
    expect(generated, contains('box: _box,'));
    expect(generated, contains('items: _items,'));
    expect(generated, contains('resource: _resource,'));
    expect(generated, contains('secondaryResource: _secondaryResource,'));
    expect(generated, contains('settings: _settings'));
    expect(generated, isNot(contains('_count.dispose();')));
    expect(generated, contains('_resource.dispose();'));
    expect(generated, contains('_secondaryResource.dispose();'));
    expect(
      generated.indexOf('_secondaryResource.dispose();'),
      lessThan(generated.indexOf('_resource.dispose();')),
    );
    expect(generated, contains('runObservationCallbacks(['));
    expect(generated, isNot(contains('_settings.dispose();')));
    expect(generated, isNot(contains('disposeIfNeeded')));
  });

  test('rejects untyped super parameters on a clean build', () async {
    final logs = await _generatorLogs('untyped_model.dart', r'''
import 'package:flutter_observation/flutter_observation.dart';

part 'untyped_model.g.dart';

@ObservableModel()
class InvalidModel extends _$InvalidModel {
  InvalidModel({super.value = 0});
}
''');

    expect(
      logs,
      contains(
        'Observable model super parameters must declare an explicit type',
      ),
    );
  });

  test('rejects a non-observable @ObservableState return type', () async {
    const package = 'flutter_observation_generator';
    final readerWriter = TestReaderWriter(rootPackage: package);
    await readerWriter.testing.loadIsolateSources();
    final logs = <String>[];

    await testBuilder(
      observationBuilder(BuilderOptions.empty),
      {
        '$package|lib/invalid_state.dart': r'''
import 'package:flutter_observation/flutter_observation.dart';

part 'invalid_state.g.dart';

class BuildContext {}
class Widget {}

class Resource {}

@ObservationWidget()
class InvalidPage extends _$InvalidPage {
  const InvalidPage({super.key});

  @ObservableState()
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
      contains('@ObservableState() factories must return an ObservableObject'),
    );
  });

  test('rejects an observable @PlainState return type', () async {
    const package = 'flutter_observation_generator';
    final readerWriter = TestReaderWriter(rootPackage: package);
    await readerWriter.testing.loadIsolateSources();
    final logs = <String>[];

    await testBuilder(
      observationBuilder(BuilderOptions.empty),
      {
        '$package|lib/invalid_plain_state.dart': r'''
import 'package:flutter_observation/flutter_observation.dart';

part 'invalid_plain_state.g.dart';

class BuildContext {}
class Widget {}

@ObservationWidget()
class InvalidPage extends _$InvalidPage {
  const InvalidPage({super.key});

  @PlainState()
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
      contains('@PlainState() factories must return a non-ObservableObject'),
    );
  });

  test('rejects state names that cannot be generated safely', () async {
    final logs = await _generatorLogs('invalid_state_name.dart', r'''
import 'package:flutter_observation/flutter_observation.dart';

part 'invalid_state_name.g.dart';

class BuildContext {}
class Widget {}
class Resource {}

@ObservationWidget()
class InvalidPage extends _$InvalidPage {
  const InvalidPage({super.key});

  @PlainState(name: 'switch')
  Resource createResource() => Resource();

  @override
  Widget build(BuildContext context) => Widget();
}
''');

    expect(logs, contains('cannot be used as a generated state parameter'));
  });

  test('rejects a build method missing an injected state parameter', () async {
    final logs = await _generatorLogs('invalid_build.dart', r'''
import 'package:flutter_observation/flutter_observation.dart';

part 'invalid_build.g.dart';

class BuildContext {}
class Widget {}
class Resource {}

@ObservationWidget()
class InvalidPage extends _$InvalidPage {
  const InvalidPage({super.key});

  @PlainState()
  Resource createResource() => Resource();

  @override
  Widget build(BuildContext context) => Widget();
}
''');

    expect(logs, contains('required Resource resource'));
  });

  test('rejects async automatic disposal', () async {
    final logs = await _generatorLogs('async_dispose.dart', r'''
import 'package:flutter_observation/flutter_observation.dart';

part 'async_dispose.g.dart';

class BuildContext {}
class Widget {}
class Resource {
  Future<void> dispose() async {}
}

@ObservationWidget()
class InvalidPage extends _$InvalidPage {
  const InvalidPage({super.key});

  @PlainState()
  Resource createResource() => Resource();

  @override
  Widget build(
    BuildContext context, {
    required Resource resource,
  }) => Widget();
}
''');

    expect(
      logs,
      contains('Automatically managed dispose() methods must return void'),
    );
  });
}

Future<String> _generatorLogs(String path, String source) async {
  const package = 'flutter_observation_generator';
  final readerWriter = TestReaderWriter(rootPackage: package);
  await readerWriter.testing.loadIsolateSources();
  final logs = <String>[];

  await testBuilder(
    observationBuilder(BuilderOptions.empty),
    {'$package|lib/$path': source},
    readerWriter: readerWriter,
    outputs: null,
    flattenOutput: true,
    onLog: (record) => logs.add(record.message),
  );
  return logs.join('\n');
}
