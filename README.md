# flutter_observation

`flutter_observation` 是一个参考 Swift Observation 设计的 Flutter 属性观察库。

它提供两套统一的代码生成入口：

```dart
@observableModel  // 声明可观察 Model
@observationWidget  // 声明自动观察的 Widget
```

Widget 中存在 `@plainState` 或 `@observableState` factory 时，生成器会自动管理
状态的创建、注入、更新和释放。`@plainState` 只接受非 Observable，
`@observableState` 只接受 Observable；没有 state factory 时，生成器只负责
跟踪 `build()` 中读取的 Observable。

所有无参数注解都有小写简写：

| 简写 | 完整写法 |
| --- | --- |
| `@observableModel` | `@ObservableModel()` |
| `@observationIgnored` | `@ObservationIgnored()` |
| `@observationReadOnly` | `@ObservationReadOnly()` |
| `@observationAlwaysNotify` | `@ObservationAlwaysNotify()` |
| `@observationWidget` | `@ObservationWidget()` |
| `@plainState` | `@PlainState()` |
| `@observableState` | `@ObservableState()` |

需要传递选项时使用完整构造函数，例如
`@PlainState(name: 'resource', autoDispose: false)` 或
`@ObservableState(name: 'user', autoDispose: false)`。

## 安装

当前仓库使用本地路径：

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_observation:
    path: ../flutter-observation

dev_dependencies:
  build_runner: ^2.15.1
  flutter_observation_generator:
    path: ../flutter-observation/packages/flutter_observation_generator
```

```bash
flutter pub get
```

## Observable Model

```dart
import 'package:flutter_observation/flutter_observation.dart';

part 'user.g.dart';

@observableModel
class User extends _$User {
  User({String name = '', int age = 18}) : super(name, age);

  void celebrateBirthday() => age++;

  String get label => '$name ($age)';
}
```

构造参数定义生成属性的名称、类型和初始值。普通计算 getter 会继续跟踪它读取的
底层属性，因此 `label` 会自动依赖 `name` 和 `age`。

生成代码：

```bash
dart run build_runner build
```

开发期间可以持续监听：

```bash
dart run build_runner watch
```

## 无内部状态的响应式 Widget

外部传入 Model 时，只使用 `@observationWidget`：

```dart
part 'user_card.g.dart';

@observationWidget
class UserCard extends _$UserCard {
  const UserCard({
    required this.user,
    super.key,
  });

  final User user;

  @override
  Widget build(BuildContext context) {
    return Text(user.name);
  }
}
```

`build()` 中读取的属性会自动建立依赖。`user.name` 变化时组件重建，其他没有被
读取的属性不会触发它。

## 拥有内部状态的响应式 Widget

使用 `@observableState` 标记返回非空 `ObservableObject` 的零参数 factory。
返回值可以是 `@observableModel` Model、`Observable<T>`、Observable 集合，或
手动混入 `ObservableModelMixin` 的类型：

```dart
part 'user_page.g.dart';

@observationWidget
class UserPage extends _$UserPage {
  const UserPage({super.key});

  @observableState
  User createUser() => User(name: 'Alice');

  @override
  Widget build(
    BuildContext context, {
    required User user,
  }) {
    return Scaffold(
      body: Text(user.name),
      floatingActionButton: FloatingActionButton(
        onPressed: () => user.name = 'Tom',
      ),
    );
  }
}
```

状态 factory 由注解识别，不是生成父类中的抽象方法，因此不需要 `@override`。
`build()` 仍然是 Widget 的构建契约，继续使用 `@override`。

生成器会：

- 在 `initState()` 中调用 `createUser()` 一次。
- 把方法名 `createUser` 转成状态名 `user`。
- 通过命名参数把 `user` 注入 `build()`。
- 跟踪 `build()` 中的 Observable 读取。
- Widget 移除时自动调用状态类型公开的零参数 `dispose()`。

普通资源使用 `@plainState`。它要求返回类型不能实现 `ObservableObject`，只表达
Widget 对对象的所有权和生命周期：

```dart
@plainState
PageResource createResource() => PageResource();
```

两者都要求 factory 是实例零参数方法，并使用相同的创建、注入、更新和释放流程。

## 多个状态

```dart
@observationWidget
class UserPage extends _$UserPage {
  const UserPage({super.key});

  @observableState
  User createUser() => User(name: 'Alice');

  @observableState
  Settings createSettings() => Settings();

