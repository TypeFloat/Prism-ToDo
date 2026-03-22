# App Shell Baseline (macOS-first)

## Goal

Establish a minimal Flutter shell that behaves like a macOS desktop workspace before any broader feature expansion.

## Phase 1 shell definition

The shell is considered correct only if it centers on:

- desktop navigation
- quick capture
- Today
- Inbox

Everything else is secondary.

## Current structure

- `main.dart`: app entrypoint
- `lib/app/app.dart`: app theme and root widget
- `lib/app/screens/macos_home_page.dart`: desktop shell composition
- `lib/app/widgets/sidebar_nav.dart`: Today / Inbox navigation
- `lib/app/widgets/quick_input_bar.dart`: top quick capture area
- `lib/app/widgets/task_list_section.dart`: task list rendering
- `lib/app/models/task_item.dart`: local task model for shell iteration

## Layout rule

Use a desktop-first split view:

1. left sidebar for navigation
2. main content pane for active list
3. quick input pinned at top of content

Do not optimize this shell for small-screen layouts in Phase 1.

## Next extraction path

1. stabilize shell interactions inside app code
2. introduce state container for Today / Inbox
3. add persistence adapter behind local repository
4. extract stable shared UI and models into `packages/`
