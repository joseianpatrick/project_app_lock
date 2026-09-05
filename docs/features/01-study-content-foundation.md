# F01: Study-content foundation

**Status:** Done  
**Depends on:** None

## Goal

Define the immutable content and source boundaries used by manual authoring, future AI generation, persistence, and active study sessions. Existing title-only tasks must continue to deserialize safely.

## Functional specification

- Support two formats: `quiz` and `flashcards`.
- A study item has a stable ID, prompt, and expected answer.
- Study content has a format, source notes, ordered items, and a string source ID. Manual content uses `manual`; future generators choose their own stable IDs.
- Extend `TaskModel` with nullable study content. A null value represents a legacy task that needs upgrading and is not startable.
- Preserve the current title, duration, creation time, and completion fields.
- Nested models serialize to JSON-compatible maps and tolerate missing legacy keys.

## Architecture and interfaces

- Keep Freezed models in `lib/data/` with no Flutter, MobX, repository, or platform imports.
- Add a `StudyContentSource` contract that accepts an authoring request and returns validated `StudyContentModel`.
- Implement `ManualStudyContentSource` as the first substitutable source. Validation normalizes surrounding whitespace and rejects empty notes, item prompts, answers, or item lists.
- Task stores and repositories receive only the resulting domain model; they must not know whether content was written manually or generated.
- Update task persistence to read/write nested study content while retaining the existing storage key and old-record compatibility.

## Acceptance criteria

- Quiz and flashcard content round-trip without losing item order or IDs.
- A pre-upgrade task map loads with `studyContent == null` and retains all old fields.
- Invalid serialized format values degrade to legacy/unavailable content rather than crashing startup.
- The manual source returns normalized content tagged with `sourceId: manual`.
- Invalid manual requests return a typed/domain validation failure rather than partially persisted content.
- A fake alternate source can satisfy the same contract without changes to task persistence or consumers.

## Test requirements

- Unit tests for every model's `fromMap`/`toMap`, empty and malformed legacy data, and ordered nested items.
- Contract tests shared by the manual source and future source implementations.
- Concrete task-repository tests for save, watch, update, recreation from shared preferences, and legacy records.
- Regenerate and commit Freezed output; run `dart analyze` and relevant task repository tests.

## Out of scope

- AI provider/API integration.
- Authoring screens.
- Study responses, scoring, or focus-session behavior.
