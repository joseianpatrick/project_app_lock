# Focus Lock implementation review

Scope: every feature listed under [`docs/README.md`](docs/README.md) — F01–F06 in
[`docs/features/`](docs/features/README.md), plus `architecture.md`, `product-features.md`,
`privacy-accessibility.md`, and `release-review.md`.

Baseline checks run on this working tree:

| Check | Result |
| --- | --- |
| `dart analyze` | No issues found |
| `flutter test` | 81 tests, all passing |
| Android unit tests | **No test source set exists** (`android/app/src/` has only `debug/ main/ profile/`, no test dependencies in `build.gradle.kts`) |
| iOS channel tests | Only the generated `RunnerTests.testExample` stub |
| Android APK build | Not run in this review |

## Feature status summary

| ID | Feature | Tracker status | Assessment |
| --- | --- | --- | --- |
| F01 | Study-content foundation | Done | Implemented as specified. Minor persistence hardening gaps (B9). |
| F02 | Manual task authoring | Done | Implemented. Legacy title-only creation path still exists in `TaskStore` (R1); docs still describe the removed modal (D1). |
| F03 | Focus-behavior settings | Done | Model/repository/store correct, but **an acceptance criterion fails in the UI** (B2). |
| F04 | Active study session | Done | Logic and persistence correct; **two UI defects break the attempt flow** (B1, B3). |
| F05 | Focus-only navigation | Done | Guard and `PopScope` correct. Dead-end screen after the session ends (B4). |
| F06 | External-app restriction | Done | Flutter + native policy plumbing correct, but **its required Android and iOS tests do not exist**, so the tracker's own definition of Done is not met (D5). Package-visibility gap weakens a documented safety exclusion (B7). |

---

## Bugs

### B1 — The typed response from the previous item stays in the field, and blocks the next reveal
`lib/features/focus_session/focus_session_screen.dart:182` · `lib/features/focus_session/study_attempt_store.dart:226`

`assess()` clears `responseDraft` in the store, but nothing clears `_responseController`. The
restore branch in the screen only copies *store → controller* when the controller is empty, so
after answering item 1 the field still shows the old text while `responseDraft` is `''`.

Verified with a two-item quiz:

```
CONTROLLER TEXT ON ITEM 2: "my first answer"
STORE responseDraft: ""  canReveal=false
```

The user sees a filled answer box with **Reveal answer** greyed out and has to edit the text before
they can continue. Every multi-item task hits this — the existing widget tests only cover
single-item decks, which is why it is green. Clearing the controller when the item index advances
(or keying the `TextField` by item id) fixes it.

### B2 — Failed settings saves are invisible; the per-switch spinner never appears
`lib/features/settings/settings_screen.dart:45` and `:59`

`_SettingsContent` is *constructed* inside the parent `Observer` but its `build` runs outside that
reactive context, so `store.savingSetting` and `store.errorMessage` are not tracked. Only a change
to `settings` triggers a rebuild — and on a failed save `settings` is restored to the identical
instance, so MobX does not notify at all.

Verified: after a save failure `store.errorMessage` is set, and the message renders nowhere.

```
store.errorMessage = Could not save focus behavior settings. Try again.
error visible in UI: false
```

This fails F03's "A failed save is visible…" acceptance criterion and the "Disable the affected
control and show progress during its save" UI rule. Wrap the switch list (or each switch) in its own
`Observer`.

### B3 — A restored, already-revealed response is never shown
`lib/features/focus_session/study_attempt_store.dart:169` · `focus_session_screen.dart:267`

`initialize()` only restores `responseDraft` when `!response.isRevealed`, but `revealAnswer()`
always persists `isRevealed: true` — so nothing is ever persisted with `isRevealed == false` and that
branch is dead. Resuming after process death mid-item (revealed, awaiting assessment) shows an
**empty, disabled** response field even though `currentResponse.response` holds the text. F04 asks
for the exact attempt to be restored; the data survives but the UI drops it. Render
`currentResponse.response` when revealed instead.

### B4 — `/focus-session` becomes a dead end once the session ends
`lib/features/focus_session/focus_session_screen.dart:61`

