import 'dart:async';
import 'dart:convert';

import 'package:project_app_lock/data/focus_behavior_settings_model.dart';
import 'package:project_app_lock/data/repository/focus_behavior_settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class LocalFocusBehaviorSettingsRepository
    implements FocusBehaviorSettingsRepository {
  LocalFocusBehaviorSettingsRepository(this._preferences);

  static const String storageKey = 'focus_behavior_settings';
  final SharedPreferences _preferences;
  final StreamController<FocusBehaviorSettingsModel> _controller =
      StreamController<FocusBehaviorSettingsModel>.broadcast();

  @override
  Future<FocusBehaviorSettingsModel> load() async {
    final encoded = _preferences.getString(storageKey);
    if (encoded == null) return FocusBehaviorSettingsModel.defaults();
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return FocusBehaviorSettingsModel.defaults();
      return FocusBehaviorSettingsModel.fromMap(
        Map<String, dynamic>.from(decoded),
      );
    } on FormatException {
      return FocusBehaviorSettingsModel.defaults();
    }
  }

  @override
  Future<void> save(FocusBehaviorSettingsModel settings) async {
    final saved = await _preferences.setString(
      storageKey,
      jsonEncode(settings.toMap()),
    );
    if (!saved) throw StateError('Could not persist focus behavior settings.');
    _controller.add(settings);
  }

  @override
  Stream<FocusBehaviorSettingsModel> watch() async* {
    yield await load();
    yield* _controller.stream;
  }

  void dispose() => _controller.close();
}
