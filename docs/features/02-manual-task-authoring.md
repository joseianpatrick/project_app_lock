# F02: Manual task authoring

**Status:** In progress  
**Depends on:** F01

## Goal

Replace title-only task creation with a full-screen workflow for manually creating and editing quiz or flashcard tasks, while keeping business validation outside widgets.

## User flow

1. The user selects **Add task** and opens the named task-create route.
2. The user enters a title, duration, source notes, and chooses Quiz or Flashcards.
3. The user adds one or more prompt-answer items and may edit, delete, or reorder them.
4. Saving validates the complete draft through the editor store and manual content source.
5. A successful save returns to Tasks, where the streamed task displays its format, item count, and duration.
6. Editing uses the same screen prefilled from a task ID route parameter.

## UI specification

```text
TaskEditorScreen
├── AppBar(Create task | Edit task)
├── title field
├── duration presets + custom minutes
├── format segmented control
├── source-notes multiline field
├── ordered item list
│   └── prompt field + answer field + reorder/delete controls
├── Add item
├── inline validation/error state
└── Save task
```

- Use named `/tasks/new` and `/tasks/:taskId/edit` routes.
- Keep the screen scrollable with the keyboard open and at 1.3 text scaling.
- All icon controls require tooltips/semantic labels and 48x48 minimum targets.
- Disable Save and show progress while persistence is active; repeated taps create no duplicates.
- Task cards replace completion checkboxes with status, format, item count, duration, and explicit Edit/Delete/Start actions.
- Legacy title-only cards show **Study content required** and route to the editor; Start remains disabled.

## State and architecture

- Add a factory-created, disposable MobX `TaskEditorStore`; do not expand `TaskStore` into form state.
- Inject the repository abstraction and `StudyContentSource` into the editor store through `DependencyManager`.
- The store owns loading an edit target, draft mutations, validation, saving, errors, and busy state.
- Widgets own and dispose text/focus controllers but delegate domain changes and persistence to store actions.
- Required fields are title, duration from 1 to 1440 minutes, format, non-empty notes, and at least one item with non-empty prompt and answer. Keep the existing 120-character title maximum.

## Acceptance criteria

- A valid quiz or flashcard task can be created and appears without manually refreshing the task list.
- Cancel/back before saving leaves repository data unchanged.
- Invalid input keeps the screen open, identifies the first invalid section, and does not persist partial data.
- Items retain their order across saving, app restart, and editing.
- Editing preserves task ID, creation time, and completion state while updating authorable fields.
- Legacy tasks can be upgraded through Edit and become startable only after a valid save.
- Manual completion from the task list is no longer possible.

## Test requirements

- Editor-store tests for loading, draft mutations, validation, item reordering/deletion, create/edit, double-save, and repository failure.
- Task-list store regression tests for streaming, completion counts, delete, and legacy eligibility.
- Widget tests for create, cancel, validation, edit, reordering, legacy messaging, saving state, keyboard layout, and text scaling.
- Router tests for both editor routes and missing task IDs.

## Out of scope

- AI generation controls.
- Performing a quiz or flashcard.
- Focus navigation and external-app restriction.
