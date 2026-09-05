import 'dart:async';

import 'package:mobx/mobx.dart';
import 'package:project_app_lock/data/lock_session_model.dart';
import 'package:project_app_lock/data/repository/repository.dart';
import 'package:project_app_lock/data/study_content_model.dart';
import 'package:project_app_lock/features/focus_session/focus_session_store.dart';

part 'study_attempt_store.g.dart';

class StudyAttemptStore = StudyAttemptStoreBase with _$StudyAttemptStore;

abstract class StudyAttemptStoreBase with Store {
  StudyAttemptStoreBase({
    required this.sessionRepository,
    required this.focusSessionStore,
  });

  final Repository<LockSessionModel> sessionRepository;
  final FocusSessionStore focusSessionStore;

  @observable
  LockSessionModel? session;

  @observable
  String responseDraft = '';

  @observable
  bool isLoading = false;

  @observable
  bool isSaving = false;

  @observable
  String? errorMessage;

  StreamSubscription<List<LockSessionModel>>? _subscription;

  @computed
  SessionStudyContentModel? get studyContent => session?.studyContent;

  @computed
  bool get isLegacySession => session != null && studyContent == null;

  @computed
  bool get hasStudyContent => studyContent != null;

  @computed
  bool get hasInvalidProgress {
    final content = studyContent;
    final progress = session?.studyProgress;
    if (content == null || progress == null) return false;
    final itemIds = content.items.map((item) => item.id).toSet();
    if (itemIds.length != content.items.length ||
        progress.currentItemIndex < 0 ||
        progress.currentItemIndex > content.items.length) {
      return true;
    }
    final responseIds = <String>{};
    for (final response in progress.responses) {
      if (!itemIds.contains(response.itemId) ||
          !responseIds.add(response.itemId) ||
          !response.isRevealed ||
          response.response.trim().isEmpty ||
          (response.assessment != null && !response.isRevealed)) {
        return true;
      }
    }
    for (var index = 0; index < progress.currentItemIndex; index++) {
      final response = _responseFor(content.items[index].id);
      if (response?.assessment == null) return true;
    }
    return false;
  }

  @computed
  bool get isSummary =>
      !hasInvalidProgress &&
      studyContent != null &&
      currentItemIndex >= studyContent!.items.length;

  @computed
  int get currentItemIndex => session?.studyProgress?.currentItemIndex ?? 0;

  @computed
  StudyResponseModel? get currentResponse {
    final item = currentItem;
    if (item == null) {
      return null;
    }
    return _responseFor(item.id);
  }

  @computed
  StudyItemModel? get currentItem {
    final content = studyContent;
    if (content == null || currentItemIndex >= content.items.length) {
      return null;
    }
    return content.items[currentItemIndex];
  }

  @computed
  bool get canReveal =>
      currentItem != null &&
      !(currentResponse?.isRevealed ?? false) &&
      responseDraft.trim().isNotEmpty &&
      !isSaving;

  @computed
  bool get canAssess =>
      currentResponse?.isRevealed == true &&
      currentResponse?.assessment == null &&
      !isSaving;

  @computed
  int get assessedCount =>
      session?.studyProgress?.responses
          .where((response) => response.assessment != null)
          .length ??
      0;

  @computed
  int get correctCount =>
      session?.studyProgress?.responses
          .where((response) => response.assessment == StudyAssessment.correct)
          .length ??
      0;

  @computed
  int get needsReviewCount =>
      session?.studyProgress?.responses
          .where(
            (response) => response.assessment == StudyAssessment.needsReview,
          )
          .length ??
      0;

  @computed
  bool get canComplete =>
      studyContent != null &&
      assessedCount == studyContent!.items.length &&
      studyContent!.items.every(
        (item) => _responseFor(item.id)?.assessment != null,
      );

  @action
  void initialize() {
    _subscription?.cancel();
    isLoading = true;
    errorMessage = null;
    _subscription = sessionRepository.watch().listen(
      (sessions) {
        final active = sessions.cast<LockSessionModel?>().firstWhere(
          (candidate) =>
              candidate?.state == LockSessionState.active ||
              candidate?.state == LockSessionState.scheduled ||
              candidate?.state == LockSessionState.unlockPending,
          orElse: () => null,
        );
        runInAction(() {
          session = active;
          isLoading = false;
          if (hasInvalidProgress) {
            errorMessage =
                'Saved study progress is invalid. Start a new focus session.';
            return;
          }
          final response = currentResponse;
          if (response != null && !response.isRevealed) {
            responseDraft = response.response;
          }
        });
      },
      onError: (_) => runInAction(() {
        isLoading = false;
        errorMessage = 'Could not restore your study progress. Try again.';
      }),
    );
  }

  @action
  void setResponseDraft(String value) {
    responseDraft = value;
    errorMessage = null;
  }

  @action
  Future<bool> revealAnswer() async {
    final active = session;
    final item = currentItem;
    if (active == null || item == null || !canReveal) {
      if (responseDraft.trim().isEmpty) {
        errorMessage = 'Enter a response before revealing the answer.';
      }
      return false;
    }
    final existing = _responseFor(item.id);
    final next = _nextProgress(
      active,
      response: StudyResponseModel(
        itemId: item.id,
        response: responseDraft.trim(),
        isRevealed: true,
        assessment: existing?.assessment,
      ),
    );
    return _saveProgress(active, next);
  }

  @action
  Future<bool> assess(StudyAssessment assessment) async {
    final active = session;
    final item = currentItem;
    final response = currentResponse;
    if (active == null || item == null || response == null || !canAssess) {
      errorMessage = 'Reveal the answer before assessing your response.';
      return false;
    }
    final next = _nextProgress(
      active,
      response: response.copyWith(assessment: assessment),
      currentItemIndex: currentItemIndex + 1,
    );
    final saved = await _saveProgress(active, next);
    if (saved) responseDraft = '';
    return saved;
  }

  @action
  Future<bool> completeAndUnlock() async {
    if (!canComplete || isSaving) {
      errorMessage = 'Assess every study item before completing the task.';
      return false;
    }
    isSaving = true;
    try {
      final completed = await focusSessionStore.completeActiveTask();
      if (!completed) {
        errorMessage =
            focusSessionStore.errorMessage ?? 'Could not unlock yet.';
      }
      return completed;
    } finally {
      isSaving = false;
    }
  }

  StudyResponseModel? _responseFor(String itemId) {
    final responses = session?.studyProgress?.responses ?? const [];
    for (final response in responses) {
      if (response.itemId == itemId) return response;
    }
    return null;
  }

  StudyProgressModel _nextProgress(
    LockSessionModel active, {
    required StudyResponseModel response,
    int? currentItemIndex,
  }) {
    final previous = active.studyProgress ?? StudyProgressModel.empty();
    final responses =
        previous.responses
            .where((value) => value.itemId != response.itemId)
            .toList()
          ..add(response);
    return StudyProgressModel(
      currentItemIndex: currentItemIndex ?? previous.currentItemIndex,
      responses: responses,
    );
  }

  Future<bool> _saveProgress(
    LockSessionModel active,
    StudyProgressModel progress,
  ) async {
    if (isSaving) return false;
    isSaving = true;
    errorMessage = null;
    try {
      await sessionRepository.update(active.id, <String, Object?>{
        'studyProgress': progress,
      });
      return true;
    } catch (_) {
      errorMessage = 'Could not save your study progress. Try again.';
      return false;
    } finally {
      isSaving = false;
    }
  }

  void dispose() => _subscription?.cancel();
}