`_NoSession` and `_ExpiredSession` are bare `Scaffold`s with no app bar and no action. The route sits
outside `AppShell` (correct per F05), so once `activeSession` is null there is no bottom navigation,
no Back affordance, and the redirect that would have moved the user is gone. On expiry the user is
stranded until they kill the app. Add a "Back to tasks" action to both states.

### B5 — Task-list load failures render as "no tasks yet"
`lib/features/tasks/task_screen.dart:80`

`TaskStore.errorMessage` is set on stream failure but the screen only branches on `isLoading` and
`isEmpty`, so a load error is indistinguishable from an empty list — and offers no retry. Same store
field is unused on Home.

### B6 — `FocusSessionStore.initialize()` is re-run by every screen, replaying native session start
`home_screen.dart:28`, `task_screen.dart:24`, `settings_screen.dart:25`, `focus_session_screen.dart:25`, `app_router.dart:24`

The store is a singleton, but five call sites call `initialize()`. Each call cancels the
subscription, resets `_awaitingInitialSnapshot`, and re-runs `_reconcile` — which calls
`gateway.startLockSession(...)` again on every navigation into those screens. It is idempotent on
the native side today, so the damage is churn rather than corruption, but it also means a transient
window where `activeSession` is stale on each navigation. Initialize once (the router guard already
does it at startup) and let screens only observe.

### B7 — Recovery-surface exclusions can silently fail on Android 11+
`android/app/src/main/kotlin/.../FocusLockSessionStorage.kt:81` · `android/app/src/main/AndroidManifest.xml:68`

`isSafetyExcluded` resolves HOME / `ACTION_DIAL` / `ACTION_SETTINGS` / accessibility-settings intents
through `packageManager.resolveActivity`, but `<queries>` only declares `MAIN`+`LAUNCHER` and
`PROCESS_TEXT`. Under package-visibility filtering those resolves can return `null`, so the
exclusion list silently shrinks to the hardcoded `safetyExcludedPackages` set. System dialers and
Settings are still saved by the `FLAG_SYSTEM` check, but a **user-installed launcher or dialer**
would then be treated as an eligible third-party app and blocked in `allEligible` mode. That
contradicts F06's safety constraint and the disclosure in `privacy-accessibility.md`. Declare the
HOME/DIAL/SETTINGS intents in `<queries>`.

### B8 — `FocusBlockedActivity` is dead code
`android/app/src/main/kotlin/.../FocusBlockedActivity.kt` + `res/layout/activity_focus_blocked.xml` + 5 strings + `FocusBlockedTheme`

The accessibility service launches `MainActivity` directly and never sends
`EXTRA_BLOCKED_PACKAGE`, so this activity, its layout, its theme, and the
`focus_blocked_*` / `blocked_app_icon_description` / `return_home` strings are unreachable. Either
wire it up as the interstitial (it is nicer UX than bouncing straight into the Flutter UI) or delete
it — right now it is a manifest-registered activity that reviewers will ask about.

### B9 — Corrupt stored JSON can silently wipe all tasks or sessions
`lib/features/tasks/task_repository.dart:31` · `lib/features/focus_session/lock_session_repository.dart:28`

`_load()` sets `_hasLoaded = true` *before* `jsonDecode`. If the stored string is corrupt the
exception escapes through `watch()` (surfacing as "Could not load tasks."), but the repository is now
permanently marked as loaded with an empty map — the next `set()`/`update()` calls `_persist()` and
overwrites the stored record with `[]`. F01 asks malformed data to degrade rather than crash; per-record
tolerance exists (`StudyContentModel.tryFromMap`) but whole-payload tolerance does not. Wrap the
decode in a try/catch and keep a "load failed" flag that blocks destructive persistence.

### B10 — Bottom-navigation highlight is wrong on the editor routes
`lib/shared/widgets/app_bottom_navigation.dart:11`

`/tasks/new` and `/tasks/:taskId/edit` fall through to index 0 (Home) instead of Tasks. Separately,
the `path == '/focus-session' ? 3` branch is unreachable — that route now lives outside the shell —
so the "Session" destination navigates out of the shell and can never render as selected.

### B11 — Completing a session whose task was deleted silently "succeeds"
`lib/features/focus_session/focus_session_store.dart:193` · `task_repository.dart:82`

