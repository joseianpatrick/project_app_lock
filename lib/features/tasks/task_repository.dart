import 'package:project_app_lock/data/repository/local_collection_repository.dart';
import 'package:project_app_lock/data/study_content_model.dart';
import 'package:project_app_lock/data/task_model.dart';

base class TaskRepository extends LocalCollectionRepository<TaskModel> {
  TaskRepository({super.uuid, super.preferences});

  @override
  String get storageKey => 'tasks';

  @override
  String get entityLabel => 'tasks';

  @override
  String idOf(TaskModel value) => value.id;

  @override
  TaskModel fromMap(Map<String, dynamic> map) => TaskModel.fromMap(map);

  @override
  Map<String, Object?> toMap(TaskModel value) => value.toMap();

  @override
  TaskModel withId(TaskModel value, String id) => value.copyWith(id: id);

  @override
  int compare(TaskModel a, TaskModel b) => a.createdAt.compareTo(b.createdAt);

  @override
  TaskModel applyPatch(TaskModel current, Map<String, Object?> data) =>
      current.copyWith(
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
}
