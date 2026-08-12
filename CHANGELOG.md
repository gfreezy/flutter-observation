## 0.2.0-dev.3

- Added typed super-parameter model declarations without repeating a
  `super(...)` initializer, while preserving the original positional
  constructor form per model.
- Updated the generator toolchain to the newest versions compatible with the
  current stable Flutter SDK.

## 0.2.0-dev.2

- Added an automatically registered debug/profile VM Service protocol.
- Added bounded event recording for dependencies, notifications, rebuilds,
  subscriptions, and transactions without retaining application objects.
- Added weak dependency snapshots, bounded state value inspection while the
  DevTools panel is open, and multi-listener debug events.
- Added a read-only Flutter DevTools extension with overview, dependency, event,
  state, and hot-property views.
- Added cross-tab source/property navigation and direct Widget/State selection
  in Flutter Inspector.
- Added owned and observed business state as separate top-level Widget
  properties in Flutter Inspector.
- Added expandable backing-field values for generated models and every built-in
  observable collection, plus `ObservationInspector` Console access to the
  currently selected Widget's business state.
- Added weak `#id` object lookup with `ObservationInspector.stateById()` for
  direct Console inspection without extending application object lifetimes.

## 0.2.0-dev.1

- Unified public Observation naming and uppercase annotation constructors.
- Kept `PlainState` and `ObservableState` as distinct, generator-checked state
  intentions.
- Added cancellable one-shot tracking and continuous-observation error handling.
- Made observer notification and generated state cleanup resilient to errors.
- Added stricter generator diagnostics for state names, build injection, and
  asynchronous disposal.
- Added `ObservationScope`, `ObservationValueListenable`, and frame scheduling.
- Added keyed collection tracking, optional debug events, and a performance
  baseline.
- Prepared the runtime and generator packages for workspace development and
  pub.dev validation.

## 0.1.0

- Initial property-level observation runtime, Flutter widgets, observable
  collections, and source generator.
