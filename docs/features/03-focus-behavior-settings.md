# F03: Focus-behavior settings

**Status:** Done
**Depends on:** None

## Goal

Let users configure the behavior applied to future focus sessions without allowing an active session to be weakened after it begins.

## Settings

| Setting | Default | Meaning |
| --- | --- | --- |
| Lock navigation to task | On | In-app routes redirect to the active task and normal bottom navigation is hidden. |
| Allow other apps | Off | When off, Android restricts all eligible third-party apps; when on, only the selected distracting apps remain blocked. |
| Enable Back button | Off | When off, the active task consumes Flutter and Android system/predictive Back actions. |

## User flow and UI

- Add a settings icon with tooltip to the Home app bar and a named `/settings` route.
- The settings screen uses three `SwitchListTile.adaptive` controls with short consequences beneath each label.
- Switches persist immediately. Disable the affected control and show progress during its save; on failure, restore the last persisted value and show a recoverable error.
- Show loading, error/retry, content, and platform-support explanation states.
- If an active session is visible through a non-locked route policy, show that session's effective settings read-only and state that edits apply only to the next session.
- The start-focus confirmation summarizes the three effective choices before the user commits.

## Architecture and persistence

- Add immutable `FocusBehaviorSettingsModel` and `FocusSessionPolicyModel`; the latter is embedded as an immutable session snapshot.
- Use a focused `FocusBehaviorSettingsRepository` interface with `load`, `save`, and broadcast `watch`; do not force singleton settings through `Repository<T>` CRUD.
- Back the production implementation with shared preferences and inject it into a singleton MobX `SettingsStore`.
- Stores depend on the settings contract/model, never shared preferences or platform APIs.
- Missing stored settings use the documented defaults. Malformed values fall back per field without discarding valid fields.

## Acceptance criteria

- The Home settings icon opens the screen through `go_router`.
- Defaults are deterministic on clean install and migration.
- Each switch survives app restart and emits updated settings to subscribers.
- A failed save is visible and does not leave the UI showing an unpersisted value.
- Starting a session copies the current settings into its policy snapshot.
- Later setting changes do not alter an active session or its restored behavior.

## Test requirements

- Model and repository tests for defaults, serialization, malformed data, broadcast re-subscription, save failure, and recreation.
- Store tests for initialize, all switches, busy state, rollback/error behavior, and active-policy display.
- Widget tests for loading/error/content states, settings icon, switches, semantics, text scaling, and start confirmation summary.

## Out of scope

- Router enforcement of the policy; covered by F05.
- Native external-app enforcement; covered by F06.
