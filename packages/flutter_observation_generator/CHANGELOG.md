## Unreleased

- Added typed super-parameter model declarations without repeating a
  `super(...)` initializer, while preserving the original positional
  constructor form per model.

## 0.2.0-dev.2

- Updated the runtime constraint and documentation for the DevTools-enabled
  `flutter_observation` release.
- Generated release-elided backing-field readers for opt-in DevTools state
  inspection.
- Generated named, top-level owned-state Widget diagnostics for Flutter
  Inspector.
- Enabled expandable Inspector backing-field values for generated models.

## 0.2.0-dev.1

- Added uppercase Observation annotations and explicit Plain/Observable state
  validation.
- Added build-contract, generated-name, and synchronous-disposal diagnostics.
- Made generated multi-state cleanup resilient to errors.

## 0.1.0

- Initial observable model and observation widget generators.
