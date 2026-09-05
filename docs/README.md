# Focus Lock documentation

- [Architecture](architecture.md) — technical boundaries, platform channels, persistence, and delivery rules.
- [Product features](product-features.md) — app selection, task creation, focus timing, user flows, and acceptance criteria.
- [Quiz and focus master plan](quiz-flashcard-task-plan.md) — approved direction for study tasks, focus behavior, and future AI-generated content.
- [Quiz and focus feature tracker](features/README.md) — implementation order, status, and separate feature specifications.
- [Accessibility and privacy disclosure](privacy-accessibility.md) — what Android accessibility access observes and its limits.
- [External-app restriction release review](release-review.md) — required Android verification and store-policy checks.

The documented MVP is implemented for Android. Its accessibility service returns Focus Lock when configured distracting apps—or, when the session policy requires it, eligible third-party launchable apps—open during an active session. It never claims kiosk-level control and preserves emergency, phone, authorization, accessibility, settings, and core system recovery surfaces. iOS provides a safe unsupported placeholder because native app blocking requires Apple Family Controls entitlements and a separate product decision.
