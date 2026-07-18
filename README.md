# flutter_observation

`flutter_observation` 是一个参考 Swift Observation 设计的 Flutter 属性观察库。

核心能力包括：

- 属性级依赖跟踪：只读取 `user.name` 的 Widget 不会被 `user.age` 的变化刷新。
- Model 和 Widget source generation，减少手写 getter、setter 和 `State` 生命周期代码。
- 显式区分 `@ObservableState()` 与 `@PlainState()`，避免把普通资源误认为可观察状态。
- `Observable<T>`、`ObservableList`、`ObservableMap`、`ObservableSet`。
- 嵌套 Observable、多个 Widget state、自动释放和 Widget 配置同步。
- `Observer`、手写 Observation Widget、现有 `StatefulWidget` mixin。
- 基于 Flutter `InheritedWidget` 的 `ObservationScope`，用于跨子树共享全局或局部状态。
- 一次性观察、连续订阅、Stream、事务、调度器、错误处理和调试事件。
- `ValueListenable` 适配器，可接入 Flutter 自带的 Listenable 生态。

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
  flutter_observation: ^0.2.0-dev.2

dev_dependencies:
  build_runner: ^2.15.1
  flutter_observation_generator: ^0.2.0-dev.2
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

Model generator 的输入规则：

- 类必须是 concrete class，并继承生成的 `_$ClassName`。
- 必须声明 unnamed generative constructor，且至少有一个 named parameter。
- constructor parameter 就是生成属性，不要在类体中再次声明同名字段。
- 泛型和泛型 bound 会保留到生成基类。
- 默认 setter 使用 `==` 去重；赋相等值不会通知。

`part` 文件名可以自行决定，只要与当前 Dart 文件中的 `part '...g.dart'` 一致。
生成文件不要手动修改。

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

`{super.key}` 是 Dart 的 super parameter 语法：它声明一个可选命名参数 `key`，
并直接传给生成基类的构造函数。它等价于手写
`UserCard({Key? key}) : super(key: key)`，与 Observation state 无关。

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

Widget generator 会在编译期检查完整契约：

- Widget 必须是 concrete class，并声明 unnamed generative constructor。
- `build()` 的第一个参数必须是唯一的 required positional `BuildContext`。
- 每个 state factory 必须是实例、零参数方法，并声明具体的非 `void`、非 `dynamic`
  返回类型。
- 每个 state 都必须在 `build()` 中存在名称和类型完全匹配的 required named
  parameter；不能添加没有对应 factory 的 named build parameter。
- `@ObservableState()` 必须返回非空 `ObservableObject`；可空值请包装成
  `Observable<T?>`。
- `@PlainState()` 的返回类型不能实现 `ObservableObject`。这要求调用者明确表达
  “该资源本身不可观察”的意图；资源内部仍然可以持有 Observable。

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

创建中途失败时，已经创建成功的状态也会按逆序清理，然后重新抛出最初的创建
错误。释放过程中即使某个 `dispose()` 抛错，其余状态仍会继续释放，最后重新抛出
第一个错误。

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

显式名称必须是合法 Dart identifier，不能是 keyword、`context` 或 `oldWidget`，也
不能与另一个 state 重名。

生成器会在编译期检查状态的静态类型。如果它声明或继承了零参数
`dispose()`，生成代码会直接调用该方法，不需要实现公共接口。禁用自动释放：

```dart
@PlainState(autoDispose: false)
ExternalResource createSharedResource() => sharedResource;
```

`Observable<T>` 和普通 `@ObservableModel()` Model 是纯 Observation 对象，本身
不需要 dispose。持有 Controller、Timer 或 Subscription 的 Observable Model
可以公开零参数 `dispose()`，由生成器自动识别并释放。

自动识别的 `dispose()` 必须是同步的零参数 `void dispose()`。异步清理应关闭自动
释放并在生命周期钩子中启动或协调：

```dart
// 需要 import 'dart:async';
@PlainState(autoDispose: false)
AsyncResource createResource() => AsyncResource();

@override
void disposeStates({required AsyncResource resource}) {
  unawaited(resource.close());
}
```

库不要求资源实现 `Disposable` 接口；是否可自动释放完全由 factory 的静态返回
类型决定。

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

生命周期顺序如下：

