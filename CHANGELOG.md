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
