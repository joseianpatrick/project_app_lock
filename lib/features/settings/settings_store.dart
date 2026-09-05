import 'dart:async';

import 'package:mobx/mobx.dart';
import 'package:project_app_lock/data/focus_behavior_settings_model.dart';
import 'package:project_app_lock/data/repository/focus_behavior_settings_repository.dart';
import 'package:project_app_lock/features/focus_session/focus_session_store.dart';

part 'settings_store.g.dart';

// ignore: library_private_types_in_public_api
class SettingsStore = _SettingsStoreBase with _$SettingsStore;

abstract class _SettingsStoreBase with Store {
  _SettingsStoreBase({
    required this.settingsRepository,
    required this.focusSessionStore,
  });

  final FocusBehaviorSettingsRepository settingsRepository;
  final FocusSessionStore focusSessionStore;
  StreamSubscription<FocusBehaviorSettingsModel>? _subscription;

  @observable
  FocusBehaviorSettingsModel? settings;

  @observable
  bool isLoading = false;

  @observable
  String? savingSetting;

  @observable
  String? errorMessage;

  @computed
  bool get isSaving => savingSetting != null;

  @computed
  FocusSessionPolicyModel? get activeSessionPolicy =>
      focusSessionStore.activeSession?.policy;

  @action
  Future<void> initialize() async {
    await _subscription?.cancel();
    isLoading = true;
    errorMessage = null;
    _subscription = settingsRepository.watch().listen(
      (value) => runInAction(() {
        settings = value;
        isLoading = false;
      }),
      onError: (_) => runInAction(() {
        isLoading = false;
        errorMessage = 'Could not load focus behavior settings.';
      }),
    );
  }

  Future<void> setLockToTaskScreen(bool value) => _save(
    'lockToTaskScreen',
    (settings) => settings.copyWith(lockToTaskScreen: value),
  );

  Future<void> setAllowOtherApps(bool value) => _save(
    'allowOtherApps',
    (settings) => settings.copyWith(allowOtherApps: value),
  );

  Future<void> setBackButtonEnabled(bool value) => _save(
    'backButtonEnabled',
    (settings) => settings.copyWith(backButtonEnabled: value),
  );

  @action
  Future<void> _save(
    String settingName,
    FocusBehaviorSettingsModel Function(FocusBehaviorSettingsModel) change,
  ) async {
    final current = settings;
    if (current == null || savingSetting != null) return;
    savingSetting = settingName;
    errorMessage = null;
    final updated = change(current);
    try {
      await settingsRepository.save(updated);
      runInAction(() => settings = updated);
    } catch (_) {
      runInAction(() {
        errorMessage = 'Could not save focus behavior settings. Try again.';
        settings = current;
      });
    } finally {
      runInAction(() => savingSetting = null);
    }
  }

  void dispose() => _subscription?.cancel();
}
