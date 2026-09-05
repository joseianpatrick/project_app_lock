import 'dart:async';

import 'package:project_app_lock/data/focus_behavior_settings_model.dart';
import 'package:project_app_lock/data/repository/focus_behavior_settings_repository.dart';

final class FakeFocusBehaviorSettingsRepository
    implements FocusBehaviorSettingsRepository {
  FakeFocusBehaviorSettingsRepository([FocusBehaviorSettingsModel? initial])
    : value = initial ?? FocusBehaviorSettingsModel.defaults();

  FocusBehaviorSettingsModel value;
  bool failSave = false;
  final StreamController<FocusBehaviorSettingsModel> _controller =
      StreamController<FocusBehaviorSettingsModel>.broadcast();

  @override
  Future<FocusBehaviorSettingsModel> load() async => value;

  @override
  Future<void> save(FocusBehaviorSettingsModel settings) async {
    if (failSave) throw StateError('save failed');
    value = settings;
    _controller.add(value);
  }

  @override
  Stream<FocusBehaviorSettingsModel> watch() async* {
    yield value;
    yield* _controller.stream;
  }

  void close() => _controller.close();
}
