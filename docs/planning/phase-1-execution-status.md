# Phase 1 Execution Status (macOS-first)

## Repository reality check

Real working repository: `/Users/return0/Code/ai-todo`

Current layout is a scaffold, not yet a fully generated runnable Flutter desktop project:

- root `pubspec.yaml`: workspace-level placeholder only
- runnable app candidate: `apps/mobile/`
- app code exists under `apps/mobile/lib/`
- docs exist under `docs/`
- package placeholders exist under `packages/`
- `.git/` was not found from file inspection in this round
- `macos/` runner was not found in this round

## Phase 1 minimum loop implemented in app code

Implemented in `apps/mobile/lib/app/`:

1. Quick Input always captures into **Inbox**
2. new items carry an **AI parsing placeholder summary**
3. Inbox items can be **Confirm parse**
4. Inbox items can be **Move to Today**
5. Today items remain toggleable as done / todo

Flow now matches:

`Quick Input → Inbox → Confirm parse → Move to Today → Today`

## Environment gap

The following Flutter/macOS pieces still appear missing or unverified:

- generated Flutter app files at repo root are absent
- `apps/mobile/macos/` runner is absent
- local Flutter SDK availability is unverified from file tools

Suggested commands for local verification:

```bash
cd /Users/return0/Code/ai-todo/apps/mobile
flutter --version
flutter pub get
flutter create . --platforms=macos
flutter run -d macos
```

If `flutter create .` regenerates files, re-check custom files under `lib/app/` afterward.

## Recommended git slices

Suggested commit split:

1. `feat: close phase-1 inbox-to-today interaction loop`
2. `docs: record repo reality and macos environment gap`

## Next dev step

1. generate and verify the macOS runner
2. add lightweight local state container / repository abstraction
3. add keyboard-first affordances for quick capture and moving items
4. decide whether `apps/mobile` should be renamed later to reduce semantic confusion
