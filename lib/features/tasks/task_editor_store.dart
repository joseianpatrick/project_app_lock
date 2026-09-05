import 'package:mobx/mobx.dart';
import 'package:project_app_lock/data/repository/repository.dart';
import 'package:project_app_lock/data/study_content_model.dart';
import 'package:project_app_lock/data/study_content_source.dart';
import 'package:project_app_lock/data/task_model.dart';

part 'task_editor_store.g.dart';

class TaskEditorStore = TaskEditorStoreBase with _$TaskEditorStore;

abstract class TaskEditorStoreBase with Store {
  TaskEditorStoreBase({
    required this.taskRepository,
    required this.studyContentSource,
  });

  final Repository<TaskModel> taskRepository;
  final StudyContentSource studyContentSource;

  @observable
  String? taskId;
  @observable
  DateTime? createdAt;
  @observable
  DateTime? completedAt;
  @observable
  String title = '';
  @observable
  int durationMinutes = 25;
  @observable
  StudyFormat format = StudyFormat.quiz;
  @observable
  String sourceNotes = '';
  @observable
  ObservableList<StudyItemModel> items = ObservableList<StudyItemModel>();
  @observable
  bool isLoading = false;
  @observable
  bool isSaving = false;
  @observable
  String? errorMessage;

  @computed
  bool get isEditing => taskId != null;

  @action
  Future<void> load(String id) async {
    isLoading = true;
    errorMessage = null;
    try {
      final task = await taskRepository.getById(id);
      if (task == null) {
        errorMessage = 'This task no longer exists.';
        return;
      }
      taskId = task.id;
      createdAt = task.createdAt;
      completedAt = task.completedAt;
      title = task.title;
      durationMinutes = task.durationMinutes;
      final content = task.studyContent;
      if (content != null) {
        format = content.format;
        sourceNotes = content.sourceNotes;
        items = content.items.toList().asObservable();
      }
    } catch (_) {
      errorMessage = 'Could not load this task.';
    } finally {
      isLoading = false;
    }
  }

  @action
  void setTitle(String value) => title = value;
  @action
  void setDuration(int value) => durationMinutes = value;
  @action
  void setFormat(StudyFormat value) => format = value;
  @action
  void setSourceNotes(String value) => sourceNotes = value;

  @action
  void addItem() => items.add(
    StudyItemModel(id: taskRepository.newId(), prompt: '', answer: ''),
  );

  @action
  void updateItem(String id, {String? prompt, String? answer}) {
    final index = items.indexWhere((item) => item.id == id);
    if (index == -1) return;
    items[index] = items[index].copyWith(
      prompt: prompt ?? items[index].prompt,
      answer: answer ?? items[index].answer,
    );
  }

  @action
  void removeItem(String id) => items.removeWhere((item) => item.id == id);

  @action
  void moveItem(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= items.length ||
        newIndex < 0 ||
        newIndex >= items.length) {
      return;
    }
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
  }

  @action
  Future<bool> save() async {
    if (isSaving) {
      return false;
    }
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) return _fail('Enter a task title.');
    if (normalizedTitle.length > 120) {
      return _fail('Keep the title to 120 characters or fewer.');
    }
    if (durationMinutes < 1 || durationMinutes > 1440) {
      return _fail('Choose a duration from 1 minute to 24 hours.');
    }
    isSaving = true;
    errorMessage = null;
    try {
      final result = await studyContentSource.create(
        StudyContentAuthoringRequest(
          format: format,
          sourceNotes: sourceNotes,
          items: items.toList(growable: false),
        ),
      );
      final content = result.content;
      if (content == null) return _fail(_messageFor(result.failure));
      final id = taskId ?? taskRepository.newId();
      await taskRepository.set(
        id,
        TaskModel(
          id: id,
          title: normalizedTitle,
          durationMinutes: durationMinutes,
          createdAt: createdAt ?? DateTime.now(),
          completedAt: completedAt,
          studyContent: content,
        ),
      );
      return true;
    } catch (_) {
      return _fail('Could not save the task. Try again.');
    } finally {
      isSaving = false;
    }
  }

  bool _fail(String message) {
    errorMessage = message;
    return false;
  }

  String _messageFor(StudyContentValidationFailure? failure) =>
      switch (failure) {
        StudyContentValidationFailure.emptySourceNotes => 'Enter source notes.',
        StudyContentValidationFailure.emptyItems =>
          'Add at least one study item.',
        StudyContentValidationFailure.emptyItemId => 'A study item is invalid.',
        StudyContentValidationFailure.emptyPrompt =>
          'Enter a prompt for every item.',
        StudyContentValidationFailure.emptyAnswer =>
          'Enter an answer for every item.',
        null => 'Could not validate study content.',
      };
}
