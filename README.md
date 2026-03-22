# AI Native Todo

macOS-first Flutter repo for the AI Native Todo Phase 1 baseline.

## Phase 1 target

Phase 1 only focuses on a usable **macOS desktop shell** around:

- Today
- Inbox
- Quick input
- desktop navigation/layout

Out of scope for this phase:

- Android / iOS product delivery
- sync engine / account system
- calendar / projects / tags / settings-heavy flows
- deep package extraction before desktop path stabilizes

## Current status

Current verified baseline:

- Flutter dependencies resolve successfully
- static analysis passes
- widget tests pass
- macOS app builds successfully
- `flutter run -d macos` launches the app process successfully

Verified on this repo revision:

- `flutter analyze` ✅
- `flutter test` ✅
- `flutter build macos` ✅
- `flutter run -d macos` ✅ launch path reached

## Repo structure

```text
ai-todo/
├─ apps/
│  └─ mobile/
│     ├─ lib/
│     │  ├─ app/
│     │  │  ├─ app.dart
│     │  │  ├─ models/
│     │  │  │  └─ task_item.dart
│     │  │  ├─ screens/
│     │  │  │  └─ macos_home_page.dart
│     │  │  └─ widgets/
│     │  │     ├─ quick_input_bar.dart
│     │  │     ├─ sidebar_nav.dart
│     │  │     └─ task_list_section.dart
│     │  └─ main.dart
│     ├─ macos/
│     ├─ test/
│     └─ pubspec.yaml
├─ docs/
├─ packages/
└─ README.md
```

## Local development

### 1) Environment check

```bash
flutter --version
flutter doctor -v
```

Notes:

- Android SDK is not required for Phase 1 macOS work
- CocoaPods is only needed when iOS/macOS plugins are introduced

### 2) Install dependencies

Workspace root:

```bash
cd ~/Code/ai-todo
flutter pub get
```

App layer:

```bash
cd ~/Code/ai-todo/apps/mobile
flutter pub get
```

### 3) Run the macOS app

```bash
cd ~/Code/ai-todo/apps/mobile
flutter run -d macos
```

### 4) Run tests

```bash
cd ~/Code/ai-todo/apps/mobile
flutter test
```

### 5) Run static analysis

```bash
cd ~/Code/ai-todo/apps/mobile
flutter analyze
```

### 6) Build macOS release

```bash
cd ~/Code/ai-todo/apps/mobile
flutter build macos
```

Build output:

```text
apps/mobile/build/macos/Build/Products/Release/ai_todo_mobile.app
```

## Working agreement for Phase 1

Before adding new work, check one thing first:

**Does this improve the first macOS experience for Today / Inbox / quick input?**

If not, defer it.

## Immediate next engineering focus

- stabilize the macOS interaction flow
- verify main screen behavior in runtime
- expand tests around Today / Inbox / duplicate-prevention behavior
- keep architecture light until Phase 1 UX is accepted
