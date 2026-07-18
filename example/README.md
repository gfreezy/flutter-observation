# flutter_observation Example

这个应用演示统一的 Widget generator、嵌套 Observable 和可观察集合。

## 运行

```bash
cd example
flutter pub get
dart run build_runner build
flutter run -d macos
```

## Widget 结构

顶层页面通过 `@ObservableState()` 创建并拥有 User：

```dart
@ObservationWidget()
class ObservationExample extends _$ObservationExample {
  const ObservationExample({super.key});

  @ObservableState()
  User createUser() => User(
    address: Address(),
    tags: ObservableList(['Flutter']),
  );

  @override
  Widget build(BuildContext context, {required User user}) {
    // ...
  }
}
```

`UserCard` 和 `AddressCard` 使用相同的 `@ObservationWidget()`，但没有任何 state
factory，因此生成器自动为它们生成 `ObservationStatelessWidget` 基类。

## 页面功能

- 右下角按钮修改 `user.name`。
- `Birthday` 修改 `user.age`。
- `Add tag` 原地修改 `ObservableList`。
- `Change city` 修改嵌套 Address。
- `Replace address` 替换整个嵌套对象。

## DevTools Extension

以 debug/profile 模式运行 Example 后打开 Flutter DevTools，在 Extensions 中启用
`flutter_observation`。Overview 会显示 User、Address 和 ObservableList；点击页面
按钮后，可以在 Dependencies 和 Events 中查看属性依赖、通知、失效与 Widget 重建。
State 页会直接显示 name、age、address、tags 以及嵌套 Address 的当前状态；点击
`Address #id` 或 `ObservableList #id` 会展开并定位目标 source。Dependencies 中显示
实际 Widget 和对应 State，点击会跳到 Flutter Inspector。

Flutter Inspector 原生 `state` 行只显示框架 State。其下方会用独立属性行显示
Observation 业务状态：`ObservationExample` 显示
`owned state · user → User #id`；`UserCard` 和 `AddressCard` 显示最近一次 build
实际读取的 `observed state`。

悬浮 `User`、`Address` 或 `ObservableList` 行可以展开 backing-field 当前值。在下方
Console 中也可以读取 Inspector 当前选中的业务状态：

```dart
ObservationInspector.selectedStates
ObservationInspector.selectedStateOf<User>()?.age
ObservationInspector
    .selectedStateOf<ObservableList<String>>()
    ?.join(', ')
ObservationInspector.stateById<ObservableList<String>>(5)?.toList()
```

这里的 `#id` 只在当前 Dart isolate 的本次运行中唯一；hot restart 后会重新编号。

状态读取仅在 Extension 打开期间启用，是 debug/profile 下的只读操作，不会修改
业务值或产生新的依赖。

## 高级生成器示例

`lib/advanced_models.dart` 中的 `Box<T>` 演示泛型 Model、只读、忽略、强制
通知、计算属性和外部存储观察。

## 代码位置

- `lib/main.dart`：统一的 `@ObservationWidget()` / `@ObservableState()` 用法。
- `lib/main.g.dart`：生成的 Widget 生命周期代码。
- `lib/lifecycle_example.dart`：状态重建和自动释放示例。
- `lib/user.dart`：User、Address 和 ObservableList。
- `lib/advanced_models.dart`：高级 Model generator 示例。
- `test/generated_observation_test.dart`：集成测试。

## 测试

```bash
flutter test
```
