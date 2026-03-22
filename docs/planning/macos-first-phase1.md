# macOS-first Phase 1 Implementation Note

## Why this reset

Previous wording implied a Flutter-first multi-platform bootstrap. That is no longer the execution strategy for Phase 1.

The project now optimizes for the fastest path to a credible desktop-first MVP on macOS.

## Product slice for Phase 1

### Primary user intent
- quickly capture tasks
- review Inbox
- focus on Today

### Minimum UI map
- left sidebar: Today / Inbox
- top work area: quick input
- main pane: selected list
- optional right-side details: deferred

## Directory note

Current app entry remains in `apps/mobile` for continuity, but the feature slice under `lib/app/` should be read as a **macOS-first desktop shell**, not a mobile-first screen tree.

## Implementation boundary

### Build now
- desktop shell layout
- quick entry interaction
- task row state change
- empty states and basic counts

### Build later
- persistence
- keyboard shortcut refinement
- drag/drop and menu-bar integrations
- sync / AI / account systems

## Acceptance signal

A reviewer should be able to open the app and immediately understand:

1. this is a desktop todo workspace
2. Inbox is the capture lane
3. Today is the execution lane
4. the repo is intentionally not spending Phase 1 effort on other platforms
