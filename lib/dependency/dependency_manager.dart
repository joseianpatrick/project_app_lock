import 'package:get_it/get_it.dart';
import 'package:project_app_lock/data/lock_session_model.dart';
import 'package:project_app_lock/data/repository/protected_app_selection_repository.dart';
import 'package:project_app_lock/data/repository/repository.dart';
import 'package:project_app_lock/data/task_model.dart';
import 'package:project_app_lock/features/focus_session/focus_session_store.dart';
import 'package:project_app_lock/features/focus_session/lock_session_repository.dart';
import 'package:project_app_lock/features/protected_apps/protected_app_selection_repository.dart';
import 'package:project_app_lock/features/protected_apps/protected_apps_store.dart';
import 'package:project_app_lock/features/tasks/task_repository.dart';
import 'package:project_app_lock/features/tasks/task_store.dart';
import 'package:project_app_lock/platform/app_lock/installed_apps_gateway.dart';
import 'package:project_app_lock/platform/app_lock/method_channel_app_lock_gateway.dart';
import 'package:project_app_lock/platform/app_lock/system_app_lock_gateway.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GetIt sl = GetIt.instance;

final class DependencyManager {
  Future<void> init() async {
    final preferences = await SharedPreferences.getInstance();
    sl.registerSingleton<SharedPreferences>(preferences);
    setSystemAppLockGateway();
    setTaskStore(preferences);
    setProtectedAppsStore(preferences);
    setFocusSessionStore(preferences);
  }

  void setSystemAppLockGateway() {
    const gateway = MethodChannelAppLockGateway();
    sl.registerSingleton<SystemAppLockGateway>(gateway);
    sl.registerSingleton<InstalledAppsGateway>(gateway);
  }

  void setTaskStore(SharedPreferences preferences) {
    final repository = TaskRepository(preferences: preferences);
    sl.registerSingleton<Repository<TaskModel>>(repository);
    sl.registerSingleton<TaskStore>(TaskStore(taskRepository: repository));
  }

  void setProtectedAppsStore(SharedPreferences preferences) {
    final selectionRepository = LocalProtectedAppSelectionRepository(
      preferences,
    );
    sl.registerSingleton<ProtectedAppSelectionRepository>(selectionRepository);
    sl.registerSingleton<ProtectedAppsStore>(
      ProtectedAppsStore(
        gateway: sl<InstalledAppsGateway>(),
        selectionRepository: selectionRepository,
      ),
    );
  }

  void setFocusSessionStore(SharedPreferences preferences) {
    final repository = LockSessionRepository(preferences: preferences);
    sl.registerSingleton<Repository<LockSessionModel>>(repository);
    sl.registerSingleton<FocusSessionStore>(
      FocusSessionStore(
        sessionRepository: repository,
        taskRepository: sl<Repository<TaskModel>>(),
        selectionRepository: sl<ProtectedAppSelectionRepository>(),
        gateway: sl<SystemAppLockGateway>(),
        installedAppsGateway: sl<InstalledAppsGateway>(),
      ),
    );
  }
}
