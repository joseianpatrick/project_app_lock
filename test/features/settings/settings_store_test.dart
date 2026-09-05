import 'package:flutter_test/flutter_test.dart';
import 'package:project_app_lock/features/focus_session/focus_session_store.dart';
import 'package:project_app_lock/features/focus_session/lock_session_repository.dart';
import 'package:project_app_lock/features/settings/settings_store.dart';

import '../../fakes/fake_app_lock_gateway.dart';
import '../../fakes/fake_focus_behavior_settings_repository.dart';
import '../../fakes/fake_protected_app_selection_repository.dart';
import '../../fakes/fake_task_repository.dart';

void main() {
  late FakeFocusBehaviorSettingsRepository repository;
  late FakeTaskRepository taskRepository;
  late LockSessionRepository sessionRepository;
  late FocusSessionStore sessionStore;
  late SettingsStore store;

  setUp(() {
    repository = FakeFocusBehaviorSettingsRepository();
    taskRepository = FakeTaskRepository();
    sessionRepository = LockSessionRepository();
    sessionStore = FocusSessionStore(
      sessionRepository: sessionRepository,
      taskRepository: taskRepository,
      selectionRepository: FakeProtectedAppSelectionRepository(),
      gateway: FakeAppLockGateway(),
      installedAppsGateway: FakeAppLockGateway(),
      settingsRepository: repository,
    );
    store = SettingsStore(
      settingsRepository: repository,
      focusSessionStore: sessionStore,
    );
  });

  tearDown(() {
    store.dispose();
    sessionStore.dispose();
    sessionRepository.dispose();
    taskRepository.close();
    repository.close();
  });

  test('loads defaults and persists a switch change', () async {
    await store.initialize();
    await Future<void>.delayed(Duration.zero);

    expect(store.settings?.lockToTaskScreen, isTrue);
    await store.setAllowOtherApps(true);

    expect(store.settings?.allowOtherApps, isTrue);
    expect(repository.value.allowOtherApps, isTrue);
    expect(store.isSaving, isFalse);
  });

  test(
    'retains the persisted value and exposes an error after save failure',
    () async {
      await store.initialize();
      await Future<void>.delayed(Duration.zero);
      repository.failSave = true;

      await store.setBackButtonEnabled(true);

      expect(store.settings?.backButtonEnabled, isFalse);
      expect(store.errorMessage, contains('Could not save'));
    },
  );
}
