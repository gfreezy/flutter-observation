# flutter_observation_generator

Source generation for
[`flutter_observation`](https://github.com/gfreezy/flutter-observation).

Add the runtime as a dependency and this package with `build_runner` as a dev
dependency:

```yaml
dependencies:
  flutter_observation: ^0.2.0-dev.2

dev_dependencies:
  build_runner: ^2.15.1
  flutter_observation_generator: ^0.2.0-dev.2
```

Generate observable models and observation widgets:

```dart
@ObservableModel()
class Counter extends _$Counter {
  Counter({int super.value = 0});
}

@ObservationWidget()
class CounterPage extends _$CounterPage {
  const CounterPage({super.key});

  @ObservableState()
  Counter createCounter() => Counter();

  @override
  Widget build(BuildContext context, {required Counter counter}) {
    return Text('${counter.value}');
  }
}
```

```bash
dart run build_runner build
```

Keep the explicit type on each model super parameter. It lets the generator
resolve properties on a clean first build before the generated superclass
exists. Projects that enable the `type_init_formals` style lint should disable
it for observable model declarations.

The original constructor form remains supported per model:

```dart
@ObservableModel()
class Counter extends _$Counter {
  Counter({int value = 0}) : super(value);
}
```

Generated observable models also register release-elided backing-field readers
for the opt-in, read-only State view in the Flutter DevTools extension.
Generated Observation widgets expose each `@ObservableState()` and
`@PlainState()` factory by name as a separate Flutter Inspector Widget property.
Generated model backing fields can be expanded from those properties without
invoking observable getters or creating dependencies.