1. `initState` 按声明顺序创建全部 state。
2. Widget 配置变化时，`shouldRecreateStates` 决定是保留还是替换全部 state。
3. 保留时调用 `didUpdateStates`；替换时先清理旧 state，再创建新 state。
4. 清理时先调用 `disposeStates`，然后按声明逆序执行自动 `dispose()`。
5. Widget 移除时取消属性依赖并执行同一套清理流程。

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
  bool shouldRecreateModel(covariant UserPage oldWidget) {
    return false;
  }

  @override
  void didUpdateModel(covariant UserPage oldWidget, User user) {
    // 保留 model 时同步新的 Widget 配置。
  }

  @override
  void disposeModel(User user) {
    // 手写 Widget 需要在这里显式清理；generator 才会静态检测 dispose()。
  }
}
```

`ObservationStatelessWidget` 名称对应“不拥有业务状态”，但它内部仍借助一个 Flutter
`State` 保存依赖关系；这些框架内部状态会自动管理。`ObservationStatefulWidget` 每个
实例只能注入一个 Model，多个状态和自动静态 `dispose()` 检测请使用
`@ObservationWidget()` generator。

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

`buildObserved()` 每次执行前会取消上一轮依赖并重新收集；mixin 的 `dispose()` 会
自动执行 `stopObservation()`。如果一个 `build()` 中只有局部区域需要刷新，优先
把该区域包装为 `Observer`，可以缩小重建范围。

## 全局和跨子树状态：ObservationScope

`ObservationScope<T>` 用来把一个已有实例传给后代。它不是必须的；状态也可以通过
constructor 传递、放在自定义 `InheritedWidget` 中，或者交给 Provider、Riverpod
等容器管理。

一个由根 Widget 创建、由页面读取的完整例子：

```dart
@ObservableModel()
class AppState extends _$AppState {
  AppState({String currentUserName = ''}) : super(currentUserName);
}

@ObservationWidget()
class App extends _$App {
  const App({super.key});

  @ObservableState()
  AppState createAppState() => AppState();

  @override
  Widget build(BuildContext context, {required AppState appState}) {
    return ObservationScope<AppState>(
      value: appState,
      child: const MaterialApp(home: HomePage()),
    );
  }
}

@ObservationWidget()
class HomePage extends _$HomePage {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = ObservationScope.of<AppState>(context);
    return Text(appState.currentUserName);
  }
}
```

这里的所有权与观察是分开的：

- 根 `App` 的 `@ObservableState()` 负责创建和必要时释放 `AppState`。
- `ObservationScope` 只负责传递引用，不创建、不拥有、也不释放 `value`。
- `ObservationScope.of<T>(context)` 依赖实例替换；`value` identity 改变时后代重建。
- `appState.currentUserName` 的属性级变化由 `HomePage` 的 Observation build 跟踪，
  不是由 Scope 跟踪。
- `ObservationScope.maybeOf<T>(context)` 在找不到时返回 `null`；`of<T>` 会抛出
  `FlutterError`。

`ObservationScope` 本身就是对 Flutter `InheritedWidget` 的轻量封装。它没有用
`InheritedNotifier`，因为 `ObservableObject` 不是 `Listenable`；属性依赖已经由
Observation registrar 更细粒度地维护。若 Flutter API 必须接收 `Listenable`，请
使用后面的 `toValueListenable()`。

多个全局状态可以按类型嵌套：

```dart
ObservationScope<AuthState>(
  value: auth,
  child: ObservationScope<SettingsState>(
    value: settings,
    child: const AppRouter(),
  ),
);
```

同一类型嵌套时，`of<T>` 返回距离当前 context 最近的 Scope。读取 Scope 中的属性
仍必须发生在 `Observer`、Observation Widget 或其他同步跟踪作用域内，普通
`StatelessWidget.build()` 不会因为属性变化自动刷新。

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

`value` setter 默认也使用 `==` 去重。`Observable<T?>` 可以表达一个可空但仍然可
观察的状态，尤其适合 `@ObservableState()` factory：

```dart
@ObservableState()
Observable<User?> createCurrentUser() => Observable(null);
```

需要接入 `ValueListenableBuilder`、`AnimatedBuilder` 等 Flutter API 时：

```dart
final name = toValueListenable(() => user.name);

