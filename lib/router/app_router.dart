import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:mobx/mobx.dart';
import 'package:project_app_lock/features/focus_session/focus_session_screen.dart';
import 'package:project_app_lock/features/focus_session/focus_session_store.dart';
import 'package:project_app_lock/features/home/home_screen.dart';
import 'package:project_app_lock/features/protected_apps/protected_apps_screen.dart';
import 'package:project_app_lock/features/settings/settings_screen.dart';
import 'package:project_app_lock/features/tasks/task_editor_screen.dart';
import 'package:project_app_lock/features/tasks/task_screen.dart';
import 'package:project_app_lock/shared/widgets/app_shell.dart';

/// Bridges the session store's MobX state to go_router without putting
/// navigation decisions in a store or a screen.
final class FocusSessionRouteGuard extends ChangeNotifier {
  FocusSessionRouteGuard(this._store) {
    _disposer = reaction<Object?>(
      (_) => _store.activeSession,
      (_) => notifyListeners(),
      fireImmediately: true,
    );
    unawaited(_store.initialize());
  }

  final FocusSessionStore _store;
  late final ReactionDisposer _disposer;

  bool get locksToTaskScreen =>
      _store.activeSession?.policy?.lockToTaskScreen ?? false;

  void disposeGuard() {
    _disposer();
    super.dispose();
  }
}

/// Owns router resources that must be released with the application widget.
final class AppRouter {
  AppRouter(FocusSessionStore focusSessionStore, {String? initialLocation})
    : guard = FocusSessionRouteGuard(focusSessionStore) {
    router = GoRouter(
      initialLocation: initialLocation,
      refreshListenable: guard,
      redirect: (context, state) {
        if (guard.locksToTaskScreen && state.uri.path != '/focus-session') {
          return '/focus-session';
        }
        return null;
      },
      routes: <RouteBase>[
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: <RouteBase>[
            GoRoute(
              path: '/',
              name: 'home',
              builder: (context, state) => const HomeScreen(),
            ),
            GoRoute(
              path: '/settings',
              name: 'settings',
              builder: (context, state) => const SettingsScreen(),
            ),
            GoRoute(
              path: '/tasks',
              name: 'tasks',
              builder: (context, state) => const TaskScreen(),
            ),
            GoRoute(
              path: '/tasks/new',
              name: 'task-create',
              builder: (context, state) => const TaskEditorScreen(),
            ),
            GoRoute(
              path: '/tasks/:taskId/edit',
              name: 'task-edit',
              builder: (context, state) =>
                  TaskEditorScreen(taskId: state.pathParameters['taskId']),
            ),
            GoRoute(
              path: '/apps-to-lock',
              name: 'apps-to-lock',
              builder: (context, state) => const ProtectedAppsScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/focus-session',
          name: 'focus-session',
          builder: (context, state) => const FocusSessionScreen(),
        ),
      ],
    );
  }

  final FocusSessionRouteGuard guard;
  late final GoRouter router;

  void dispose() {
    router.dispose();
    guard.disposeGuard();
  }
}
