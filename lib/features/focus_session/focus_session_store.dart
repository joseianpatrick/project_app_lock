import 'dart:async';

import 'package:mobx/mobx.dart';
import 'package:project_app_lock/data/lock_session_model.dart';
import 'package:project_app_lock/data/repository/protected_app_selection_repository.dart';
import 'package:project_app_lock/data/repository/repository.dart';
import 'package:project_app_lock/data/task_model.dart';
import 'package:project_app_lock/platform/app_lock/installed_apps_gateway.dart';
import 'package:project_app_lock/platform/app_lock/system_app_lock_gateway.dart';

part 'focus_session_store.g.dart';

class FocusSessionStore = FocusSessionStoreBase with _$FocusSessionStore;

abstract class FocusSessionStoreBase with Store {
  FocusSessionStoreBase({
    required this.sessionRepository,
    required this.taskRepository,
    required this.selectionRepository,
    required this.gateway,
    required this.installedAppsGateway,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final Repository<LockSessionModel> sessionRepository;
  final Repository<TaskModel> taskRepository;
  final ProtectedAppSelectionRepository selectionRepository;
  final SystemAppLockGateway gateway;
  final InstalledAppsGateway installedAppsGateway;
  final DateTime Function() now;

  @observable
  LockSessionModel? activeSession;

  @observable
  DateTime currentTime = DateTime.now();

  @observable
  bool isBusy = false;

  @observable
  String? errorMessage;

  StreamSubscription<List<LockSessionModel>>? _subscription;
  Timer? _timer;
  bool _awaitingInitialSnapshot = false;
  Future<bool>? _finishOperation;

  @computed
  bool get hasActiveSession => activeSession != null;

  @computed
  Duration get remaining {
    final session = activeSession;
    if (session == null) return Duration.zero;
    final value = session.endsAt.difference(currentTime);
    return value.isNegative ? Duration.zero : value;
  }

  @computed
  bool get needsUnlockRetry =>
      activeSession?.state == LockSessionState.unlockPending;

  @action
  Future<void> initialize() async {
    await _subscription?.cancel();
    _awaitingInitialSnapshot = true;
    _subscription = sessionRepository.watch().listen((sessions) {
      final active = sessions.cast<LockSessionModel?>().firstWhere(
        (session) =>
            session?.state == LockSessionState.active ||
            session?.state == LockSessionState.scheduled ||
            session?.state == LockSessionState.unlockPending,
        orElse: () => null,
      );
      runInAction(() => activeSession = active);
      if (_awaitingInitialSnapshot) {
        _awaitingInitialSnapshot = false;
        if (active != null) _reconcile(active);
      }
    });
  }

  @action
  Future<String?> validateStart(TaskModel task) async {
    errorMessage = null;
    if (hasActiveSession) return 'Finish the active focus session first.';
    if (task.isCompleted) return 'Completed tasks cannot start a session.';
    if (task.durationMinutes < 1 || task.durationMinutes > 1440) {
      return 'The task duration is outside the supported range.';
    }
    final capability = await gateway.getCapability();
    if (!capability.isAvailable) return capability.reason;
    final selected = await selectionRepository.load();
    if (selected.isEmpty) return 'Select at least one app to lock.';
    try {
      final installedPackageIds =
          (await installedAppsGateway.getInstalledApps())
              .map((app) => app.packageId)
              .toSet();
      final eligibleSelection = selected.intersection(installedPackageIds);
      if (eligibleSelection.length != selected.length) {
        await selectionRepository.save(eligibleSelection);
      }
      if (eligibleSelection.isEmpty) {
        return 'Select at least one installed app to lock.';
      }
    } catch (_) {
      return 'Could not verify the selected apps. Try again.';
    }
    return null;
  }

  Future<int> getSelectedAppCount() async =>
      (await selectionRepository.load()).length;

  @action
  Future<bool> start(TaskModel task) async {
    if (isBusy) return false;
    isBusy = true;
    try {
      final validation = await validateStart(task);
      if (validation != null) {
        errorMessage = validation;
        return false;
      }
      final packageIds = (await selectionRepository.load()).toList()..sort();
      final startedAt = now();
      final session = LockSessionModel(
        id: sessionRepository.newId(),
        taskId: task.id,
        taskTitle: task.title,
        packageIds: packageIds,
        startedAt: startedAt,
        endsAt: startedAt.add(Duration(minutes: task.durationMinutes)),
        state: LockSessionState.scheduled,
      );
      await sessionRepository.set(session.id, session);
      try {
        await gateway.startLockSession(
          packageIds: packageIds,
          endsAt: session.endsAt,
        );
      } catch (_) {
        await sessionRepository.update(session.id, <String, Object?>{
          'state': LockSessionState.cancelled,
        });
        errorMessage = 'The system could not start app locking.';
        return false;
      }
      await sessionRepository.update(session.id, <String, Object?>{
        'state': LockSessionState.active,
      });
      _startTimer();
      return true;
    } finally {
      isBusy = false;
    }
  }

  @action
  Future<bool> completeActiveTask() async {
    final session = activeSession;
    if (session == null || isBusy) return false;
    isBusy = true;
    try {
      await taskRepository.update(session.taskId, <String, Object?>{
        'completedAt': now(),
      });
      return await _finish(session);
    } finally {
      isBusy = false;
    }
  }

  @action
  Future<bool> retryUnlock() async {
    if (isBusy) return false;
    final session = activeSession;
    if (session == null) return true;
    isBusy = true;
    try {
      return await _finish(session);
    } finally {
      isBusy = false;
    }
  }

  Future<bool> _finish(LockSessionModel session) {
    final existing = _finishOperation;
    if (existing != null) return existing;
    late final Future<bool> operation;
    operation = _performFinish(session).whenComplete(() {
      if (identical(_finishOperation, operation)) _finishOperation = null;
    });
    _finishOperation = operation;
    return operation;
  }

  Future<bool> _performFinish(LockSessionModel session) async {
    await sessionRepository.update(session.id, <String, Object?>{
      'state': LockSessionState.completed,
    });
    try {
      await gateway.stopLockSession();
      _timer?.cancel();
      return true;
    } catch (_) {
      await sessionRepository.update(session.id, <String, Object?>{
        'state': LockSessionState.unlockPending,
      });
      runInAction(() => errorMessage = 'Unlocking needs to be retried.');
      return false;
    }
  }

  Future<void> _reconcile(LockSessionModel session) async {
    if (session.state == LockSessionState.unlockPending) return;
    if (!session.endsAt.isAfter(now())) {
      await _finish(session);
      return;
    }
    if (session.state == LockSessionState.scheduled ||
        session.state == LockSessionState.active) {
      try {
        await gateway.startLockSession(
          packageIds: session.packageIds,
          endsAt: session.endsAt,
        );
        if (session.state == LockSessionState.scheduled) {
          await sessionRepository.update(session.id, <String, Object?>{
            'state': LockSessionState.active,
          });
        }
        _startTimer();
      } catch (_) {
        runInAction(() => errorMessage = 'Could not restore app locking.');
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    runInAction(() => currentTime = now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      runInAction(() => currentTime = now());
      final session = activeSession;
      if (session != null && !session.endsAt.isAfter(currentTime)) {
        unawaited(_finish(session));
      }
    });
  }

  void dispose() {
    _subscription?.cancel();
    _timer?.cancel();
  }
}