ValueListenableBuilder(
  valueListenable: name,
  builder: (context, value, child) => Text(value),
);

// 放在 State.dispose() 或其他 owner 的清理逻辑中：
name.dispose();
```

适配器应由 `State.initState()`、dependency injection container 或其他长期 owner
创建一次，不要在每次 `build()` 时重新创建。

`ObservationValueListenable` 拥有连续观察 subscription，单独创建时需要 dispose。
它还支持 `notifyOnEqual`、`scheduler` 和 `onError`：

```dart
final label = toValueListenable(
  () => '${user.name} (${user.age})',
  notifyOnEqual: false,
  scheduler: ObservationSchedulers.frame,
  onError: reportError,
);
```

`notifyOnEqual: false` 表示依赖已经失效、但派生值仍然 `==` 时不通知 Flutter
listener。适配器只是互操作桥梁；Observation Widget 自身不需要先转成
`ValueListenable`。

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

细粒度规则：

| 类型 | 细粒度读取 | 整体读取 | 结构变化 |
| --- | --- | --- | --- |
| `ObservableList<E>` | `list[index]` | iterator、`join` 等；`length` 单独跟踪 | 插入、删除会通知受影响位置之后的索引与 length |
| `ObservableMap<K, V>` | `map[key]`、`containsKey(key)` | `keys`、values/entries 迭代 | 只通知变化的 key，并通知整体内容观察者 |
| `ObservableSet<E>` | `contains(value)`、`lookup(value)` | iterator、`length`、`toSet()` | 只通知变化的成员，并通知整体内容观察者 |

三个集合都实现对应的 Dart collection interface，可以使用常规 List、Map、Set API。
批量业务操作可以使用集合自带的 `transaction()`，让同一观察者最多失效一次：

```dart
tags.transaction((tags) {
  tags.add('Dart');
  tags.add('Observation');
});
```

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
final initialName = withObservationTracking(
  () => user.name,
  onChange: scheduleRender,
);
```

它立即返回闭包的值。`onChange` 在任意已读取属性第一次变化时同步执行一次，执行前
依赖已经解除；需要继续观察时，由调用者重新运行 tracking。这是 Widget renderer
使用的底层模式。

需要在首次变化前主动取消时：

```dart
final tracking = withCancellableObservationTracking(
  () => user.name,
  onChange: scheduleRender,
);

tracking.cancel();
```

handle 同时提供首次读取的 `value` 与 `isActive`。如果闭包没有读取任何 Observable，
就不会建立依赖，`isActive` 为 `false`。

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

`ObservationSubscription<T>` 提供：

- `value`：最近一次跟踪得到的值。
- `refresh()`：立即重新读取、重新收集依赖并返回新值，不等待 scheduler。
- `isDisposed`：订阅是否已经停止。
- `dispose()`：幂等地取消订阅并释放 registrar 引用。

每次 refresh 都会重新收集依赖，因此条件读取可以动态切换：

```dart
final subscription = observe(
  () => useNickname.value ? user.nickname : user.name,
  onChange: print,
);
```

切换到 `nickname` 后，旧的 `name` 依赖会被解除。

默认使用 microtask 合并同步变化，也可以按下一帧刷新：

```dart
observe(
  () => user.name,
  onChange: print,
  scheduler: ObservationSchedulers.frame,
);
```

可用 scheduler：

- `ObservationSchedulers.immediate`：失效时同步 refresh。
- `ObservationSchedulers.microtask`：默认值；同一 microtask 前的同步变化自然合并。
- `ObservationSchedulers.frame`：下一 Flutter frame 开始时 refresh。
- 自定义 `ObservationScheduler`：接收 callback 并自行安排执行。

初始 `read` 或启用 `fireImmediately` 时的 `onChange` 抛错，会停止订阅并把错误重新
抛出。后续 scheduler、`read` 或 `onChange` 抛错时也会先停止订阅；传入 `onError`
时错误交给它，否则保留原 stack trace 重新抛出。

异步 Stream：

```dart
await for (final name in observeStream(() => user.name)) {
  print(name);
}
```

`observeStream(read, emitInitial: true)` 返回 single-subscription Stream。默认先发送
初始值；取消 `StreamSubscription` 会取消底层 observation。refresh 出错会把错误
发送到 Stream 并关闭它。

