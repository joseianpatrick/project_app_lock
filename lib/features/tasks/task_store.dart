import 'dart:async';

import 'package:mobx/mobx.dart';
import 'package:project_app_lock/data/repository/repository.dart';
import 'package:project_app_lock/data/task_model.dart';

part 'task_store.g.dart';

class TaskStore = TaskStoreBase with _$TaskStore;

abstract class TaskStoreBase with Store {
  TaskStoreBase({required this.taskRepository});

  final Repository<TaskModel> taskRepository;

  @observable
  ObservableList<TaskModel> tasks = ObservableList<TaskModel>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @observable
  String? formError;

  @observable
  bool isSaving = false;

  @computed
  bool get isEmpty => tasks.isEmpty;

  @computed
  int get pendingCount => tasks.where((task) => !task.isCompleted).length;

  @computed
  bool get canUnlock => tasks.isNotEmpty && pendingCount == 0;

  StreamSubscription<List<TaskModel>>? _subscription;

  @action
  void initialize() {
    _subscription?.cancel();
    isLoading = true;
    errorMessage = null;
    _subscription = taskRepository.watch().listen(
      (items) {
        runInAction(() {
          tasks = items.asObservable();
          isLoading = false;
        });
      },
      onError: (Object error) {
        runInAction(() {
          errorMessage = 'Could not load tasks.';
          isLoading = false;
        });
      },
    );
  }

  @action
  Future<bool> addTask(String title, {int durationMinutes = 25}) =>
      saveTask(title: title, durationMinutes: durationMinutes);

  @action
  Future<bool> saveTask({
    String? id,
    required String title,
    required int durationMinutes,
  }) async {
    if (isSaving) return false;
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      formError = 'Enter a task title.';
      return false;
    }
    if (normalizedTitle.length > 120) {
      formError = 'Keep the title to 120 characters or fewer.';
      return false;
    }
    if (durationMinutes < 1 || durationMinutes > 1440) {
      formError = 'Choose a duration from 1 minute to 24 hours.';
      return false;
    }

    errorMessage = null;
    formError = null;
    isSaving = true;
    try {
      if (id == null) {
        final newId = taskRepository.newId();
        await taskRepository.set(
          newId,
          TaskModel(
            id: newId,
            title: normalizedTitle,
            durationMinutes: durationMinutes,
            createdAt: DateTime.now(),
          ),
        );
      } else {
        await taskRepository.update(id, <String, Object?>{
          'title': normalizedTitle,
          'durationMinutes': durationMinutes,
        });
      }
      return true;
    } catch (_) {
      formError = 'Could not save the task. Try again.';
      return false;
    } finally {
      isSaving = false;
    }
  }

  @action
  void clearFormError() => formError = null;

  @action
  Future<void> deleteTask(String id) async {
    errorMessage = null;
    await taskRepository.delete(id);
  }

  void dispose() {
    _subscription?.cancel();
  }
}
