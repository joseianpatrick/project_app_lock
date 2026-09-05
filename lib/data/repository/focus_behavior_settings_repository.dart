import 'package:project_app_lock/data/focus_behavior_settings_model.dart';
import 'package:project_app_lock/data/repository/repository.dart';

abstract interface class FocusBehaviorSettingsRepository
    implements
        SingleValueRepository<FocusBehaviorSettingsModel>,
        Watchable<FocusBehaviorSettingsModel> {}