## 事务

```dart
observationTransaction(() {
  user.name = 'Alice';
  user.age = 20;
});
```

同一观察者在一个事务中只失效一次。
事务可以嵌套，只有最外层结束时才 flush。`observationMutation()` 和 Observable
集合的批量通知内部也使用同一事务机制。

通知采用容错 fan-out：即使一个观察者回调抛错，其他观察者仍会收到通知，完成后
重新抛出第一个错误。公开的 `runObservationCallbacks()` 可用于需要相同行为的自定义
清理或通知代码。

## Flutter DevTools Extension

`flutter_observation` 从 `0.2.0-dev.2` 开始内置只读 DevTools Extension。应用以
debug 或 profile 模式运行并连接 DevTools 后，会出现 `flutter_observation` 标签页；
第一次打开需要在 DevTools 的 Extensions 对话框中启用。

无需在 `main()` 中初始化。创建第一个 `ObservationRegistrar` 时会自动注册当前
isolate 的 VM Service protocol；当前面板读取 main isolate。release 构建不会注册、
记录或保留调试数据。

Extension 提供：

- **Overview**：Observable source、被观察属性、observer、通知、失效和重建数量。
- **State**：按 source 查看生成 Model、`Observable<T>` 和可观察集合的当前状态；
  Observable 引用可点击跳到目标 source。
- **Dependencies**：当前 `Observable.property → Widget/Subscription` 依赖关系；显示
  实际 Widget 和对应 State，点击可在 Flutter Inspector 中选中该 Element。
- **Events**：依赖增删、通知、失效、重建、连续观察和事务时间线；source、property
  和 Widget 引用可跳到对应 State、Dependencies 或 Flutter Inspector。
- **Hot properties**：事件窗口内通知次数最多的属性。

跳转到 Flutter Inspector 后，原生 `state` 属性只显示真实的 Flutter `State` 类型。
Observation 业务状态会作为独立的 Widget property 行显示：生成器创建的
`@ObservableState()` / `@PlainState()` 使用 `owned state · 名称`，当前 Widget 在
最近一次 build 中读取的 Observable source 使用 `observed state`。例如：

```text
state                _$ObservationExampleState#...
owned state · user   User #16

state                _ObservationStatelessWidgetState#...
observed state       User #16
observed state       ObservableList<String> #10
```

这里的稳定 ID 与 Extension 的 State、Dependencies 页一致；业务属性的完整值仍在
Extension 的 State 页查看。Flutter Inspector 当前不向第三方 diagnostics 开放属性行
点击回调，因此跨页跳转仍从 Extension 的 Dependencies 或 Events 中发起。

将鼠标停在 `owned state` 或 `observed state` 的值上，悬浮面板会显示已注册的
backing-field 值。生成 Model 自动包含所有可观察字段；内置类型包括：

- `Observable<T>`：`Observable.value`
- `ObservableList<T>`：`contents`、`length`，以及本次实际读取的索引
- `ObservableMap<K, V>`：`contents`，以及本次实际读取的 key
- `ObservableSet<T>`：`contents`，以及本次实际读取的成员关系

也可以在 Flutter Inspector 的 Console 中读取当前选中 Widget 的真实业务对象：

```dart
// 查看当前 Widget 的全部 owned / observed state
ObservationInspector.selectedStates

// 按类型取得第一个匹配的 state
ObservationInspector.selectedStateOf<User>()

// 查看集合内容
ObservationInspector
    .selectedStateOf<ObservableList<String>>()
    ?.toList()

ObservationInspector
    .selectedStateOf<ObservableSet<String>>()
    ?.toSet()

ObservationInspector
    .selectedStateOf<ObservableMap<String, int>>()
    ?.entries
    .toList()

// 也可以直接使用 Inspector / Extension 显示的 #id
ObservationInspector.stateById(5)
ObservationInspector.stateById<ObservableList<String>>(5)?.toList()
```

`ObservationInspector` 仅用于 debug/profile 诊断；release 模式返回空结果，Console
表达式求值需要 debug 模式。取得的是实际业务对象而不是副本，因此应避免在检查时
意外修改它。