`Repository.update` returns silently when the id is missing, so `completeActiveTask()` unlocks and
reports success without ever persisting a completion. This is reachable whenever
`lockToTaskScreen` is off (the task list stays navigable and Delete has no guard). F04 requires that
missing snapshot references produce a recoverable error rather than a silent completion.

---

## Improvements

- **I1 — `allEligible` still requires at least one selected app.** `validateStart`
  (`focus_session_store.dart:105`) and `MainActivity.startLockSession:128` both reject an empty
  package list, even when the policy is "block everything eligible" and the selected list is
  irrelevant. Users who only want the blunt mode are forced through app selection.
- **I2 — The accessibility service does package-manager work on every window change.**
  `shouldBlock` reads `SharedPreferences` and, in `allEligible` mode, calls `getApplicationInfo`,
  `queryIntentActivities`, and up to four `resolveActivity` calls per `TYPE_WINDOW_STATE_CHANGED`
  event, on the service's main thread. Cache the policy, the end time, and the resolved exclusion set
  in memory and invalidate on `save`/`clear`.
- **I3 — Lock sessions are never pruned.** `LockSessionRepository` keeps every completed and
  cancelled session in shared preferences forever and re-serialises the whole list on each write.
  Cap the history or delete on completion.
- **I4 — No prominent in-app accessibility disclosure.** `release-review.md` requires confirming one,
  but the only in-app text is `capability.reason` on the Apps-to-lock screen. Google Play's
  Accessibility API policy expects a disclosure before the permission hand-off. Related: the
  "Accessibility Guard" card (`protected_apps_screen.dart:151`) says "Service protects N selected
  apps", which is inaccurate while `allowOtherApps` is off.
- **I5 — Deleting a task has no confirmation** (`task_screen.dart:100`) — irreversible loss of all
  authored study items from a two-tap overflow menu.
- **I6 — A disabled "Start focus" button gives no reason.** The card shows "Study content required",
  but a *completed* task also disables Start with no explanation. Add a tooltip/semantic label.
- **I7 — The duration text field never syncs to the store until save**
  (`task_editor_screen.dart:53`), so the preset chips do not reflect a typed value and
  `_store.durationMinutes` is stale during editing.
- **I8 — Editing a deleted task silently creates a new one.** `TaskEditorStore.load` sets
  "This task no longer exists." but leaves `taskId == null`, so `save()` falls into the create path
  (`task_editor_store.dart:138`). Block saving in that state.
- **I9 — `PopScope` defaults to `canPop: true` for a policy-less session**
  (`focus_session_screen.dart:67`), while the documented default for `backButtonEnabled` is *off*.
  The router guard and the native gateway both default the other way (`app_router.dart:31`,
  `focus_session_store.dart:295` default to the strict value). Align on the documented default.
- **I10 — F06's iOS channel tests do not exist.** `AppDelegate.swift` correctly returns
  `unsupported_platform` for the extended `startLockSession`, but `RunnerTests.swift` is still the
  generated empty stub.

---

## Refactors / cleanup

- **R1 — `TaskStore` still contains the pre-F02 authoring path.** `addTask`, `saveTask`,
  `formError`, `clearFormError`, and `canUnlock` (`task_store.dart:63-119`) have no production
  callers — only tests. Worse, `saveTask` constructs a `TaskModel` with `studyContent: null`, which
  is exactly the "not startable legacy task" state F01/F02 set out to eliminate. Delete them (and the
  unused `TaskModel.empty()`) so the invariant is structural, not conventional.
- **R2 — A widget reaches through a store into a repository.** `task_screen.dart:38` calls
  `_sessionStore.settingsRepository.load()` to build the confirmation summary. `architecture.md`
  says screens talk to stores only. Expose the effective policy from `FocusSessionStore` (or read
  `SettingsStore.settings`) instead.
- **R3 — The router guard owns store lifecycle.** `FocusSessionRouteGuard`'s constructor calls
  `_store.initialize()` (`app_router.dart:24`), making app-wide session restoration a side effect of
  building a router. Also `disposeGuard()` calls `super.dispose()` from a non-override method rather
  than overriding `dispose()`.
- **R4 — Completion eligibility is implemented twice.** `FocusSessionStore._canComplete:202` and
  `StudyAttemptStore.canComplete/hasInvalidProgress:49-145` re-derive the same rules with slightly
  different checks. The duplication is deliberate defence-in-depth per F04, but it should live in one
  shared pure function over `(SessionStudyContentModel, StudyProgressModel)`.
