import 'dart:async';

import 'package:project_app_lock/data/repository/repository.dart';
import 'package:project_app_lock/data/task_model.dart';
import 'package:project_app_lock/data/study_content_model.dart';

final class FakeTaskRepository implements Repository<TaskModel> {
  final Map<String, TaskModel> _items = <String, TaskModel>{};
  final StreamController<List<TaskModel>> _controller =
      StreamController<List<TaskModel>>.broadcast();
  int _idCounter = 0;
  int setCalls = 0;
  Completer<void>? setGate;

  List<TaskModel> get _snapshot => List<TaskModel>.unmodifiable(_items.values);

  void _emit() => _controller.add(_snapshot);

  @override
  Stream<List<TaskModel>> watch() async* {
    yield _snapshot;
    yield* _controller.stream;
  }

  @override
  Future<TaskModel?> getById(String id) async => _items[id];

  @override
  Future<void> set(String id, TaskModel value) async {
    setCalls += 1;
    final gate = setGate;
    if (gate != null) await gate.future;
    _items[id] = value.copyWith(id: id);
    _emit();
  }

  @override
  Future<void> update(String id, Map<String, Object?> data) async {
    final current = _items[id];
    if (current == null) {
      return;
    }
    _items[id] = current.copyWith(
      title: data['title'] as String? ?? current.title,
      durationMinutes:
          data['durationMinutes'] as int? ?? current.durationMinutes,
      completedAt: data.containsKey('completedAt')
          ? data['completedAt'] as DateTime?
          : current.completedAt,
      studyContent: data.containsKey('studyContent')
          ? data['studyContent'] as StudyContentModel?
          : current.studyContent,
    );
    _emit();
  }

  @override
  Future<void> delete(String id) async {
    _items.remove(id);
    _emit();
  }

  @override
  String newId() => 'id_${_idCounter++}';

  void close() => _controller.close();
}