`#id` 由 `ObservationDebug.idFor()` 按对象身份分配，同一个对象在当前 Dart isolate
生命周期内保持稳定且不会复用。它不是跨 isolate 的全局 ID；hot restart、应用重启、
切换设备或连接另一个 isolate 后都可能重新从相同数字开始。反查采用弱引用，对象被
回收后 `stateById()` 会返回 `null`。

State 页始终显示当前值；打开 Extension 时自动启用读取，关闭面板后停止。状态可能
包含 token、用户资料等敏感数据。生成代码注册的是 backing-field reader，读取不会
调用 Observable getter、不会产生新依赖，也不会调用任意业务对象的 `toString()`。
字符串和集合预览有长度上限，Observable 引用只显示类型和稳定 ID；快照不会保留
业务对象的原始引用。release 构建会移除 reader 和 Inspector target 注册。

面板默认不记录每次属性读取，因为 `access` 频率通常很高；需要时可打开
`Property reads`。记录使用有界 ring buffer，默认最多 2000 条。

底层 VM Service 方法如下，主要供其他工具集成：

```text
ext.flutter_observation.getSnapshot
ext.flutter_observation.getEvents
ext.flutter_observation.setRecording
ext.flutter_observation.setValueInspection
ext.flutter_observation.selectInspectorTarget
ext.flutter_observation.clearEvents
```

开发 Extension 源码：

```bash
cd tool/flutter_observation_devtools_extension
flutter test
dart run devtools_extensions build_and_copy \
  --source=. \
  --dest=../../extension/devtools
dart run devtools_extensions validate --package=../..
```

## 调试 API 和性能基线

开发工具可以订阅属性访问和通知事件；未设置回调时不会分配事件对象：

```dart
ObservationDebug.onEvent = (event) {
  print(
    '${event.kind}: ${event.property}, observers=${event.observerCount}',
  );
};

// 调试结束后恢复
ObservationDebug.onEvent = null;
```

多个工具需要同时监听时，使用不会互相覆盖的 listener：

```dart
final handle = ObservationDebug.addListener((event) {
  print(event.toJson());
});

handle.dispose();
```

也可以直接控制有界记录器和 opt-in 状态快照：

```dart
ObservationDebug.setRecording(true, capacity: 1000);
ObservationDebug.setValueInspection(true);
final snapshot = ObservationDebug.snapshot();
final events = ObservationDebug.eventsAfter(0);
ObservationDebug.setValueInspection(false);
ObservationDebug.setRecording(false);
```

事件 kind 包括 access、依赖增删、notify、invalidate、重建、连续观察和事务；同时
包含 sequence、timestamp、稳定 ID、类型、属性与 observer label。`registrar`、
`property`、`observer` 原始引用只会传给进程内 listener，不进入序列化缓存。
未设置 listener 且记录器关闭时不会创建事件对象。

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
- `@ObservationIgnored()`：保留 getter/setter，但读取不跟踪、写入不通知。
- `@ObservationAlwaysNotify()`：跳过 `==` 去重，每次赋值都通知。

`@ObservationAlwaysNotify()` 不能与 `@ObservationIgnored()` 或
`@ObservationReadOnly()` 组合。`@ObservationReadOnly()` 只限制公开 setter；如果
属性引用的是可变 Observable 对象，仍可修改那个对象自身的属性。

## 手写 Observable Model

当 generator 不能占用 superclass slot，或属性来自外部存储时，可以混入
`ObservableModelMixin`：

```dart
class ManualCounter with ObservableModelMixin {
  ManualCounter() {
    if (!ObservationDebug.isReleaseMode) {
      observationRegisterDebugProperty(_countKey, () => _count);
    }
  }

  static final ObservationKey<int> _countKey =
      ObservationKey<int>('ManualCounter.count');

  int _count = 0;

  int get count {
    observationAccess(_countKey);
    return _count;
  }

  set count(int value) {
    if (_count == value) return;
    observationMutation(_countKey, () => _count = value);
  }

  void syncFromExternalStorage(int value) {
    _count = value;
    observationNotify(_countKey);
  }
}
```

每个属性应持有一个生命周期稳定的 `ObservationKey<T>`；key 按 identity 区分，通常
声明为 `static final`。mixin 自动提供 `ObservationRegistrar` 以及
`observationAccess`、`observationMutation`、`observationNotify`。
如果希望手写属性出现在 DevTools State 页，再通过
`observationRegisterDebugProperty()` 注册直接读取 backing field 的闭包；release
分支会被常量消除。

