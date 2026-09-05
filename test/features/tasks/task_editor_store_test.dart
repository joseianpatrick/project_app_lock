import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'package:project_app_lock/data/study_content_model.dart';
import 'package:project_app_lock/features/tasks/manual_study_content_source.dart';
import 'package:project_app_lock/features/tasks/task_editor_store.dart';

import '../../fakes/fake_task_repository.dart';

void main() {
  late FakeTaskRepository repository;
  late TaskEditorStore store;

  setUp(() {
    repository = FakeTaskRepository();
    store = TaskEditorStore(
      taskRepository: repository,
      studyContentSource: ManualStudyContentSource(),
    );
  });

  tearDown(() => repository.close());

  test('creates normalized study content in item order', () async {
    store
      ..setTitle('  Review verbs  ')
      ..setSourceNotes('  Grammar notes  ')
      ..addItem()
      ..updateItem(
        store.items.single.id,
        prompt: '  Define a verb ',
        answer: ' Action word ',
      );

    expect(await store.save(), isTrue);
    final task = await repository.getById('id_1');
    expect(task?.title, 'Review verbs');
    expect(task?.studyContent?.sourceNotes, 'Grammar notes');
    expect(task?.studyContent?.items.single.prompt, 'Define a verb');
  });

  test(
    'validates content, supports reordering, and preserves edit metadata',
    () async {
      store
        ..setTitle('Study')
        ..setSourceNotes('Notes');
      expect(await store.save(), isFalse);
      expect(store.errorMessage, 'Add at least one study item.');

      store
        ..addItem()
        ..addItem()
        ..updateItem(store.items[0].id, prompt: 'First', answer: 'One')
        ..updateItem(store.items[1].id, prompt: 'Second', answer: 'Two')
        ..moveItem(1, 0);
      expect(store.items.first.prompt, 'Second');
      expect(await store.save(), isTrue);

      final saved = (await repository.getById('id_2'))!;
      final editor = TaskEditorStore(
        taskRepository: repository,
        studyContentSource: ManualStudyContentSource(),
      );
      await editor.load(saved.id);
      editor.setTitle('Updated');
      expect(await editor.save(), isTrue);
      final updated = (await repository.getById(saved.id))!;
      expect(updated.createdAt, saved.createdAt);
      expect(updated.studyContent?.format, StudyFormat.quiz);
    },
  );

  test('prevents duplicate saves while persistence is pending', () async {
    store
      ..setTitle('Study')
      ..setSourceNotes('Notes')
      ..addItem()
      ..updateItem(store.items.single.id, prompt: 'Prompt', answer: 'Answer');
    final gate = Completer<void>();
    repository.setGate = gate;

    final first = store.save();
    await Future<void>.delayed(Duration.zero);
    expect(store.isSaving, isTrue);
    expect(await store.save(), isFalse);
    expect(repository.setCalls, 1);

    gate.complete();
    expect(await first, isTrue);
  });

  test('keeps the draft and reports a repository failure', () async {
    store
      ..setTitle('Study')
      ..setSourceNotes('Notes')
      ..addItem()
      ..updateItem(store.items.single.id, prompt: 'Prompt', answer: 'Answer');
    repository.failSet = true;

    expect(await store.save(), isFalse);
    expect(store.errorMessage, 'Could not save the task. Try again.');
    expect(store.title, 'Study');
    expect(store.items, hasLength(1));
  });

  test('reports missing and unreadable edit targets', () async {
    await store.load('missing');
    expect(store.errorMessage, 'This task no longer exists.');

    repository.failGet = true;
    await store.load('another');
    expect(store.errorMessage, 'Could not load this task.');
  });
}
