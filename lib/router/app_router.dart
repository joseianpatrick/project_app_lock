import 'package:go_router/go_router.dart';
import 'package:project_app_lock/features/home/home_screen.dart';
import 'package:project_app_lock/features/focus_session/focus_session_screen.dart';
import 'package:project_app_lock/features/protected_apps/protected_apps_screen.dart';
import 'package:project_app_lock/features/tasks/task_screen.dart';
import 'package:project_app_lock/features/tasks/task_editor_screen.dart';
import 'package:project_app_lock/shared/widgets/app_shell.dart';

final GoRouter appRouter = GoRouter(
  routes: <RouteBase>[
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          name: 'home',
          builder: (context, state) => const HomeScreen(),
          routes: [
            GoRoute(
              path: 'tasks',
              name: 'tasks',
              builder: (context, state) => const TaskScreen(),
              routes: <RouteBase>[
                GoRoute(
                  path: 'new',
                  name: 'task-create',
                  builder: (context, state) => const TaskEditorScreen(),
                ),
                GoRoute(
                  path: ':taskId/edit',
                  name: 'task-edit',
                  builder: (context, state) =>
                      TaskEditorScreen(taskId: state.pathParameters['taskId']),
                ),
              ],
            ),
            GoRoute(
              path: 'apps-to-lock',
              name: 'apps-to-lock',
              builder: (context, state) => const ProtectedAppsScreen(),
            ),
            GoRoute(
              path: 'focus-session',
              name: 'focus-session',
              builder: (context, state) => const FocusSessionScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