更底层的适配器可以直接实现 `ObservableObject` 并暴露 Registrar：

```dart
class ExternalValue implements ObservableObject {
  ExternalValue() {
    observationRegistrar.attachDebugSource(this);
    if (!ObservationDebug.isReleaseMode) {
      observationRegistrar.registerDebugProperty(_valueKey, () => _value);
    }
  }

  @override
  final observationRegistrar = ObservationRegistrar();

  final _valueKey = ObservationKey<int>('ExternalValue.value');
  int _value = 0;

  int get value {
    observationRegistrar.access(_valueKey);
    return _value;
  }

  void setValue(int value) {
    observationRegistrar.withMutation(_valueKey, () => _value = value);
  }
}
```

Registrar 还提供成对的 `willSet()` / `didSet()`、显式 `notify()`、
`removeObserver()` 和 `hasObserversFor()`。这些属于框架集成层；普通业务 Model 优先
使用 generator 或 mixin helper。

## 跟踪规则

- 只有同步跟踪作用域内的读取会建立依赖；`await` 之后的读取不属于原作用域。
- 每次重新构建会重新收集依赖，条件分支不再读取的属性会取消订阅。
- 计算 getter 不需要额外 annotation；它读取的底层 Observable 会成为实际依赖。
- 普通对象不会被递归变为 Observable。
- 普通集合原地变更无法拦截，使用 Observable 集合或重新赋值。
- 生成 setter 和 `Observable<T>` 默认使用 `==` 去重；需要每次赋值都通知时使用
  `@ObservationAlwaysNotify()`。
- `@PlainState()` 必须标记实例零参数方法，并返回非 `ObservableObject`。
- `@ObservableState()` 具有相同生命周期语义，但必须返回非空
  `ObservableObject`；可空数据请包装在 `Observable<T?>` 中。
- Widget constructor 参数属于外部配置，不会被自动释放。

## 什么时候需要 dispose

Observation 的属性注册关系由 Widget 或 subscription owner 解除；纯 Model 并不持有
后台任务，所以并不是所有对象都需要 `dispose()`。

| 对象 | 是否需要手动 dispose | 原因 |
| --- | --- | --- |
| `@ObservableModel()`、`Observable<T>` | 否 | 只保存 registrar 和属性值，没有外部订阅 |
| `ObservableList/Map/Set` | 否 | 集合自身就是 observation source，没有外部 subscription |
| 生成的无状态 Observation Widget、`Observer`、`ObservationStateMixin` | 否 | Widget 生命周期自动解除依赖 |
| generator 通过 `@PlainState()` / `@ObservableState()` 拥有的状态 | 通常否 | 静态返回类型存在同步 `void dispose()` 时自动调用；可用 `autoDispose: false` 关闭 |
| 手写 `ObservationStatefulWidget` 的 Model | 视 Model 而定 | 需要在 `disposeModel()` 中自行清理外部资源 |
| `ObservationSubscription` | 是 | 连续观察会一直持有依赖，owner 应调用 `dispose()` |
| `ObservationTrackingHandle` | 可选 | 第一次变化后自动结束；不再等待变化时可提前 `cancel()` |
| `ObservationValueListenable` | 是 | 内部拥有连续 subscription 和 `ChangeNotifier` |
| `observeStream()` 的 `StreamSubscription` | 是 | 按 Dart Stream 生命周期调用 `cancel()` |
| `ObservationScope` | 否 | 只传递引用，不拥有 `value` |

如果 Observable Model 自己持有 `Timer`、`StreamSubscription`、Controller、isolate
或平台资源，它仍然需要为这些业务资源定义清理方法。generator 可以自动调用同步
零参数 `void dispose()`，但不会猜测其他方法或异步协议。

## 公开 API 总览

下表覆盖 `package:flutter_observation/flutter_observation.dart` 当前导出的公开功能。

