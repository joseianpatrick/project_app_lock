import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_app_lock/dependency/dependency_manager.dart';
import 'package:project_app_lock/features/focus_session/focus_session_store.dart';
import 'package:project_app_lock/features/focus_session/lock_session_repository.dart';
import 'package:project_app_lock/features/settings/settings_screen.dart';
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
  late SettingsStore settingsStore;

  setUp(() async {
    await sl.reset();
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
    settingsStore = SettingsStore(
      settingsRepository: repository,
      focusSessionStore: sessionStore,
    );
    sl.registerSingleton<FocusSessionStore>(sessionStore);
    sl.registerSingleton<SettingsStore>(settingsStore);
  });

  tearDown(() async {
    settingsStore.dispose();
    sessionStore.dispose();
    sessionRepository.dispose();
    taskRepository.close();
    repository.close();
    await sl.reset();
  });

  testWidgets('shows controls and saves a changed switch', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pump();

    expect(find.text('Lock navigation to task'), findsOneWidget);
    expect(find.text('Allow other apps'), findsOneWidget);
    expect(find.text('Enable Back button'), findsOneWidget);

    await tester.tap(find.byType(Switch).at(1));
    await tester.pump();

    expect(repository.value.allowOtherApps, isTrue);
  });
}
