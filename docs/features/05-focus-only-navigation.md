# F05: Focus-only in-app navigation

**Status:** Done
**Depends on:** F03, F04

## Goal

Make the active task the only Focus Lock screen available when the session's `lockToTaskScreen` policy is enabled, while independently honoring its Back-button policy.

## Navigation behavior

- Move the active study route outside `AppShell`; it must never render the global bottom navigation.
- Add a reactive router guard based on the active `LockSessionModel` and its snapshotted policy.
- When task-screen lock is enabled, redirect attempts to reach Home, Tasks, task editors, Apps to lock, or Settings to the active study route.
- Direct/deep links follow the same rule. Once the session completes or expires, redirects stop and normal navigation resumes.
- When task-screen lock is disabled, other Focus Lock routes remain reachable, but the active-session card and route continue to restore the attempt.

## Back behavior

- Wrap the active study screen in `PopScope` and derive `canPop` from the snapshotted `backButtonEnabled` value.
- When Back is disabled, consume app-bar, gesture, Android system Back, and predictive Back attempts without navigating.
- When Back is enabled, allow the platform's normal behavior, including backgrounding/exiting Focus Lock when no prior route exists.
- Reopening Focus Lock restores the active study route when task-screen lock is enabled.
- A locked app bar exposes no Back, close, settings, theme, or overflow escape action.

## Architecture

- Refactor router construction as needed so the guard receives observable active-session state through an injected adapter/listenable; do not resolve `get_it` inside stores or place session policy in widgets.
- Keep navigation decisions in the router/guard and Back presentation in the active screen. The native accessibility service must not decide Flutter routes.
- Dispose any MobX-to-router reaction/listenable with the application router lifecycle.

## Acceptance criteria

- Starting a locked session immediately replaces the shell with the active study screen.
- Bottom navigation and unrelated app-bar actions are absent during the locked session.
- Every in-app route and deep link redirects while locked.
- Task-screen lock off permits internal navigation without changing external-app or Back settings.
- Back enabled and disabled behaviors match the snapshot and survive process restoration.
- Completing or expiring the session restores normal routing without a restart.

## Test requirements

- Router tests covering every protected route, deep links, enabled/disabled task-screen lock, restoration, expiry, and completion.
- Widget tests proving shell navigation is absent and no escape controls are rendered.
- Back and predictive-Back tests through `PopScope` for both policy values.
- Regression tests for normal Home, Tasks, Settings, and Apps-to-lock navigation when no session is active.

## Platform limitation

This feature confines navigation inside Focus Lock. It does not disable Android Home, Recents, notifications, or power controls; external-app behavior belongs to F06.
