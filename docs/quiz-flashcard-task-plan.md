# Quiz, Flashcard, and Focus-Behavior Plan

## Summary

Upgrade tasks from title-only focus timers into study tasks. Each task keeps its title and duration, but also requires a format, source notes, and at least one prompt-answer item. Users manually author content in v1; content creation is isolated behind a source abstraction so a future AI implementation can produce the same draft without changing persistence or study-session logic.

Once a task starts, its study experience becomes the dedicated Focus Lock screen. User-configurable focus behavior controls whether in-app navigation is locked to that screen, whether other eligible apps may be opened, and whether the system Back action is enabled. The selected behavior is snapshotted when the session starts and cannot be weakened during that session.

Implementation is tracked through the separate [feature specifications](features/README.md).

## Study-task architecture

- Add immutable study models:
  - `StudyFormat`: `quiz` or `flashcards`.
  - `StudyItemModel`: stable ID, prompt, and expected answer.
  - `StudyContentModel`: format, source notes, items, and string `sourceId` (`manual` initially).
  - Extend `TaskModel` with nullable study content so existing persisted tasks remain readable.
- Introduce a `StudyContentSource` contract that converts an authoring request into validated `StudyContentModel`.
  - Register `ManualStudyContentSource` through dependency injection.
  - A future AI source will implement the same contract, consume the task notes, and return the same model.
  - Task persistence and session stores consume only `StudyContentModel`; they never depend on manual forms, prompts, or an AI SDK.
- Split authoring from the task-list store:
  - Keep `TaskStore` responsible for listing, persistence, deletion, and completion state.
  - Add a disposable MobX task-editor store for draft fields, item add/edit/delete/reorder, validation, and saving.
  - Replace the small creation dialog with named full-screen create/edit routes because notes and a dynamic item list exceed a practical dialog workflow.
- The editor requires a title, non-empty source notes, a format, and at least one item whose prompt and answer are both non-empty. Preserve the existing title and duration validation.
- Task cards show format, item count, duration, and completion status. Existing title-only tasks show “Study content required,” allow edit/delete, and cannot start.
- Remove the task-list completion checkbox as a bypass. New tasks become complete only through the active study experience.

## Focus-behavior settings

- Add a settings icon to the Home app bar and a named `/settings` route.
- Add an immutable `FocusBehaviorSettingsModel` with three independent settings:
  - `lockToTaskScreen`: when enabled, any attempted navigation inside Focus Lock returns to the active study screen and the normal bottom navigation is hidden.
  - `allowOtherApps`: when enabled, unselected apps remain usable while the user's selected distracting apps stay blocked; when disabled, Android redirects attempts to open any eligible third-party app back to Focus Lock.
  - `backButtonEnabled`: when disabled, the active study screen consumes Flutter and Android predictive/system Back actions; when enabled, Back may background or leave Focus Lock, but reopening Focus Lock still restores the active study screen.
- Default new and migrated installations to focused behavior: task-screen lock enabled, other-app access disabled, and Back disabled. Explain these defaults during the start confirmation and on the settings screen.
- Use a narrow `FocusBehaviorSettingsRepository` contract with `load`, `save`, and `watch`, backed by shared preferences. A MobX `SettingsStore` owns loading, saving, errors, and switch state; the settings screen never accesses preferences directly.
- Save switches immediately with visible progress/error feedback. When a session is active, show the effective session policy as read-only and explain that changes apply to the next session.
- Snapshot all three settings into `LockSessionModel` at session start. Routing, Back handling, and native enforcement read the session snapshot rather than live preferences, preventing a running lock from being relaxed through settings changes or process restart.

## Dedicated active-task experience

- Move the active focus-session route outside `AppShell` so it has no Home/Tasks bottom navigation and cannot accidentally expose other in-app screens.
- Add a router-level active-session redirect: when `lockToTaskScreen` is enabled, attempts to open Home, Tasks, Settings, app selection, or task-editor routes resolve to the active study route. Once the session expires or completes, normal navigation resumes.
- Wrap the active screen in `PopScope` using the snapshotted `backButtonEnabled` value. Do not place Back, close, settings, theme, or overflow escape actions in the locked app bar.
- Keep the countdown, task title, progress indicator, and connection/error state visible without distracting from the current prompt.
- Starting focus snapshots the task title, format, notes, and ordered items into the lock session so later task edits cannot alter an active attempt.
- Persist the current item, typed responses, revealed state, and `correct`/`needsReview` self-assessments with the session.
- Quiz mode presents a sequential question form followed by a final results summary.
- Flashcard mode presents a front/back card deck with typed recall before revealing the back.
- Require a non-empty response before reveal and require self-assessment before advancing. After every item is assessed, enable **Complete task and unlock**.
- Completion persists the task's `completedAt` before attempting to unlock, retaining the existing unlock-retry behavior.
- If the timer expires first, unlock normally but leave the task incomplete; a later session starts a fresh attempt.
- Restore the exact item, response state, route restriction, Back behavior, and external-app policy after navigation, process restart, or device reboot.
- Preserve the old manual-completion UI only for an already-active session created by an earlier app version without a content or policy snapshot, preventing an update from trapping the user.

