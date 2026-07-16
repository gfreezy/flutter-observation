# flutter_observation

`flutter_observation` 是一个参考 Swift Observation 设计的 Flutter 属性观察库。

它提供两套统一的代码生成入口：

```dart
@ObservableModel()   // 声明可观察 Model
@ObservationWidget() // 声明自动观察的 Widget
```

Widget 中存在 `@PlainState()` 或 `@ObservableState()` factory 时，生成器会自动
管理状态的创建、注入、更新和释放。`@PlainState()` 明确声明普通资源，
`@ObservableState()` 明确要求状态实现 `ObservableObject`；没有 state factory
时，生成器只负责跟踪 `build()` 中读取的 Observable。

所有 annotation 统一使用大写构造形式：

| Annotation | 意图 |
| --- | --- |
| `@ObservableModel()` | 生成可观察 Model |
| `@ObservationIgnored()` | 属性不参与观察 |
| `@ObservationReadOnly()` | 属性只生成 getter |
| `@ObservationAlwaysNotify()` | 赋值时跳过相等判断 |
| `@ObservationWidget()` | 生成自动跟踪 Widget |
| `@PlainState()` | 拥有不可观察的普通资源 |
| `@ObservableState()` | 拥有且要求可观察的状态 |

需要传递选项时仍使用相同构造函数，例如
`@PlainState(name: 'resource', autoDispose: false)` 或
`@ObservableState(name: 'user', autoDispose: false)`。

## 安装

准备发布的 prerelease：

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_observation: ^0.2.0-dev.1

dev_dependencies:
  build_runner: ^2.15.1
  flutter_observation_generator: ^0.2.0-dev.1
```

```bash
flutter pub get
```

## Observable Model

```dart
import 'package:flutter_observation/flutter_observation.dart';

part 'user.g.dart';

@ObservableModel()
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

外部传入 Model 时，只使用 `@ObservationWidget()`：

```dart
part 'user_card.g.dart';

@ObservationWidget()
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

使用 `@ObservableState()` 标记返回非空 `ObservableObject` 的零参数 factory。
返回值可以是 `@ObservableModel()` Model、`Observable<T>`、Observable 集合，或
手动混入 `ObservableModelMixin` 的类型：

```dart
part 'user_page.g.dart';

@ObservationWidget()
class UserPage extends _$UserPage {
  const UserPage({super.key});

  @ObservableState()
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

普通资源使用 `@PlainState()`。它要求返回类型不能实现 `ObservableObject`，只表达
Widget 对对象的所有权和生命周期：

```dart
@PlainState()
PageResource createResource() => PageResource();
```

两者都要求 factory 是实例零参数方法，并使用相同的创建、注入、更新和释放流程。

## 多个状态

```dart
@ObservationWidget()
class UserPage extends _$UserPage {
  const UserPage({super.key});

  @ObservableState()
  User createUser() => User(name: 'Alice');

  @ObservableState()
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

`Observable<T>` 和普通 `@ObservableModel()` Model 是纯 Observation 对象，本身
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
class UserCard extends ObservationStatelessWidget {
  const UserCard({required this.user, super.key});

  final User user;

  @override
  Widget build(BuildContext context) => Text(user.name);
}
```

直接拥有一个 Model：

```dart
class UserPage extends ObservationStatefulWidget<User> {
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
class _PageState extends State<Page> with ObservationStateMixin<Page> {
  @override
  Widget build(BuildContext context) {
    return buildObserved((context) => Text(widget.user.name));
  }
}
```

跨 Widget 子树共享 Model：

```dart
ObservationScope<User>(
  value: user,
  child: const UserPage(),
);

// 在 Observer、ObservationStatelessWidget 或生成 Widget 中读取：
final user = ObservationScope.of<User>(context);
return Text(user.name);
```

## 单值 Observable

`Observable<T>` 与 `@ObservableModel()` Model 使用相同的 Registrar，不依赖
`ChangeNotifier`，因此不需要 dispose：

```dart
final count = Observable(0);

Observer(
  builder: (context) => Text('${count.value}'),
);

count.value++;
```

需要接入 `ValueListenableBuilder`、`AnimatedBuilder` 等 Flutter API 时：

```dart
final name = toValueListenable(() => user.name);

ValueListenableBuilder(
  valueListenable: name,
  builder: (context, value, child) => Text(value),
);

name.dispose();
```

`ObservationValueListenable` 拥有连续观察 subscription，单独创建时需要 dispose。

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

集合本身不注册到外部 source，因此不需要 dispose。直接索引、键和成员查询是
细粒度依赖：修改 `scores['Bob']` 不会让只读取 `scores['Alice']` 的观察者失效；
迭代、`join()`、`keys` 等整体读取仍会观察完整内容。List 的插入和删除会使受影响
位置之后的索引依赖失效。

## 嵌套 Observable

```dart
@ObservableModel()
class Address extends _$Address {
  Address({String city = 'Shanghai'}) : super(city);
}

@ObservableModel()
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

需要在首次变化前主动取消时：

```dart
final tracking = withCancellableObservationTracking(
  () => user.name,
  onChange: scheduleRender,
);

tracking.cancel();
```

连续观察：

```dart
final subscription = observe(
  () => user.name,
  onChange: print,
  onError: (error, stackTrace) => report(error, stackTrace),
  fireImmediately: true,
);

subscription.dispose();
```

默认使用 microtask 合并同步变化，也可以按下一帧刷新：

```dart
observe(
  () => user.name,
  onChange: print,
  scheduler: ObservationSchedulers.frame,
);
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

## 调试和性能基线

开发工具可以订阅属性访问和通知事件；未设置回调时不会分配事件对象：

```dart
ObservationDebug.onEvent = (event) {
  print('${event.kind}: ${event.property}');
};

// 调试结束后恢复
ObservationDebug.onEvent = null;
```

运行仓库内的性能基线：

```bash
flutter test benchmark/observation_benchmark.dart --reporter expanded
```

## Model generator 选项

```dart
@ObservableModel()
class Box<T extends Object?> extends _$Box<T> {
  Box({
    required T value,
    @ObservationReadOnly() required String id,
    @ObservationIgnored() int cacheHits = 0,
    @ObservationAlwaysNotify() int revision = 0,
  }) : super(value, id, cacheHits, revision);
}
```

- `@ObservationReadOnly()`：只生成 getter。
- `@ObservationIgnored()`：不参与跟踪。
- `@ObservationAlwaysNotify()`：跳过 `==` 去重。

## 跟踪规则

- 只有同步跟踪作用域内的读取会建立依赖。
- 每次重新构建会重新收集依赖，条件分支不再读取的属性会取消订阅。
- 普通对象不会被递归变为 Observable。
- 普通集合原地变更无法拦截，使用 Observable 集合或重新赋值。
- `@PlainState()` 必须标记实例零参数方法，并返回非 `ObservableObject`。
- `@ObservableState()` 具有相同生命周期语义，但必须返回非空
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

更多说明参见
[`example/README.md`](https://github.com/gfreezy/flutter-observation/blob/main/example/README.md)。
