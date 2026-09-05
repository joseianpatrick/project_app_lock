import 'dart:async';

import 'package:project_app_lock/data/task_model.dart';
import 'package:project_app_lock/features/tasks/task_repository.dart';

/// In-memory [TaskRepository] (no [SharedPreferences]) with hooks for driving
/// failure and timing scenarios in tests.
final class FakeTaskRepository extends TaskRepository {
  int _idCounter = 0;
  int setCalls = 0;
  Completer<void>? setGate;
  bool failSet = false;
  bool failGet = false;

  @override
  Future<TaskModel?> getById(String id) {
    if (failGet) throw StateError('get failed');
    return super.getById(id);
  }

  @override
  Future<void> set(String id, TaskModel value) async {
    setCalls += 1;
    if (failSet) throw StateError('set failed');
    final gate = setGate;
    if (gate != null) await gate.future;
    await super.set(id, value);
  }

  @override
  String newId() => 'id_${_idCounter++}';

  void close() => dispose();
}