- **R5 — `reconcileExpiry` is `shouldBlock(context, "")`** (`FocusLockSessionStorage.kt:72`). It
  works only because the blank package short-circuits after the expiry check. Give expiry its own
  method.
- **R6 — Dead conditions:** `hasInvalidProgress`'s `(response.assessment != null &&
  !response.isRevealed)` is unreachable after the preceding `!response.isRevealed` check
  (`study_attempt_store.dart:65`); `progress.currentItemIndex < 0` can't hold because `fromMap`
  clamps it (`lock_session_model.dart:110`); `Bitmap.compress(PNG, 90)` — quality is ignored for PNG
  (`MainActivity.kt:108`).
- **R7 — `TaskEditorStore.addItem` mints study-item ids from `taskRepository.newId()`**
  (`task_editor_store.dart:85`) — the task repository is being used as a general id generator across
  aggregates. Inject a `Uuid`/id function instead.
- **R8 — `FocusBehaviorSettingsModel` and `FocusSessionPolicyModel` are field-for-field identical**
  with duplicated `fromMap`/`toMap` (`focus_behavior_settings_model.dart`). The distinction is
  meaningful (settings vs. immutable snapshot), but the parsing can be shared.
- **R9 — Installed-app eligibility is duplicated** between `MainActivity.loadInstalledApps:71` and
  `FocusLockSessionStorage.isEligibleLaunchableThirdParty:92` with slightly different rules — the
  former does not apply `safetyExcludedPackages`, so a user can select an app that will never be
  blocked, with no feedback. F06 says both should use "the same eligibility rules".

---

## Documentation drift

- **D1 — `docs/product-features.md` "Feature 2: Create a timed task in a modal" is obsolete but
  marked Implemented.** It specifies `showAdaptiveDialog`, an `AlertDialog` composition tree, and
  `TaskStore`-owned validation. F02 replaced all of that with `/tasks/new`, `/tasks/:taskId/edit`,
  and `TaskEditorStore`. `docs/README.md` still presents this file as the product feature spec, so
  the two documents now contradict each other. "Feature 3" step 5 is likewise stale — completion now
  requires every item to be assessed.
- **D2 — `architecture.md` native contract table omits `externalAppPolicy`** from
  `startLockSession`'s arguments (it lists `{packageIds, endsAt, endsAtEpochMillis}`).
- **D3 — `architecture.md` "Tasks" section is stale:** `TaskModel` is described without
  `studyContent`, task authoring is described as "an adaptive modal", and `TaskStore` is credited
  with validation, saving, and completion — all now owned by `TaskEditorStore` / the session store.
- **D4 — `architecture.md` has no entry for the F03/F04/F05 modules:**
  `FocusBehaviorSettingsRepository`, `SettingsStore`, `StudyContentSource`, `StudyAttemptStore`, and
  the `FocusSessionRouteGuard` are all absent from the layer table and "Core product modules".
- **D5 — `docs/features/README.md` marks F06 Done, and claims an initiative DoD of "Android unit
  tests … pass".** There is no Android test source set and no test dependency in
  `android/app/build.gradle.kts`; F06's required tests for storage, expiry, selected-only vs.
  all-eligible matching, exclusions, malformed values, clearing, and reboot restoration do not exist,
  and neither do its iOS channel tests. Either add them or move F06 back to *In progress* — as
  written, the tracker overstates verification of the riskiest, safety-relevant feature.
- **D6 — Accurate as written:** `docs/README.md`, `privacy-accessibility.md`, and
  `release-review.md` all match the implemented `selectedOnly` / `allEligible` behaviour and avoid
  kiosk claims.

---

## Suggested order of work

1. B1, B2, B3 — user-visible defects in shipped "Done" features; each is a small, local fix.
2. B4, B5, B11 — recoverability gaps (stranded screen, hidden error, silent false completion).
3. B7 + I2 — Android safety and performance in the accessibility path.
4. D5 — add the Android/iOS tests F06 requires, or correct the tracker status.
5. R1, R2 — remove the pre-F02 authoring path and the widget→repository reach-through.
6. D1–D4 — fold the stale product/architecture docs back in line with F01–F06.