## Android and iOS platform behavior

- Extend `SystemAppLockGateway.startLockSession` with a typed external-app policy rather than passing UI booleans into platform code.
- Persist the policy with the native Android session so the accessibility service can enforce it after the Flutter process is killed or the device reboots.
- In selected-app mode, preserve existing behavior: only package IDs selected by the user are blocked.
- In restricted mode, treat every eligible launchable third-party package as blocked, excluding Focus Lock itself, System UI, device settings, phone/emergency functions, permission/authorization surfaces, and other system-critical packages. When one is detected, bring Focus Lock forward; the router restores the active task screen.
- Treat restricted mode as best-effort focus enforcement, not Android kiosk mode. A regular consumer app cannot reliably disable Home, Recents, notifications, power controls, or every system surface without device-owner/lock-task privileges. The UI and documentation must not claim otherwise.
- Keep accessibility permission disclosure explicit and verify the broader enforcement behavior against Google Play accessibility policy before release.
- Maintain the matching iOS channel signature and return a typed unsupported result for app restriction until an approved Family Controls/Managed Settings implementation and entitlement exist. In-app route and Back rules remain platform-neutral where an active session is supported.

## Screen composition

```text
HomeScreen
└── AppBar
    └── Settings icon -> SettingsScreen

SettingsScreen
├── AppBar("Focus behavior")
└── settings list
    ├── Switch("Lock navigation to task")
    ├── Switch("Allow other apps")
    ├── Switch("Enable Back button")
    ├── platform/support explanation
    └── save/error status

ActiveStudyScreen (outside AppShell)
├── locked AppBar(task title, countdown; no navigation actions)
├── progress indicator
├── quiz question or flashcard
├── typed response
├── reveal + self-assessment controls
└── final summary -> Complete task and unlock
```

The settings screen provides loading, error, unsupported-platform explanation, and content states. All controls use Material 3 theme roles, 48x48 minimum targets, scrollable layouts, and support at least 1.3 text scaling.

## Tests and acceptance criteria

- Model/repository tests cover nested study content, settings serialization/defaults, old title-only JSON, session policy snapshots, responses, and persisted progress.
- Source contract tests verify the manual implementation is substitutable and produces normalized domain content; use the same contract tests for a future AI source.
- Editor-store tests cover required fields, trimmed values, item operations, duplicate-save protection, editing, and persistence failures.
- Settings-store tests cover defaults, each toggle, immediate persistence, errors, migration, and the rule that an active session continues using its snapshot.
- Study-store tests cover quiz and flashcard sequencing, blocked empty responses, reveal/self-assessment, resume behavior, final summary, and completion eligibility.
- Router/widget tests verify that a locked active session hides bottom navigation and redirects every in-app route, while disabling the setting restores permitted navigation.
- Back-navigation tests cover enabled and disabled behavior, including Android predictive Back through `PopScope`.
- Session tests verify content and policy snapshot isolation, task completion before unlock, timer expiry without task completion, legacy active-session fallback, and unlock retries.
- Android tests cover selected-app enforcement, restricted eligible-app enforcement, safety exclusions, native policy restoration, expiry, and redirecting back to Focus Lock.
- iOS tests verify the extended channel contract remains handled and reports unsupported external-app enforcement without crashing.
- Widget tests cover create/edit routes, dynamic items, legacy-task upgrade messaging, both study layouts, settings states, large text, keyboard visibility, and restored progress.
- Regenerate Freezed/MobX output, then require `dart analyze`, the complete `flutter test` suite, Android unit tests, and an APK build to pass.
- Update product, architecture, privacy/disclosure, and store-policy documentation with the authoring boundary, focus settings, platform limitations, and future AI extension point.

## Assumptions

- Manual and future AI-generated tasks use identical stored study-content models.
- Correctness is self-assessed; v1 performs no automatic text matching and has no passing-score requirement.
- Items are completed in their stored order, and every item must be assessed once before early unlock.
- Source notes are visible while authoring but hidden during an attempt to avoid exposing answers unless explicitly included in an item.
- The three focus settings affect future sessions only; the start confirmation shows their effective values before the user commits.
- Disabling other-app access means all eligible third-party apps, not safety-critical Android/system surfaces.
- Adding AI later may add UI and a new source implementation, but it will not require changes to task persistence, study models, focus policy, or session-completion rules.
