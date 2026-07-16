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
