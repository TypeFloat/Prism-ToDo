# apps/mobile

Flutter application entrypoint for the macOS-first Phase 1 shell.

## Current state

- Custom `lib/` desktop shell exists.
- `macos/` runner has **not** been generated into the repo yet.
- Minimal widget/smoke test scaffold now exists under `test/widget_test.dart`.

## Execute macOS runner bootstrap

Run from this directory:

```bash
flutter --version
flutter config --enable-macos-desktop
flutter pub get
flutter create . --platforms=macos
flutter run -d macos
```

## Expected prerequisites

Before `flutter run -d macos` can pass locally, the machine needs:

1. Flutter SDK available on PATH
2. Xcode installed
3. Xcode command line tools configured
4. CocoaPods available if Flutter doctor reports it missing
5. macOS desktop support enabled via `flutter config --enable-macos-desktop`

Recommended verification:

```bash
flutter doctor -v
xcode-select -p
```

## Important note after runner generation

`flutter create . --platforms=macos` will add generated files such as `macos/`, `.gitignore`, and platform registrants. Re-check the existing custom `lib/` shell after generation, but it should remain the source of truth for Phase 1 UI work.

After generation, keep app-specific composition here and move reusable code into `packages/`.
