# Focus Lock architecture

## Product scope

Focus Lock helps a user select distracting apps, create timed tasks, and keep the selected apps unavailable during a focus session. Android is the first supported platform. The iOS build exposes the same Flutter channel contract, but its native implementation returns an explicit unsupported result until an approved Screen Time / Family Controls approach and the required Apple entitlement are available.

The project includes persistent timed tasks, installed-app discovery and selection, focus-session orchestration, dependency injection, navigation, tests, and Android enforcement through an accessibility service. Product behavior is defined in [Product features](product-features.md).

## Architectural boundaries

Dependencies point toward contracts and models:

```text
Flutter screen -> MobX store -> Repository<T> contract <- Repository implementation
                            -> SystemAppLockGateway <- MethodChannel implementation
                                                       |
                                                       +-> Android native handler
                                                       +-> iOS unsupported placeholder
```

| Layer | Location | Responsibility |
| --- | --- | --- |
| Models | `lib/data/` | Immutable Freezed data with no UI or platform dependencies |
| Contracts | `lib/data/repository/`, `lib/platform/app_lock/` | Persistence and system-lock abstractions |
| Implementations | `lib/features/*/*_repository.dart`, method-channel gateway | Local data and Flutter-to-native serialization |
| State | `lib/features/*/*_store.dart` | MobX actions, computed rules, validation, and orchestration |
| UI | `lib/features/*/*_screen.dart` | Material 3 rendering and user events only |
| Composition root | `lib/dependency/dependency_manager.dart` | The only place concrete implementations are wired |
| Navigation | `lib/router/app_router.dart` | Named `go_router` routes |

Stores depend on abstractions, never concrete repositories or `get_it`. Screens resolve stores through `sl<T>()`; repositories and native gateways never import widgets. A dialog may collect input, but validation and persistence remain store responsibilities.

## Core product modules

### Tasks

`TaskModel` records title, `durationMinutes`, creation time, and optional completion time. The task creation and editing UI uses an adaptive modal.

`TaskStore` owns title and duration validation, saving, completion, deletion, and task-derived state. `TaskRepository` persists JSON through shared preferences in production and can run in memory for isolated tests.

### Protected apps

The protected-app module uses an immutable model containing Android package id, display name, and icon data. It consists of:

- `InstalledAppsGateway`: narrow contract for native package discovery and capability/permission status.
- `MethodChannelAppLockGateway`: translates Flutter requests and native results.
- `ProtectedAppsStore`: loads installed apps, searches/filters them, and persists the selected package ids.
- `ProtectedAppsScreen`: renders loading, permission-required, empty, error, and content states.

Package discovery and permission checks remain outside widgets. The Android implementation must exclude Focus Lock itself and system components that cannot safely be selected. iOS must expose matching methods that return a typed unsupported response.

### Lock sessions

Starting a timed task creates a lock session containing an id, task id, selected package ids, start/end timestamps, and state (`scheduled`, `active`, `completed`, `cancelled`, or `unlockPending`). The session store coordinates persisted task/app data and calls `SystemAppLockGateway` only after the session is saved.

For the first MVP, one active task maps to one active lock session. This avoids ambiguous timing when tasks have different durations. A later focus-plan feature may group multiple tasks, but it must define a separate plan-level duration and snapshot all task ids at session start.

## Native platform contract

The channel name is `com.focuslock/app_lock`. Its calls are:

| Method | Status | Flutter arguments | Result |
| --- | --- | --- | --- |
| `getCapability` | Implemented | none | `{platform, isAvailable, authorizationRequired, reason}` |
| `getInstalledApps` | Implemented on Android | none | list of app summaries or typed error |
| `requestAuthorization` | Implemented on Android | none | updated permission/capability status |
| `startLockSession` | Implemented on Android | `{packageIds, endsAt, endsAtEpochMillis}` | success or typed `PlatformException` |
| `stopLockSession` | Implemented on Android | none | success or typed `PlatformException` |

Android uses an opt-in accessibility service to return Focus Lock to the foreground while a persisted session is active. Sessions use either selected-app enforcement or best-effort enforcement of eligible launchable third-party apps; system UI, launchers, settings, phone/emergency, permissions, accessibility, and recovery surfaces are always excluded. Permission onboarding opens system Accessibility settings, session enforcement state survives process death and reboot, and expired state is reconciled. Accessibility API use requires a Google Play policy and disclosure review before distribution.

iOS implements the same channel as a placeholder. It reports unavailable and returns `unsupported_platform` for lock operations. A future implementation must remain behind the same gateway and evaluate Apple's Family Controls, Managed Settings, Device Activity APIs, entitlement approval, and App Store rules. Flutter features render capability state; they do not branch directly on `Platform.isIOS`.

## Unlock policy

The first timed-task policy is:

1. Starting a task snapshots its duration and the selected package ids into a session.
2. Selected apps remain locked until the session end time.
3. Completing the active task permits an early unlock.
4. Editing/deleting the task or changing the global app selection must not silently alter an active session.
5. Native enforcement is released only after session state is durably updated, with reconciliation after app relaunch or Android reboot.

This policy belongs in the session store or a focused domain service, not in a widget or native activity.

## Persistence roadmap

1. Shared preferences persist tasks, selected apps, and sessions for the MVP.
2. In-memory repository modes remain available for isolated unit tests.
3. Native enforcement state is persisted separately on Android so killing the Flutter process does not bypass an active session.
4. A later schema-heavy release can replace preferences with a transactional database behind the existing repository contracts.

## Feature delivery order

For every feature, change files in this order: model -> contract -> implementation -> store -> dependency registration -> route/screen -> generated code -> tests. Every Android method-channel addition must include an iOS handler that returns either a real implementation or a documented typed unsupported response.

Before merging a milestone, run:

```sh
dart run build_runner build --delete-conflicting-outputs
dart analyze
flutter test
```

Generated `*.g.dart` and `*.freezed.dart` files are committed and never edited by hand.
