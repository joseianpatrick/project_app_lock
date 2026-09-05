import 'package:project_app_lock/data/lock_session_model.dart';
import 'package:project_app_lock/data/repository/local_collection_repository.dart';

final class LockSessionRepository
    extends LocalCollectionRepository<LockSessionModel> {
  LockSessionRepository({super.uuid, super.preferences});

  @override
  String get storageKey => 'lock_sessions';

  @override
  String get entityLabel => 'lock sessions';

  @override
  String idOf(LockSessionModel value) => value.id;

  @override
  LockSessionModel fromMap(Map<String, dynamic> map) =>
      LockSessionModel.fromMap(map);

  @override
  Map<String, Object?> toMap(LockSessionModel value) => value.toMap();

  @override
  LockSessionModel withId(LockSessionModel value, String id) =>
      value.copyWith(id: id);

  /// Most recently started session first.
  @override
  int compare(LockSessionModel a, LockSessionModel b) =>
      b.startedAt.compareTo(a.startedAt);

  @override
  LockSessionModel applyPatch(
    LockSessionModel current,
    Map<String, Object?> data,
  ) => current.copyWith(
    state: data['state'] as LockSessionState? ?? current.state,
    studyProgress: data.containsKey('studyProgress')
        ? data['studyProgress'] as StudyProgressModel?
        : current.studyProgress,
  );
}
