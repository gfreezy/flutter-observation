# flutter_observation DevTools extension source

This non-published Flutter web package contains the source for the read-only
DevTools extension shipped by `package:flutter_observation`.

The extension provides compact Overview, State, Dependencies, and Events tabs.
State values are read-only and enabled while the extension is open. Object,
property, Widget, and State references navigate to their matching extension
location or Flutter Inspector element.

```bash
flutter pub get
flutter analyze
flutter test
dart run devtools_extensions build_and_copy \
  --source=. \
  --dest=../../extension/devtools
dart run devtools_extensions validate --package=../..
```

The generated release assets live in `../../extension/devtools/build`. The
runtime package archive excludes this source package through its root
`.pubignore`.
