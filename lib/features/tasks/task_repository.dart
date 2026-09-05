import 'dart:async';
import 'dart:convert';

import 'package:project_app_lock/data/repository/repository.dart';
import 'package:project_app_lock/data/task_model.dart';
import 'package:project_app_lock/data/study_content_model.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class TaskRepository implements Repository<TaskModel> {
  TaskRepository({Uuid? uuid, this.preferences})
    : _uuid = uuid ?? const Uuid(),
      super();

  static const String _storageKey = 'tasks';
  final Uuid _uuid;
  final SharedPreferences? preferences;
  final Map<String, TaskModel> _tasks = <String, TaskModel>{};
  bool _hasLoaded = false;
  final StreamController<List<TaskModel>> _controller =
      StreamController<List<TaskModel>>.broadcast();

  List<TaskModel> get _snapshot {
    final tasks = _tasks.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return List<TaskModel>.unmodifiable(tasks);
  }

  void _emit() => _controller.add(_snapshot);

  Future<void> _load() async {
    if (_hasLoaded) return;
    _hasLoaded = true;
    final encoded = preferences?.getString(_storageKey);
    if (encoded == null) return;
    final values = jsonDecode(encoded) as List<dynamic>;
    _tasks
      ..clear()
      ..addEntries(
        values.whereType<Map<String, dynamic>>().map((map) {
          final task = TaskModel.fromMap(map);
          return MapEntry<String, TaskModel>(task.id, task);
        }),
      );
  }

  Future<void> _persist() async {
    final storage = preferences;
    if (storage == null) return;
    final saved = await storage.setString(
      _storageKey,
      jsonEncode(_snapshot.map((task) => task.toMap()).toList()),
    );
    if (!saved) throw StateError('Could not persist tasks.');
  }

  @override
  Stream<List<TaskModel>> watch() async* {
    await _load();
    yield _snapshot;
    yield* _controller.stream;
  }

  @override
  Future<TaskModel?> getById(String id) async {
    await _load();
    return _tasks[id];
  }

  @override
  Future<void> set(String id, TaskModel value) async {
    await _load();
    _tasks[id] = value.copyWith(id: id);
    await _persist();
    _emit();
  }

  @override
  Future<void> update(String id, Map<String, Object?> data) async {
    await _load();
    final current = _tasks[id];
    if (current == null) {
      return;
    }

    _tasks[id] = current.copyWith(
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
    await _persist();
    _emit();
  }

  @override
  Future<void> delete(String id) async {
    await _load();
    _tasks.remove(id);
    await _persist();
    _emit();
  }

  @override
  String newId() => _uuid.v4();

  void dispose() => _controller.close();
}
