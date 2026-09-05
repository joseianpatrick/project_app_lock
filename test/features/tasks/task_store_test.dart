import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_app_lock/features/tasks/task_store.dart';

import '../../fakes/fake_task_repository.dart';

void main() {
  late FakeTaskRepository repository;
  late TaskStore store;

  setUp(() {
    repository = FakeTaskRepository();
    store = TaskStore(taskRepository: repository);
  });

  tearDown(() {
    store.dispose();
    repository.close();
  });

  test('initialize exposes the empty state', () async {
    store.initialize();
    await Future<void>.delayed(Duration.zero);

    expect(store.isLoading, isFalse);
    expect(store.isEmpty, isTrue);
    expect(store.pendingCount, 0);
    expect(store.canUnlock, isFalse);
  });

  test('addTask trims input and exposes a pending task', () async {
    store.initialize();
    await store.addTask('  Read chapter  ');
    await Future<void>.delayed(Duration.zero);

    expect(store.tasks.single.title, 'Read chapter');
    expect(store.tasks.single.durationMinutes, 25);
    expect(store.pendingCount, 1);
    expect(store.canUnlock, isFalse);
  });

  test('addTask rejects empty input', () async {
    store.initialize();

    expect(await store.addTask('   '), isFalse);
    expect(store.formError, 'Enter a task title.');
    expect(store.tasks, isEmpty);
  });

  test('saveTask rejects durations outside 1 minute to 24 hours', () async {
    expect(await store.saveTask(title: 'Read', durationMinutes: 0), isFalse);
    expect(store.formError, contains('1 minute'));
  });

  test('saveTask edits title and duration', () async {
    store.initialize();
    await store.addTask('Read');
    await Future<void>.delayed(Duration.zero);

    expect(
      await store.saveTask(
        id: store.tasks.single.id,
        title: 'Write',
        durationMinutes: 45,
      ),
      isTrue,
    );
    await Future<void>.delayed(Duration.zero);

    expect(store.tasks.single.title, 'Write');
    expect(store.tasks.single.durationMinutes, 45);
  });

  test('repeated save is ignored while persistence is in progress', () async {
    final gate = Completer<void>();
    repository.setGate = gate;
    final first = store.saveTask(title: 'Read', durationMinutes: 25);
    await Future<void>.delayed(Duration.zero);

    expect(store.isSaving, isTrue);
    expect(await store.saveTask(title: 'Read', durationMinutes: 25), isFalse);
    expect(repository.setCalls, 1);
    gate.complete();
    expect(await first, isTrue);
  });

  test('deleteTask removes an existing task', () async {
    store.initialize();
    await store.addTask('Read chapter');
    await Future<void>.delayed(Duration.zero);

    await store.deleteTask(store.tasks.single.id);
    await Future<void>.delayed(Duration.zero);

    expect(store.isEmpty, isTrue);
  });

  test('initialize can be called twice without duplicate updates', () async {
    store.initialize();
    store.initialize();
    await store.addTask('Read chapter');
    await Future<void>.delayed(Duration.zero);

    expect(store.tasks, hasLength(1));
  });
}
