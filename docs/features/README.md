# Quiz and focus feature tracker

This directory breaks the [quiz, flashcard, and focus-behavior plan](../quiz-flashcard-task-plan.md) into implementation-ready feature specifications. Update the status in this table and in the corresponding spec as work progresses.

## Delivery tracker

| ID | Feature | Status | Depends on |
| --- | --- | --- | --- |
| F01 | [Study-content foundation](01-study-content-foundation.md) | Done | None |
| F02 | [Manual task authoring](02-manual-task-authoring.md) | In progress | F01 |
| F03 | [Focus-behavior settings](03-focus-behavior-settings.md) | Planned | None |
| F04 | [Active quiz and flashcard session](04-active-study-session.md) | Planned | F01, F02, F03 |
| F05 | [Focus-only in-app navigation](05-focus-only-navigation.md) | Planned | F03, F04 |
| F06 | [External-app restriction](06-external-app-restriction.md) | Planned | F03, F04 |

Allowed status values are **Planned**, **In progress**, **Blocked**, and **Done**. A feature becomes **Done** only when its acceptance criteria pass, generated code is current, and its required tests are green.

## Recommended delivery order

1. Implement F01 so every later feature shares one stable study-content model.
2. Implement F02 and F03 independently after their contracts are available.
3. Implement F04 using the content and settings snapshots.
4. Implement F05 and F06 in parallel after the active-session model is stable.
5. Run the full Flutter suite, Android tests, static analysis, and APK build before marking the initiative complete.

## Initiative definition of done

- New tasks cannot start without valid quiz or flashcard content.
- Manual authoring, editing, persistence, and legacy-task upgrading work end to end.
- Active responses and session policies survive process restart and device reboot where supported.
- The active task is the only in-app screen when its session policy requires it.
- Back and external-app behavior match the policy snapshot shown at session start.
- Safety-critical Android surfaces are never blocked, and unsupported iOS behavior is explicit.
- `dart analyze`, `flutter test`, Android unit tests, and an Android APK build pass.