| 分组 | API | 用途 |
| --- | --- | --- |
| Model generation | `ObservableModel` | 标记需要生成属性观察代码的 Model |
| Model generation | `ObservationIgnored` | 属性完全绕过 observation |
| Model generation | `ObservationReadOnly` | 生成可观察 getter，不生成公开 setter |
| Model generation | `ObservationAlwaysNotify` | setter 不做相等去重 |
| Widget generation | `ObservationWidget` | 生成自动跟踪 Widget 及可选状态生命周期 |
| Widget generation | `PlainState` | 声明 Widget 拥有的非 Observable state |
| Widget generation | `ObservableState` | 声明 Widget 拥有的 Observable state |
| Widget generation | `StateAnnotation` | 两种 state annotation 的配置基类；业务代码不直接使用 |
| Observable source | `ObservableObject` | 所有可观察对象实现的最小协议 |
| Observable source | `ObservableModelMixin` | 手写可观察 Model 的 registrar 与 helper |
| Observable source | `Observable<T>` | 单个可观察值 |
| Observable source | `ObservableList<E>` | 可观察 List，支持索引级依赖 |
| Observable source | `ObservableMap<K, V>` | 可观察 Map，支持 key 级依赖 |
| Observable source | `ObservableSet<E>` | 可观察 Set，支持成员级依赖 |
| Widget integration | `Observer` | 在现有 Widget tree 中创建局部观察区域 |
| Widget integration | `ObservationStatelessWidget` | 手写不拥有业务 state 的 Observation Widget |
| Widget integration | `ObservationStatefulWidget<Model>` | 手写创建并拥有单个 Model 的 Observation Widget |
| Widget integration | `ObservationStateMixin<T>` | 为已有 Flutter `State<T>` 增加 `buildObserved()` |
| Widget integration | `ObservationScope<T>` | 通过 Flutter `InheritedWidget` 跨子树共享引用 |
| Flutter bridge | `ObservationValueListenable<T>` | 把派生 Observation 值适配成 `ValueListenable<T>` |
| Flutter bridge | `toValueListenable()` | 创建需要释放的 ValueListenable 适配器 |
| One-shot tracking | `withObservationTracking()` | 读取并监听第一次失效 |
| One-shot tracking | `withCancellableObservationTracking()` | 同上，同时返回可提前取消的 handle |
| One-shot tracking | `ObservationTrackingHandle<T>` | 保存首次值、active 状态和 `cancel()` |
| Continuous tracking | `observe()` | 创建持续重新收集依赖的订阅 |
| Continuous tracking | `ObservationSubscription<T>` | 提供 value、refresh、isDisposed、dispose |
| Continuous tracking | `observeStream()` | 创建 single-subscription 派生值 Stream |
| Scheduling | `ObservationScheduler` | 自定义连续观察 callback 调度函数类型 |
| Scheduling | `ObservationSchedulers` | immediate、microtask、frame 调度器 |
| Transaction | `observationTransaction()` | 合并一组 mutation 的重复失效 |
| Transaction | `ObservationTransaction` | 事务的底层静态接口 |
| Debugging | `ObservationDebug` | 多 listener、事件记录和依赖快照 |
| Debugging | `ObservationDebugEvent`、`ObservationDebugEventKind` | 调试事件数据和类型 |
| Debugging | `ObservationDebugListenerHandle` | 多 listener 注册的幂等释放句柄 |
| Debugging | `ObservationInspector` | 从 Console 按当前 Widget、类型或 `#id` 读取业务状态 |
| Debugging | `ObservationDevTools` | debug/profile VM Service bridge |
| Low-level integration | `ObservationDebugSnapshotProvider` | 为 DevTools 提供无业务值依赖快照的底层协议 |
| Low-level integration | `ObservationKey<T>` | 属性 identity 与调试标签 |
| Low-level integration | `ObservationRegistrar` | 属性到观察者的注册、mutation 和通知 |
| Low-level integration | `ObservationObserver` | renderer 或订阅实现的失效协议 |
| Low-level integration | `ObservationTracking` | 在同步闭包中设置当前 observer |
| Low-level integration | `runObservationCallbacks()` | 全部执行并重新抛出第一个错误的 callback fan-out |

普通应用通常只需要 annotations、Observable source 和 Widget integration。Registrar、
Observer protocol 与 `ObservationTracking.track()` 主要用于编写新的 framework
adapter；直接使用时，owner 必须在结束时通过 registrar 移除 observer。

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
