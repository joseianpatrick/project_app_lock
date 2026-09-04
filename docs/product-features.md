# Product feature specification

## MVP behavior

The Android MVP lets the user maintain a set of apps to lock, create tasks with a focus duration, and start one task at a time. Starting a task locks the selected apps until its duration expires. Marking the active task complete allows the session to end early.

Saving a task does not immediately lock apps. The user explicitly starts the task from the task list, which prevents an accidental lock while creating or editing it.

## Feature 1: Add apps to lock

**Status: Implemented (Android MVP)**

### User flow

1. From Home, the user opens **Apps to lock**.
2. If Android authorization is missing, the screen explains why it is needed and offers **Grant access**.
3. Once authorized, the screen lists launchable user apps with icon, name, and selection control.
4. The user can search by app name and select or deselect multiple apps.
5. **Save apps to lock** becomes enabled only when the draft differs from the saved selection.
6. Saving persists the selection locally and applies a minimum one-second press throttle.
7. The saved selection becomes the default app set for future focus sessions.
8. Changes affect only future sessions; an active session retains its snapshot.

### Screen composition

```text
Scaffold
├── AppBar("Apps to lock")
├── permission/capability banner
├── SearchBar
├── app list
│   └── CheckboxListTile(icon, app name, selection)
└── Save apps to lock button
```

### State matrix

| State | Presentation | Action |
| --- | --- | --- |
| Loading | Progress indicator and loading label | None |
| Authorization required | Explanation of the Android access required | Grant access |
| Unsupported | Platform reason from capability result | Return home |
| Empty | No eligible apps found | Refresh |
| Error | Recoverable error message | Try again |
| Content | Searchable installed-app list and selected count | Select/deselect |

### Acceptance criteria

- Only eligible, launchable apps are shown; Focus Lock itself is excluded.
- Search is case-insensitive and does not mutate the stored selection.
- Checkbox changes update the draft immediately but persist only when **Save apps to lock** is pressed.
- The save button is disabled without changes and for at least one second during each save.
- Selection survives app restart through local preferences.
- At least one app must be selected before a task can start.
- Android native failures are presented as recoverable typed errors.
- iOS shows a supported placeholder state without crashing or exposing Android-only controls.

## Feature 2: Create a timed task in a modal

**Status: Implemented**

The task screen uses an **Add task** floating action button. Activating it opens `showAdaptiveDialog`, keeping the interaction appropriate for Android and preserving a compatible iOS UI shell.

### Modal fields

| Field | Required | Rules |
| --- | --- | --- |
| Task title | Yes | Trim whitespace; must not be empty; define a practical maximum length |
| Time period | Yes | Duration presets (for example 15, 25, 45, 60 minutes) plus a custom duration |

The time period is the task's intended focus/lock duration. Store it as an integer number of minutes rather than a display string. The MVP should enforce a documented lower and upper bound; a proposed range is 1 minute to 24 hours.

### Modal composition

```text
showAdaptiveDialog
└── AlertDialog
    ├── title: "Create task"
    ├── constrained scrollable content
    │   ├── TextField(task title)
    │   ├── duration preset chips
    │   ├── custom duration control
    │   └── inline validation/error message
    └── actions
        ├── Cancel
        └── Create task
```

The dialog content uses 16–24 point spacing, supports a text scale of at least 1.3, and avoids fixed-height text containers. Controls have at least 48×48 logical-pixel tap targets. While saving, the primary action is disabled and displays progress.

### Interaction rules

- Cancel closes the modal without changing task data.
- Create delegates validation and persistence to `TaskStore`; the widget does not construct repository calls.
- Validation errors keep the dialog open and focus the relevant field.
- A successful save closes the dialog and the new task appears through the repository stream.
- Editing a task uses the same form widget pre-populated with the existing title and duration.
- Starting a task is a separate explicit action on the task card.

### Acceptance criteria

- Tapping **Add task** opens the adaptive modal.
- Empty or whitespace-only titles cannot be saved.
- A duration is required and must be within the configured bounds.
- Title and duration are persisted on successful creation.
- The modal remains usable with the keyboard open and at larger text scales.
- Repeated taps cannot create duplicate tasks while a save is in progress.
- Store, repository, and widget tests cover valid input, invalid input, cancellation, saving state, and successful display.

## Feature 3: Start and complete a focus session

**Status: Implemented (Android MVP)**

Each pending task displays its duration and a **Start focus** action. Starting is allowed only when no other session is active and at least one app is selected.

### Session flow

1. The store validates capability, permissions, selected apps, task state, and duration.
2. A confirmation surface shows the task, selected-app count, and calculated end time.
3. The session and its app/task snapshot are persisted.
4. `SystemAppLockGateway.startLockSession` is invoked.
5. The active-session screen shows a countdown and task completion action.
6. Expiry or task completion persists the final state before calling `stopLockSession`.

### Failure behavior

- If native locking fails to start, the session must not remain marked active.
- If native unlocking fails, retain a recoverable reconciliation state and retry safely.
- Relaunching the app restores the active session from storage rather than creating another one.
- Android reboot handling must restore enforcement when the session has not expired.

## Delivered sequence

1. Extend `TaskModel` and task persistence with `durationMinutes`.
2. Replace the inline composer with the tested adaptive task modal.
3. Add installed-app discovery and persistent app selection.
4. Add the session model, repository, store, and active-session UI.
5. Implement Android authorization and enforcement behind the existing channel.
6. Add matching iOS placeholders for every new channel method.
7. Add lifecycle, relaunch, expiry, and reconciliation coverage; verify the Android native layer with an APK build.