  @override
  Widget build(
    BuildContext context, {
    required User user,
    required Settings settings,
  }) {
    return Text('${user.name} / ${settings.themeName}');
  }
}
```

每个 factory 只执行一次，并按照声明顺序创建、逆序释放。

注意：一个 state factory 不应调用另一个 state factory，因为那会创建第二个实例。
有关联的状态应组合成页面 Model，或者在普通 Widget 配置中共享依赖。

## 自定义状态名称和释放行为

默认规则是去掉 `create` 前缀并把首字母改成小写：

```text
createUser     → user
createSettings → settings
counter        → counter
```

可以显式指定名称：

```dart
@ObservableState(name: 'currentUser')
User makeUser() => User(name: 'Alice');
```

生成器会在编译期检查状态的静态类型。如果它声明或继承了零参数
`dispose()`，生成代码会直接调用该方法，不需要实现公共接口。禁用自动释放：

```dart
@PlainState(autoDispose: false)
ExternalResource createSharedResource() => sharedResource;
```

`Observable<T>` 和普通 `@observableModel` Model 是纯 Observation 对象，本身
不需要 dispose。持有 Controller、Timer 或 Subscription 的 Observable Model
可以公开零参数 `dispose()`，由生成器自动识别并释放。

## Widget 配置变化

默认会保留已创建状态。需要根据 Widget 参数重新创建全部状态时：

```dart
@override
bool shouldRecreateStates(covariant UserPage oldWidget) {
  return oldWidget.userId != userId;
}
```

保留状态但需要同步新配置时：

```dart
@override
void didUpdateStates(
  covariant UserPage oldWidget, {
  required User user,
}) {
  if (oldWidget.userId != userId) {
    user.load(userId);
  }
}
```

没有标准 `dispose()`，或者需要额外清理逻辑时，可以使用自定义钩子：

```dart
@override
void disposeStates({required User user}) {
  // 在这里释放 User 持有的其他外部资源。
}
```

不要在 `disposeStates()` 中再次调用生成器已经自动处理的 `dispose()`。

## 不使用 Widget generator

只消费外部 Model：

```dart
class UserCard extends ReactiveStatelessWidget {
  const UserCard({required this.user, super.key});

  final User user;

  @override
  Widget build(BuildContext context) => Text(user.name);
}
```

直接拥有一个 Model：

```dart
class UserPage extends ReactiveStatefulWidget<User> {
  const UserPage({super.key});

  @override
  User createModel() => User(name: 'Alice');

  @override
  Widget build(BuildContext context, User user) => Text(user.name);

  @override
  void disposeModel(User user) {
    // 手写 Widget 需要在这里显式清理；generator 才会静态检测 dispose()。
  }
}
```

## 嵌入现有 Widget

局部观察：

```dart
Observer(
  builder: (context) => Text(user.name),
)
```

已有 `StatefulWidget`：

```dart
class _PageState extends State<Page> with ReactiveStateMixin<Page> {
  @override
  Widget build(BuildContext context) {
    return buildReactive((context) => Text(widget.user.name));
  }
}
```

## 单值 Observable

`Observable<T>` 与 `@observableModel` Model 使用相同的 Registrar，不依赖
`ChangeNotifier`，因此不需要 dispose：

```dart
final count = Observable(0);

Observer(
  builder: (context) => Text('${count.value}'),
);

count.value++;
```

## 可观察集合

Dart 普通集合的原地变更不经过属性 setter。需要观察内容时使用：

```dart
final tags = ObservableList<String>(['Flutter']);
final scores = ObservableMap<String, int>({'Alice': 10});
final selected = ObservableSet<String>();
```

```dart
tags.add('Dart');
scores['Alice'] = 11;
selected.add('Alice');
```

集合本身不注册到外部 source，因此不需要 dispose。

## 嵌套 Observable

```dart
@observableModel
class Address extends _$Address {
  Address({String city = 'Shanghai'}) : super(city);
}

@observableModel
class User extends _$User {
  User({required Address address}) : super(address);
}
```

读取 `user.address.city` 会同时订阅外层引用和内层属性。修改 `city` 或替换整个
`address` 都会刷新；重建后会取消旧对象依赖。

## 一次性、连续和异步观察

一次性观察，在第一次变化后自动解除：

```dart
withObservationTracking(
  () => user.name,
  onChange: scheduleRender,
);
```

连续观察：

```dart
final subscription = observe(
  () => user.name,
  onChange: print,
  fireImmediately: true,
);

subscription.dispose();
```

异步 Stream：

```dart
await for (final name in observeStream(() => user.name)) {
  print(name);
}
```

## 事务

```dart
observationTransaction(() {
  user.name = 'Alice';
  user.age = 20;
});
```

同一观察者在一个事务中只失效一次。

## Model generator 选项

```dart
@observableModel
class Box<T extends Object?> extends _$Box<T> {
  Box({
    required T value,
    @observationReadOnly required String id,
    @observationIgnored int cacheHits = 0,
    @observationAlwaysNotify int revision = 0,
  }) : super(value, id, cacheHits, revision);
}
```

- `@observationReadOnly`：只生成 getter。
- `@observationIgnored`：不参与跟踪。
- `@observationAlwaysNotify`：跳过 `==` 去重。

## 跟踪规则

- 只有同步跟踪作用域内的读取会建立依赖。
- 每次重新构建会重新收集依赖，条件分支不再读取的属性会取消订阅。
- 普通对象不会被递归变为 Observable。
- 普通集合原地变更无法拦截，使用 Observable 集合或重新赋值。
- `@plainState` 必须标记实例零参数方法，并返回非 `ObservableObject`。
- `@observableState` 具有相同生命周期语义，但必须返回非空
  `ObservableObject`；可空数据请包装在 `Observable<T?>` 中。
- Widget constructor 参数属于外部配置，不会被自动释放。

## 运行 Example

```bash
cd example
flutter pub get
dart run build_runner build
flutter run -d macos
```

```bash
# runtime
flutter test

# Example
cd example && flutter test

# generator golden
cd packages/flutter_observation_generator && dart test
```

更多说明参见 [`example/README.md`](example/README.md)。
