# F04: Active quiz and flashcard session

**Status:** Planned  
**Depends on:** F01, F02, F03

## Goal

Turn an active focus session into a resumable quiz or flashcard attempt. Completing every item permits early task completion and unlock; timer expiry unlocks without marking unfinished study complete.

## Session snapshot and progress

- At start, snapshot task ID/title, duration, format, ordered study items, and the current focus policy into `LockSessionModel`.
- Do not expose source notes in the active attempt.
- Persist current item index and one response record per attempted item: item ID, typed response, revealed state, and self-assessment (`correct` or `needsReview`).
- Persist progress after reveal/assessment transitions so process death restores the exact attempt.
- Task edits after start must not change the session snapshot.

## Quiz behavior

1. Show one numbered question and an empty typed-response field.
2. Require a non-empty response before **Reveal answer**.
3. After reveal, show the expected answer and require **Correct** or **Needs review**.
4. Persist the response and advance to the next question.
5. After all questions, show a summary with both assessment counts and the completion action.

## Flashcard behavior

1. Show the card front and typed-recall field.
2. Require a non-empty recall attempt before revealing the back.
3. Show the back/expected answer and require **Correct** or **Needs review**.
4. Persist the response and advance through the ordered deck.
5. After all cards, show the same assessment summary and completion action.

## Completion and failure rules

- Keep **Complete task and unlock** disabled until every snapshotted item has one assessment.
- On completion, persist the task's `completedAt` before finishing/unlocking the session.
- Preserve the current `unlockPending` recovery behavior if native unlock fails.
- If time expires before all items are assessed, finish the lock session but leave the task incomplete. Starting it later creates a fresh attempt.
- An already-active pre-upgrade session without study content retains the legacy manual completion action so an update cannot trap the user.
- Invalid/missing snapshotted item references produce a recoverable error and never silently mark the task complete.

## UI and store boundaries

- Keep focus-lock lifecycle and native orchestration in `FocusSessionStore`.
- Add a focused study-attempt store for response/reveal/assessment state and derived progress; inject the session repository and coordinate completion through the focus-session abstraction/store.
- The active screen renders loading, recoverable error, quiz/card content, summary, unlock-pending, and expired states.
- Always show task title, countdown, and item progress. Do not show unrelated task or settings controls.

## Acceptance criteria

- Both modes enforce response, reveal, and self-assessment order.
- Self-assessment never relies on exact text matching and does not impose a passing score.
- Every state transition survives leaving/resuming the Flutter process.
- Completion cannot be triggered early through the task list or direct store calls that bypass eligibility.
- Unlock occurs only after durable task completion; unlock failure remains retryable.
- Expiry releases enforcement but leaves incomplete task content available for a new attempt.

## Test requirements

- Model/repository tests for content/policy snapshots and every response state.
- Attempt-store tests for both modes, empty responses, repeat actions, progress, summaries, persistence failures, and restoration.
- Focus-session tests for snapshot isolation, completion ordering, expiry, unlock retry, and legacy fallback.
- Widget tests for quiz, flashcard, summary, loading/error, expiry, restoration, keyboard use, semantics, and 1.3 text scaling.

