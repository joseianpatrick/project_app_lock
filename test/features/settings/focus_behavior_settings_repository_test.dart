import 'package:flutter_test/flutter_test.dart';
import 'package:project_app_lock/data/focus_behavior_settings_model.dart';
import 'package:project_app_lock/features/settings/focus_behavior_settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('uses documented defaults and persists each setting', () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalFocusBehaviorSettingsRepository(preferences);

    expect(await repository.load(), FocusBehaviorSettingsModel.defaults());

    const updated = FocusBehaviorSettingsModel(
      lockToTaskScreen: false,
      allowOtherApps: true,
      backButtonEnabled: true,
    );
    await repository.save(updated);

    expect(await repository.load(), updated);
    repository.dispose();
  });

  test('keeps valid fields when stored data has malformed values', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      LocalFocusBehaviorSettingsRepository.storageKey:
          '{"lockToTaskScreen":false,"allowOtherApps":"nope","backButtonEnabled":true}',
    });
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalFocusBehaviorSettingsRepository(preferences);

    expect(
      await repository.load(),
      const FocusBehaviorSettingsModel(
        lockToTaskScreen: false,
        allowOtherApps: false,
        backButtonEnabled: true,
      ),
    );
    repository.dispose();
  });

  test('supports multiple watch subscriptions', () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalFocusBehaviorSettingsRepository(preferences);
    final first = repository.watch();
    final second = repository.watch();

    expect(await first.first, FocusBehaviorSettingsModel.defaults());
    expect(await second.first, FocusBehaviorSettingsModel.defaults());
    repository.dispose();
  });
}
