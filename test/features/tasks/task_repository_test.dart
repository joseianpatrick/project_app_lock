import 'package:flutter_test/flutter_test.dart';
import 'package:project_app_lock/data/task_model.dart';
import 'package:project_app_lock/data/study_content_model.dart';
import 'package:project_app_lock/features/tasks/task_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late TaskRepository repository;

  setUp(() {
    repository = TaskRepository();
  });

  tearDown(() {
    repository.dispose();
  });

  test('set emits the stored task and getById returns it', () async {
    final task = TaskModel(
      id: 'ignored',
      title: 'Write plan',
      durationMinutes: 25,
      createdAt: DateTime.utc(2026),
    );
    final expectation = expectLater(
      repository.watch(),
      emitsInOrder(<dynamic>[isEmpty, hasLength(1)]),
    );
    await Future<void>.delayed(Duration.zero);

    await repository.set('task-1', task);
    await expectation;

    expect((await repository.getById('task-1'))?.id, 'task-1');
  });

  test('update changes completion and delete removes the task', () async {
    final completedAt = DateTime.utc(2026, 9, 4);
    await repository.set(
      'task-1',
      TaskModel(
        id: 'task-1',
        title: 'Write plan',
        durationMinutes: 25,
        createdAt: DateTime.utc(2026),
      ),
    );

    await repository.update('task-1', <String, Object?>{
      'completedAt': completedAt,
    });
    expect((await repository.getById('task-1'))?.completedAt, completedAt);

    await repository.delete('task-1');
    expect(await repository.getById('task-1'), isNull);
  });

  test('newId does not collide across rapid calls', () {
    final ids = List<String>.generate(100, (_) => repository.newId()).toSet();
    expect(ids, hasLength(100));
  });

  test('watch supports multiple subscriptions', () async {
    final first = repository.watch().first;
    final second = repository.watch().first;

    expect(await first, isEmpty);
    expect(await second, isEmpty);
  });

  test('tasks survive repository recreation with preferences', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final firstRepository = TaskRepository(preferences: preferences);
    await firstRepository.set(
      'task-1',
      TaskModel(
        id: 'task-1',
        title: 'Persist me',
        durationMinutes: 45,
        createdAt: DateTime.utc(2026),
      ),
    );
    firstRepository.dispose();

    final restoredRepository = TaskRepository(preferences: preferences);
    final restored = await restoredRepository.watch().first;

    expect(restored.single.title, 'Persist me');
    expect(restored.single.durationMinutes, 45);
    restoredRepository.dispose();
  });

  test('persists nested study content with ordered item IDs', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final firstRepository = TaskRepository(preferences: preferences);
    await firstRepository.set(
      'task-1',
      TaskModel(
        id: 'task-1',
        title: 'Study grammar',
        durationMinutes: 25,
        createdAt: DateTime.utc(2026),
        studyContent: const StudyContentModel(
          format: StudyFormat.quiz,
          sourceNotes: 'Grammar notes',
          sourceId: 'manual',
          items: <StudyItemModel>[
            StudyItemModel(id: 'one', prompt: 'Prompt 1', answer: 'Answer 1'),
            StudyItemModel(id: 'two', prompt: 'Prompt 2', answer: 'Answer 2'),
          ],
        ),
      ),
    );
    firstRepository.dispose();

    final restoredRepository = TaskRepository(preferences: preferences);
    final restored = (await restoredRepository.watch().first).single;

    expect(restored.studyContent?.format, StudyFormat.quiz);
    expect(restored.studyContent?.items.map((item) => item.id), <String>[
      'one',
      'two',
    ]);
    restoredRepository.dispose();
  });

  test('loads legacy preference records without study content', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'tasks':
          '[{"id":"legacy","title":"Old task","durationMinutes":25,'
          '"createdAt":"2026-01-01T00:00:00.000Z","completedAt":null}]',
    });
    final repository = TaskRepository(
      preferences: await SharedPreferences.getInstance(),
    );

    final task = (await repository.watch().first).single;

    expect(task.title, 'Old task');
    expect(task.studyContent, isNull);
    repository.dispose();
  });
}
